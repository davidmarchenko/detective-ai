import SwiftUI
import UIKit
import Combine
import LiveKit

struct InterrogationView: View {
    @Bindable var gameState: GameState
    let suspect: SuspectDefinition
    @State private var session = SessionManager()
    @State private var callStart: Date?
    @State private var isMuted = false
    @State private var showTranscription = false
    @State private var currentEmotion: String?
    @State private var showEndConfirm = false
    @State private var showInvestigate = false
    @State private var activeCard: NotificationCard?
    @State private var cardQueue: [NotificationCard] = []
    @State private var cardDismissTask: Task<Void, Never>?
    @State private var ringScale: CGFloat = 0.6

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Avatar video
            if let videoTrack = session.remoteVideoTrack {
                SwiftUIVideoView(videoTrack)
                    .ignoresSafeArea()
            }

            // Corner brackets overlay (decorative, non-interactive)
            cornerBrackets
                .allowsHitTesting(false)

            // Main HUD
            VStack(spacing: 0) {
                topBar
                Spacer()
                if showTranscription { transcriptView }

                // Notification card (above controls)
                if let card = activeCard, session.state == .active {
                    notificationCard(card)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.3), value: activeCard?.id)
                }

                controlBar
            }

            // Overlays
            if session.state == .connecting { connectingOverlay }
            if case .error(let msg) = session.state { errorOverlay(msg) }
            if showEndConfirm { endConfirmOverlay }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .task {
            if let mystery = gameState.mystery {
                let discoveredIds = Set(gameState.discoveredClues.map(\.clueId))
                gameState.gameMaster.configure(scenario: mystery, suspect: suspect, discoveredClueIds: discoveredIds)
                gameState.gameMaster.onGameEvent = { event in
                    gameState.handleGameMasterEvent(event)
                    handleGameMasterUIEvent(event)
                }
            }
            session.onGameEvent = { tool, args in
                gameState.handleGameEvent(tool: tool, args: args)
                handleLocalUIEvent(tool: tool, args: args)
            }
            await session.connect(
                avatar: suspect.avatarConfig,
                personality: suspect.personality,
                startScript: suspect.startScript,
                tools: GameTools.interrogationTools
            )
            if session.state == .active { callStart = Date() }
        }
        .onChange(of: session.transcriptions.count) { _, _ in
            if let latest = session.transcriptions.last {
                gameState.gameMaster.feedTranscript(role: latest.role, text: latest.text)
            }
        }
        .onChange(of: session.state) { _, newState in
            if newState == .active && callStart == nil { callStart = Date() }
            if newState == .ended {
                gameState.gameMaster.reset()
                gameState.endInterrogation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            Task { await session.disconnect() }
        }
        .sheet(isPresented: $showInvestigate) {
            InvestigationDrawerView(gameState: gameState, suspectId: suspect.id, isPresented: $showInvestigate)
                .presentationDetents([.fraction(0.45), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .presentationBackground(.ultraThinMaterial)
        }
        .onDisappear { gameState.gameMaster.reset() }
    }

    // MARK: - Corner Brackets (Decorative)

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                let s: CGFloat = 24
                let i: CGFloat = 16
                // Top-left
                p.move(to: CGPoint(x: i, y: i + s)); p.addLine(to: CGPoint(x: i, y: i)); p.addLine(to: CGPoint(x: i + s, y: i))
                // Top-right
                p.move(to: CGPoint(x: w-i-s, y: i)); p.addLine(to: CGPoint(x: w-i, y: i)); p.addLine(to: CGPoint(x: w-i, y: i + s))
                // Bottom-left
                p.move(to: CGPoint(x: i, y: h-i-s)); p.addLine(to: CGPoint(x: i, y: h-i)); p.addLine(to: CGPoint(x: i + s, y: h-i))
                // Bottom-right
                p.move(to: CGPoint(x: w-i-s, y: h-i)); p.addLine(to: CGPoint(x: w-i, y: h-i)); p.addLine(to: CGPoint(x: w-i, y: h-i-s))
            }
            .stroke(DT.Colors.warmGlow.opacity(0.2), lineWidth: 1)
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(suspect.name)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(DT.Colors.fog)
                    .lineLimit(1)
                Text(suspect.role)
                    .font(DT.Typo.tagLabel)
                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.7))
                    .tracking(1)
            }

            Spacer(minLength: 4)

            // Suspicion
            if gameState.gameMaster.suspicionLevel > 0 {
                HStack(spacing: 4) {
                    Circle().fill(suspicionColor).frame(width: 6, height: 6)
                        .shadow(color: suspicionColor, radius: 3)
                    Text("\(Int(gameState.gameMaster.suspicionLevel * 100))%")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(suspicionColor)
                }
            }

            // Clues
            if !gameState.discoveredClues.isEmpty {
                Label("\(gameState.discoveredClues.count)", systemImage: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(DT.Colors.warmGlow)
            }

            // Timer
            if let callStart {
                CallTimerView(startDate: callStart)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(DT.Colors.fog.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(session.transcriptions) { entry in
                        let isUser = entry.role == "user"
                        HStack(alignment: .top, spacing: 8) {
                            Text(isUser ? "YOU" : suspect.name.components(separatedBy: " ").first?.uppercased() ?? "—")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(isUser ? DT.Colors.suggestion : DT.Colors.warmGlow)
                                .frame(width: 40, alignment: .trailing)

                            Rectangle()
                                .fill(isUser ? DT.Colors.suggestion.opacity(0.3) : DT.Colors.warmGlow.opacity(0.2))
                                .frame(width: 2)

                            Text(entry.text)
                                .font(.system(size: 14))
                                .foregroundStyle(DT.Colors.fog.opacity(isUser ? 0.6 : 0.9))
                        }
                        .padding(.vertical, 2)
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 180)
            .mask(LinearGradient(colors: [.clear, .black, .black, .black], startPoint: .top, endPoint: .bottom))
            .onChange(of: session.transcriptions.count) { _, _ in
                if let last = session.transcriptions.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 0) {
            // Mic
            controlButton(
                icon: isMuted ? "mic.slash.fill" : "mic.fill",
                label: isMuted ? "Unmute" : "Mute",
                isActive: !isMuted,
                activeColor: DT.Colors.suggestion
            ) {
                isMuted.toggle()
                Task { try? await session._room?.localParticipant.setMicrophone(enabled: !isMuted) }
            }

            // Transcript
            controlButton(
                icon: "text.bubble.fill",
                label: "Log",
                isActive: showTranscription,
                activeColor: DT.Colors.fog
            ) {
                withAnimation { showTranscription.toggle() }
            }

            // Investigate
            ZStack(alignment: .topTrailing) {
                controlButton(
                    icon: "magnifyingglass",
                    label: "Clues",
                    isActive: showInvestigate,
                    activeColor: DT.Colors.warmGlow
                ) {
                    showInvestigate.toggle()
                    gameState.newQuestionsAvailable = false
                }
                if gameState.newQuestionsAvailable && !showInvestigate {
                    Circle()
                        .fill(DT.Colors.warmGlow)
                        .frame(width: 8, height: 8)
                        .shadow(color: DT.Colors.warmGlow, radius: 3)
                        .offset(x: -8, y: 8)
                }
            }

            // End call
            Button { showEndConfirm = true } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DT.Colors.ember)
            }
        }
        .frame(height: 52)
        .background(.ultraThinMaterial)
    }

    private func controlButton(icon: String, label: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? activeColor : DT.Colors.smoke)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(isActive ? activeColor.opacity(0.7) : DT.Colors.smoke)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Notification Card

    private func notificationCard(_ card: NotificationCard) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(card.accentColor)
                .frame(width: 4)
                .padding(.vertical, 6)
                .shadow(color: card.accentColor.opacity(0.4), radius: 3)

            VStack(alignment: .leading, spacing: 3) {
                if let label = card.label {
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(card.accentColor)
                        .tracking(1)
                }
                Text(card.text)
                    .font(.system(size: 13))
                    .foregroundStyle(DT.Colors.fog)
                    .lineLimit(2)
            }
            .padding(.leading, 10)

            Spacer(minLength: 8)

            Button {
                withAnimation { activeCard = nil }
                if let questionId = card.questionId { gameState.usedQuestionIds.insert(questionId) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DT.Colors.smoke)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(card.accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Card Queue

    private func showCard(_ card: NotificationCard, duration: TimeInterval = 6) {
        if activeCard != nil {
            cardQueue.append(card)
            return
        }
        cardDismissTask?.cancel()
        withAnimation { activeCard = card }
        cardDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            withAnimation { activeCard = nil }
            try? await Task.sleep(for: .seconds(0.3))
            if !cardQueue.isEmpty {
                let next = cardQueue.removeFirst()
                showCard(next)
            }
        }
    }

    // MARK: - Connecting

    private var connectingOverlay: some View {
        ZStack {
            DT.Colors.void.ignoresSafeArea()

            RadialGradient(
                colors: [DT.Colors.warmGlow.opacity(0.05), .clear],
                center: .center, startRadius: 20, endRadius: 300
            ).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(DT.Colors.warmGlow.opacity(0.12 - Double(i) * 0.03), lineWidth: 1)
                            .frame(width: 80 + CGFloat(i) * 40)
                            .scaleEffect(ringScale)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: ringScale)
                    }
                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.4))
                }

                VStack(spacing: 8) {
                    Text(suspect.name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(DT.Colors.fog)

                    Text(session.connectingStatus.isEmpty ? "Entering interrogation room..." : session.connectingStatus)
                        .font(DT.Typo.caption)
                        .foregroundStyle(DT.Colors.steel)
                }

                Button {
                    Task { await session.disconnect() }
                    gameState.endInterrogation()
                } label: {
                    Text("Cancel")
                        .font(DT.Typo.caption)
                        .foregroundStyle(DT.Colors.smoke)
                }
                .padding(.top, 16)
            }
        }
        .onAppear { ringScale = 1.0 }
    }

    // MARK: - Error

    private func errorOverlay(_ message: String) -> some View {
        let isReconnecting = message.contains("reconnect")
        return ZStack {
            DT.Colors.void.opacity(0.9).ignoresSafeArea()
            VStack(spacing: DT.Space.lg) {
                if isReconnecting {
                    ProgressView().scaleEffect(1.2).tint(DT.Colors.warmGlow)
                    Text("Connection Lost").font(DT.Typo.cardTitle).foregroundStyle(DT.Colors.fog)
                    Text("Trying to reconnect...").font(DT.Typo.caption).foregroundStyle(DT.Colors.steel)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36)).foregroundStyle(DT.Colors.suspicion)
                    Text("Interrogation Failed").font(DT.Typo.cardTitle).foregroundStyle(DT.Colors.fog)
                    Text(message).font(DT.Typo.footnote).foregroundStyle(DT.Colors.steel)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                HStack(spacing: DT.Space.lg) {
                    Button("Reconnect") {
                        Task {
                            await session.connect(avatar: suspect.avatarConfig, personality: suspect.personality,
                                                  startScript: suspect.startScript, tools: GameTools.interrogationTools)
                        }
                    }.buttonStyle(.borderedProminent).tint(DT.Colors.warmGlow)
                    Button("End & Keep Evidence") { gameState.endInterrogation() }
                        .buttonStyle(.bordered).tint(DT.Colors.fog)
                }
            }
        }
    }

    // MARK: - End Confirm

    private var endConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { showEndConfirm = false }
            VStack(spacing: 16) {
                Text("End Interrogation?")
                    .font(DT.Typo.screenTitle)
                    .foregroundStyle(DT.Colors.fog)
                Text("You've found \(gameState.discoveredClues.count) clue(s) so far.")
                    .font(DT.Typo.caption)
                    .foregroundStyle(DT.Colors.steel)
                HStack(spacing: 16) {
                    Button("Continue") { showEndConfirm = false }
                        .buttonStyle(.bordered).tint(DT.Colors.fog)
                    Button("End & Review") {
                        showEndConfirm = false
                        Task { await session.disconnect() }
                    }.buttonStyle(.borderedProminent).tint(DT.Colors.ember)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Game Master Events

    private func handleGameMasterUIEvent(_ event: GameMasterService.GameMasterEvent) {
        for clue in event.cluesDetected {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCard(NotificationCard(
                label: clue.importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                text: clue.text,
                accentColor: clue.importance == "critical" ? DT.Colors.ember : DT.Colors.warmGlow
            ))
        }
        if event.contradictionDetected != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showCard(NotificationCard(label: "CONTRADICTION", text: "You caught an inconsistency!", accentColor: DT.Colors.ember))
        }
        if let suggestion = event.suggestedQuestion, activeCard == nil {
            Task {
                try? await Task.sleep(for: .seconds(2))
                if activeCard == nil {
                    showCard(NotificationCard(label: "TRY ASKING", text: suggestion, accentColor: DT.Colors.suggestion), duration: 12)
                }
            }
        }
        if let instinct = event.instinct, activeCard == nil, event.cluesDetected.isEmpty {
            Task {
                try? await Task.sleep(for: .seconds(1))
                if activeCard == nil {
                    showCard(NotificationCard(label: "DETECTIVE INSTINCT", text: instinct, accentColor: DT.Colors.instinct), duration: 8)
                }
            }
        }
    }

    // MARK: - Avatar Tool Events

    private func handleLocalUIEvent(tool: String, args: [String: Any]) {
        switch tool {
        case "reveal_clue":
            if let clueId = args["clue_id"] as? String,
               gameState.discoveredClues.contains(where: { $0.clueId == clueId }) { break }
            if let text = args["clue_text"] as? String {
                let importance = args["importance"] as? String ?? "supporting"
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showCard(NotificationCard(
                    label: importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                    text: text,
                    accentColor: importance == "critical" ? DT.Colors.ember : DT.Colors.warmGlow
                ))
            }
        case "contradiction":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showCard(NotificationCard(label: "CONTRADICTION", text: "You caught an inconsistency!", accentColor: DT.Colors.ember))
        case "emotional_shift":
            if let emotion = args["emotion"] as? String {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { currentEmotion = emotion }
            }
        case "interrogation_milestone":
            if let milestone = args["milestone"] as? String {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let (label, text, color) = milestoneDisplay(milestone)
                showCard(NotificationCard(label: label, text: text, accentColor: color))
            }
        case "suspicion_shift":
            if let target = args["target_suspect"] as? String {
                showCard(NotificationCard(label: "ACCUSATION", text: "They're pointing the finger at \(target)", accentColor: DT.Colors.suspicion))
            }
        default: break
        }
    }

    private func milestoneDisplay(_ milestone: String) -> (String, String, Color) {
        switch milestone {
        case "first_probe": ("GOOD QUESTION", "You're on the right track", DT.Colors.suggestion)
        case "key_reveal": ("BREAKTHROUGH", "Key information revealed!", DT.Colors.warmGlow)
        case "turning_point": ("TURNING POINT", "The interrogation just shifted", DT.Colors.suspicion)
        case "near_confession": ("PRESSURE", "They're starting to crack...", DT.Colors.ember)
        case "confession": ("CONFESSION", "They broke!", DT.Colors.success)
        default: ("PROGRESS", "Milestone reached", DT.Colors.fog)
        }
    }

    private var suspicionColor: Color {
        let level = gameState.gameMaster.suspicionLevel
        if level > 0.7 { return DT.Colors.ember }
        if level > 0.4 { return DT.Colors.warmGlow }
        return DT.Colors.suspicion
    }
}

// MARK: - Models

struct NotificationCard: Identifiable, Equatable {
    let id = UUID()
    let label: String?
    let text: String
    let accentColor: Color
    var questionId: String? = nil
    static func == (lhs: NotificationCard, rhs: NotificationCard) -> Bool { lhs.id == rhs.id }
}

struct CallTimerView: View {
    let startDate: Date
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedTime)
            .onReceive(timer) { _ in elapsed = Date().timeIntervalSince(startDate) }
    }

    private var formattedTime: String {
        let total = Int(elapsed)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
