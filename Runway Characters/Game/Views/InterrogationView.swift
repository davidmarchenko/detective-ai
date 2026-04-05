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

    // Haptic generators — prepared once, reused
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticNotify = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Avatar video (full bleed)
            if let videoTrack = session.remoteVideoTrack {
                SwiftUIVideoView(videoTrack)
                    .ignoresSafeArea()
            }

            // Corner brackets (decorative, respects safe area insets)
            cornerBrackets.allowsHitTesting(false)

            // Main HUD
            VStack(spacing: 0) {
                topBar
                Spacer()
                if showTranscription { transcriptView }
                floatingControls
                    .padding(.bottom, 8)
            }

            // Notification card — SEPARATE layer, bottom-aligned, hard size cap
            if let card = activeCard, session.state == .active {
                VStack {
                    Spacer()
                    notificationCard(card)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: 100)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 80)
                }
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: activeCard?.id)
            }

            // Modal overlays
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

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let w = geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
            let h = geo.size.height + safeTop + safeBottom
            let s: CGFloat = 20
            let inset: CGFloat = max(24, safeTop > 0 ? 20 : 24) // respect rounded screen corners
            Path { p in
                p.move(to: CGPoint(x: inset, y: safeTop + inset + s))
                p.addLine(to: CGPoint(x: inset, y: safeTop + inset))
                p.addLine(to: CGPoint(x: inset + s, y: safeTop + inset))

                p.move(to: CGPoint(x: w - inset - s, y: safeTop + inset))
                p.addLine(to: CGPoint(x: w - inset, y: safeTop + inset))
                p.addLine(to: CGPoint(x: w - inset, y: safeTop + inset + s))

                p.move(to: CGPoint(x: inset, y: h - safeBottom - inset - s))
                p.addLine(to: CGPoint(x: inset, y: h - safeBottom - inset))
                p.addLine(to: CGPoint(x: inset + s, y: h - safeBottom - inset))

                p.move(to: CGPoint(x: w - inset - s, y: h - safeBottom - inset))
                p.addLine(to: CGPoint(x: w - inset, y: h - safeBottom - inset))
                p.addLine(to: CGPoint(x: w - inset, y: h - safeBottom - inset - s))
            }
            .stroke(DT.Colors.warmGlow.opacity(0.15), lineWidth: 1)
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suspect.name)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(suspect.role)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if gameState.gameMaster.suspicionLevel > 0 {
                HStack(spacing: 4) {
                    Circle().fill(suspicionColor).frame(width: 6, height: 6)
                    Text("\(Int(gameState.gameMaster.suspicionLevel * 100))%")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(suspicionColor)
                }
            }

            if !gameState.discoveredClues.isEmpty {
                Label("\(gameState.discoveredClues.count)", systemImage: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(.orange)
            }

            if let callStart {
                CallTimerView(startDate: callStart)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(session.transcriptions) { entry in
                        transcriptRow(entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 200)
            .defaultScrollAnchor(.bottom) // start at bottom, not top
            .onChange(of: session.transcriptions.count) { _, _ in
                if let last = session.transcriptions.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func transcriptRow(_ entry: TranscriptionEntry) -> some View {
        let isUser = entry.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 80) }
            Text(entry.text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isUser
                        ? Color.blue.opacity(0.6)
                        : Color.white.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            if !isUser { Spacer(minLength: 80) }
        }
        .id(entry.id)
    }

    // MARK: - Floating Controls (FaceTime-style)

    private var floatingControls: some View {
        HStack(spacing: 12) {
            // Mic
            floatingButton(
                icon: isMuted ? "mic.slash.fill" : "mic.fill",
                isActive: !isMuted
            ) {
                isMuted.toggle()
                Task { try? await session._room?.localParticipant.setMicrophone(enabled: !isMuted) }
            }

            // Log
            floatingButton(
                icon: "captions.bubble.fill",
                isActive: showTranscription
            ) {
                withAnimation { showTranscription.toggle() }
            }

            // Clues
            ZStack(alignment: .topTrailing) {
                floatingButton(
                    icon: "magnifyingglass",
                    isActive: showInvestigate
                ) {
                    showInvestigate.toggle()
                    gameState.newQuestionsAvailable = false
                }
                if gameState.newQuestionsAvailable && !showInvestigate {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                        .shadow(color: .orange, radius: 3)
                        .offset(x: -2, y: -2)
                }
            }

            // End call — red circle like FaceTime
            Button { showEndConfirm = true } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red, in: Circle())
            }
        }
        .padding(.horizontal, 24)
    }

    private func floatingButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.6))
                .frame(width: 48, height: 48)
                .background(
                    isActive ? Color.white.opacity(0.25) : Color.black.opacity(0.4),
                    in: Circle()
                )
        }
    }

    // MARK: - Notification Card

    private func notificationCard(_ card: NotificationCard) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(card.accentColor)
                .frame(width: 4)
                .frame(minHeight: 30)
                .shadow(color: card.accentColor.opacity(0.3), radius: 3)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                if let label = card.label {
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(card.accentColor)
                        .tracking(1)
                }
                Text(card.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
            }

            Spacer(minLength: 4)

            // Dismiss
            Button {
                withAnimation { activeCard = nil }
                if let questionId = card.questionId { gameState.usedQuestionIds.insert(questionId) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 32, height: 32) // 32pt minimum tap target
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(card.accentColor.opacity(0.25), lineWidth: 1)
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
                showCard(cardQueue.removeFirst())
            }
        }
    }

    // MARK: - Connecting

    private var connectingOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                        .foregroundStyle(.white)
                    Text(session.connectingStatus.isEmpty ? "Entering interrogation room..." : session.connectingStatus)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await session.disconnect() }
                    gameState.endInterrogation()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
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
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 16) {
                if isReconnecting {
                    ProgressView().scaleEffect(1.2).tint(.orange)
                    Text("Connection Lost").font(.headline).foregroundStyle(.white)
                    Text("Trying to reconnect...").font(.subheadline).foregroundStyle(.white.opacity(0.5))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36)).foregroundStyle(.yellow)
                    Text("Interrogation Failed").font(.headline).foregroundStyle(.white)
                    Text(message).font(.footnote).foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center).lineLimit(5)
                        .padding(.horizontal, 32)
                }
                HStack(spacing: 16) {
                    Button("Reconnect") {
                        Task {
                            await session.connect(avatar: suspect.avatarConfig, personality: suspect.personality,
                                                  startScript: suspect.startScript, tools: GameTools.interrogationTools)
                        }
                    }.buttonStyle(.borderedProminent).tint(.orange)
                    Button("End & Keep Evidence") { gameState.endInterrogation() }
                        .buttonStyle(.bordered).tint(.white)
                }
            }
            .padding(32)
        }
    }

    // MARK: - End Confirm

    private var endConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { showEndConfirm = false }
            VStack(spacing: 16) {
                Text("End Interrogation?")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("You've found \(gameState.discoveredClues.count) clue(s) so far.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 16) {
                    Button("Continue") { showEndConfirm = false }
                        .buttonStyle(.bordered).tint(.white)
                    Button("End & Review") {
                        showEndConfirm = false
                        Task { await session.disconnect() }
                    }.buttonStyle(.borderedProminent).tint(.red)
                }
            }
            .padding(28)
            .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 0.5))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Game Master Events

    private func handleGameMasterUIEvent(_ event: GameMasterService.GameMasterEvent) {
        for clue in event.cluesDetected {
            hapticMedium.impactOccurred()
            showCard(NotificationCard(
                label: clue.importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                text: clue.text,
                accentColor: clue.importance == "critical" ? .red : .orange
            ))
        }
        if event.contradictionDetected != nil {
            hapticNotify.notificationOccurred(.warning)
            showCard(NotificationCard(label: "CONTRADICTION", text: "You caught an inconsistency!", accentColor: .red))
        }
        if let suggestion = event.suggestedQuestion, activeCard == nil {
            Task {
                try? await Task.sleep(for: .seconds(2))
                if activeCard == nil {
                    showCard(NotificationCard(label: "TRY ASKING", text: suggestion, accentColor: .blue), duration: 12)
                }
            }
        }
        if let instinct = event.instinct, activeCard == nil, event.cluesDetected.isEmpty {
            Task {
                try? await Task.sleep(for: .seconds(1))
                if activeCard == nil {
                    showCard(NotificationCard(label: "DETECTIVE INSTINCT", text: instinct, accentColor: .purple), duration: 8)
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
                hapticMedium.impactOccurred()
                showCard(NotificationCard(
                    label: importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                    text: text,
                    accentColor: importance == "critical" ? .red : .orange
                ))
            }
        case "contradiction":
            hapticNotify.notificationOccurred(.warning)
            showCard(NotificationCard(label: "CONTRADICTION", text: "You caught an inconsistency!", accentColor: .red))
        case "emotional_shift":
            if let emotion = args["emotion"] as? String {
                hapticLight.impactOccurred()
                withAnimation { currentEmotion = emotion }
            }
        case "interrogation_milestone":
            if let milestone = args["milestone"] as? String {
                hapticNotify.notificationOccurred(.success)
                let (label, text, color) = milestoneDisplay(milestone)
                showCard(NotificationCard(label: label, text: text, accentColor: color))
            }
        case "suspicion_shift":
            if let target = args["target_suspect"] as? String {
                showCard(NotificationCard(label: "ACCUSATION", text: "They're pointing the finger at \(target)", accentColor: .yellow))
            }
        default: break
        }
    }

    private func milestoneDisplay(_ milestone: String) -> (String, String, Color) {
        switch milestone {
        case "first_probe": ("GOOD QUESTION", "You're on the right track", .blue)
        case "key_reveal": ("BREAKTHROUGH", "Key information revealed!", .orange)
        case "turning_point": ("TURNING POINT", "The interrogation just shifted", .yellow)
        case "near_confession": ("PRESSURE", "They're starting to crack...", .red)
        case "confession": ("CONFESSION", "They broke!", .green)
        default: ("PROGRESS", "Milestone reached", .white)
        }
    }

    private var suspicionColor: Color {
        let level = gameState.gameMaster.suspicionLevel
        if level > 0.7 { return .red }
        if level > 0.4 { return .orange }
        return .yellow
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
