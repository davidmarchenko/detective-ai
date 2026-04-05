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
    @State private var showNotebook = false
    @State private var showInvestigate = false
    @State private var activeCard: NotificationCard?
    @State private var cardQueue: [NotificationCard] = []
    @State private var cardDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            DT.Colors.void.ignoresSafeArea()

            // Avatar video
            if let videoTrack = session.remoteVideoTrack {
                SwiftUIVideoView(videoTrack)
                    .ignoresSafeArea()
            }

            // HUD frame overlay — corner brackets + scan lines
            hudFrame

            // Game HUD overlay
            VStack(spacing: 0) {
                gameTopBar
                Spacer()
                if showTranscription { transcriptionArea }
                gameControls
            }

            // Unified notification card (one slot above controls)
            if let card = activeCard, session.state == .active {
                VStack {
                    Spacer()
                    notificationCard(card)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 70) // above the 60pt control bar
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(duration: 0.35), value: activeCard?.id)
            }

            // Connecting overlay
            if session.state == .connecting {
                connectingOverlay
            }

            // Error overlay
            if case .error(let msg) = session.state {
                errorOverlay(msg)
            }

            // End confirmation
            if showEndConfirm {
                endConfirmOverlay
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .task {
            // Configure Game Master
            if let mystery = gameState.mystery {
                let discoveredIds = Set(gameState.discoveredClues.map(\.clueId))
                gameState.gameMaster.configure(
                    scenario: mystery,
                    suspect: suspect,
                    discoveredClueIds: discoveredIds
                )
                gameState.gameMaster.onGameEvent = { event in
                    gameState.handleGameMasterEvent(event)
                    handleGameMasterUIEvent(event)
                }
            }

            // Wire avatar tool events (still useful as supplementary signals)
            session.onGameEvent = { tool, args in
                gameState.handleGameEvent(tool: tool, args: args)
                handleLocalUIEvent(tool: tool, args: args)
            }

            // Connect directly
            await session.connect(
                avatar: suspect.avatarConfig,
                personality: suspect.personality,
                startScript: suspect.startScript,
                tools: GameTools.interrogationTools
            )
            if session.state == .active {
                callStart = Date()
            }
        }
        .onChange(of: session.transcriptions.count) { _, _ in
            // Feed new transcriptions to the Game Master
            if let latest = session.transcriptions.last {
                gameState.gameMaster.feedTranscript(role: latest.role, text: latest.text)
            }
        }
        .onChange(of: session.state) { _, newState in
            if newState == .active && callStart == nil {
                callStart = Date()
            }
            if newState == .ended {
                gameState.gameMaster.reset()
                gameState.endInterrogation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            Task { await session.disconnect() }
        }
        .sheet(isPresented: $showNotebook) {
            CaseNotebookView(gameState: gameState)
        }
        .sheet(isPresented: $showInvestigate) {
            InvestigationDrawerView(
                gameState: gameState,
                suspectId: suspect.id,
                isPresented: $showInvestigate
            )
            .presentationDetents([.fraction(0.45), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .presentationBackground(.ultraThinMaterial)
        }
        .onDisappear {
            gameState.gameMaster.reset()
        }
    }


    // MARK: - HUD Frame (Corner Brackets + Surveillance Aesthetic)

    private var hudFrame: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bracketSize: CGFloat = 30
            let inset: CGFloat = 12
            let lineWidth: CGFloat = 1.5

            ZStack {
                // Corner brackets (single path)
                Path { p in
                    // Top-left
                    p.move(to: CGPoint(x: inset, y: inset + bracketSize))
                    p.addLine(to: CGPoint(x: inset, y: inset))
                    p.addLine(to: CGPoint(x: inset + bracketSize, y: inset))
                    // Top-right
                    p.move(to: CGPoint(x: w - inset - bracketSize, y: inset))
                    p.addLine(to: CGPoint(x: w - inset, y: inset))
                    p.addLine(to: CGPoint(x: w - inset, y: inset + bracketSize))
                    // Bottom-left
                    p.move(to: CGPoint(x: inset, y: h - inset - bracketSize))
                    p.addLine(to: CGPoint(x: inset, y: h - inset))
                    p.addLine(to: CGPoint(x: inset + bracketSize, y: h - inset))
                    // Bottom-right
                    p.move(to: CGPoint(x: w - inset - bracketSize, y: h - inset))
                    p.addLine(to: CGPoint(x: w - inset, y: h - inset))
                    p.addLine(to: CGPoint(x: w - inset, y: h - inset - bracketSize))
                }
                .stroke(DT.Colors.warmGlow.opacity(0.25), lineWidth: lineWidth)

                // "REC" indicator top-right
                HStack(spacing: 4) {
                    Circle()
                        .fill(DT.Colors.ember)
                        .frame(width: 6, height: 6)
                        .shadow(color: DT.Colors.ember, radius: 3)
                    Text("REC")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(DT.Colors.ember.opacity(0.7))
                }
                .position(x: w - 40, y: 75)

                // Subtle scan line
                Rectangle()
                    .fill(DT.Colors.warmGlow.opacity(0.03))
                    .frame(height: 1)
                    .position(x: w / 2, y: h * 0.33)
                Rectangle()
                    .fill(DT.Colors.warmGlow.opacity(0.03))
                    .frame(height: 1)
                    .position(x: w / 2, y: h * 0.66)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Game Top Bar (Stylized HUD)

    private var gameTopBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                // Angular background strip
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: w, y: 58))
                    p.addLine(to: CGPoint(x: w * 0.7, y: 58))
                    p.addLine(to: CGPoint(x: w * 0.65, y: 48))
                    p.addLine(to: CGPoint(x: 0, y: 48))
                    p.closeSubpath()
                }
                .fill(DT.Colors.void.opacity(0.85))

                // Amber accent line at bottom
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 48))
                    p.addLine(to: CGPoint(x: w * 0.65, y: 48))
                    p.addLine(to: CGPoint(x: w * 0.7, y: 58))
                    p.addLine(to: CGPoint(x: w, y: 58))
                }
                .stroke(DT.Colors.warmGlow.opacity(0.3), lineWidth: 1)

            HStack(alignment: .center, spacing: DT.Space.md) {
                // Suspect name plate
                VStack(alignment: .leading, spacing: 1) {
                    Text(suspect.name.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(DT.Colors.fog)
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(suspect.role.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.6))
                        .tracking(2)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Suspicion meter
                if gameState.gameMaster.suspicionLevel > 0 {
                    HStack(spacing: 4) {
                        Text("SUS")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(suspicionColor.opacity(0.7))
                        ZStack(alignment: .leading) {
                            Capsule().fill(DT.Colors.surface).frame(width: 36, height: 4)
                            Capsule().fill(suspicionColor)
                                .frame(width: 36 * gameState.gameMaster.suspicionLevel, height: 4)
                                .shadow(color: suspicionColor.opacity(0.6), radius: 3)
                                .animation(.easeOut(duration: 0.5), value: gameState.gameMaster.suspicionLevel)
                        }
                    }
                }

                // Clue count
                if !gameState.discoveredClues.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 8))
                        Text("\(gameState.discoveredClues.count)")
                            .font(.system(size: 12, weight: .black).monospacedDigit())
                    }
                    .foregroundStyle(DT.Colors.warmGlow)
                }

                // Timer
                if let callStart {
                    CallTimerView(startDate: callStart)
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(DT.Colors.fog.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            }
        }
        .frame(height: 58)
    }

    // MARK: - Transcription (Interrogation Transcript Style)

    private var transcriptionArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.transcriptions) { entry in
                        let isUser = entry.role == "user"
                        HStack(alignment: .top, spacing: 8) {
                            // Role tag
                            Text(isUser ? "YOU" : suspect.name.components(separatedBy: " ").first?.uppercased() ?? "SUS.")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(isUser ? DT.Colors.suggestion : DT.Colors.warmGlow)
                                .frame(width: 36, alignment: .trailing)
                                .padding(.top, 3)

                            // Accent line (fixed width, auto height)
                            Rectangle()
                                .fill(isUser ? DT.Colors.suggestion.opacity(0.4) : DT.Colors.warmGlow.opacity(0.3))
                                .frame(width: 2)

                            // Text
                            Text(entry.text)
                                .font(.system(size: 13))
                                .foregroundStyle(isUser ? DT.Colors.fog.opacity(0.6) : DT.Colors.fog.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 200)
            .mask(LinearGradient(colors: [.clear, .black, .black, .black], startPoint: .top, endPoint: .bottom))
            .onChange(of: session.transcriptions.count) { _, _ in
                if let last = session.transcriptions.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Controls (Opaque HUD Bar)

    private var gameControls: some View {
        VStack(spacing: 0) {
            // Amber accent line
            Rectangle()
                .fill(DT.Colors.warmGlow.opacity(0.2))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                hudButton(icon: isMuted ? "mic.slash.fill" : "mic.fill", label: "MIC", active: !isMuted, color: DT.Colors.suggestion) {
                    isMuted.toggle()
                    Task { try? await session._room?.localParticipant.setMicrophone(enabled: !isMuted) }
                }

                hudDivider

                hudButton(icon: "text.quote", label: "LOG", active: showTranscription, color: DT.Colors.fog) {
                    withAnimation { showTranscription.toggle() }
                }

                hudDivider

                ZStack(alignment: .topTrailing) {
                    hudButton(icon: "magnifyingglass", label: "CLUES", active: showInvestigate, color: DT.Colors.warmGlow) {
                        withAnimation { showInvestigate.toggle() }
                        gameState.newQuestionsAvailable = false
                    }
                    if gameState.newQuestionsAvailable && !showInvestigate {
                        Circle()
                            .fill(DT.Colors.warmGlow)
                            .frame(width: 8, height: 8)
                            .shadow(color: DT.Colors.warmGlow, radius: 4)
                            .offset(x: -6, y: 6)
                    }
                }

                hudDivider

                // End button — red, prominent
                Button { showEndConfirm = true } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DT.Colors.fog)
                        Text("END")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(DT.Colors.fog.opacity(0.7))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DT.Space.md)
                    .background(DT.Colors.ember.opacity(0.9))
                }
            }
            .frame(height: 56)
            .background(DT.Colors.void.opacity(0.95))

            // Safe area padding for home indicator
            DT.Colors.void.opacity(0.95)
                .frame(height: 20)
        }
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(DT.Colors.warmGlow.opacity(0.1))
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    private func hudButton(icon: String, label: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(active ? color : DT.Colors.smoke)
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(active ? color.opacity(0.8) : DT.Colors.smoke)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DT.Space.md)
            .background(active ? color.opacity(0.08) : .clear)
        }
    }

    // MARK: - Connecting

    @State private var ringScale: CGFloat = 0.6

    private var connectingOverlay: some View {
        ZStack {
            DT.Colors.void.ignoresSafeArea()

            // Subtle radial pulse
            RadialGradient(
                colors: [DT.Colors.warmGlow.opacity(0.06), .clear],
                center: .center, startRadius: 20, endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: DT.Space.xl) {
                // Expanding concentric rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(DT.Colors.warmGlow.opacity(0.15 - Double(i) * 0.04), lineWidth: 1)
                            .frame(width: 80 + CGFloat(i) * 40, height: 80 + CGFloat(i) * 40)
                            .scaleEffect(ringScale)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i) * 0.3),
                                value: ringScale
                            )
                    }
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                }

                VStack(spacing: DT.Space.sm) {
                    Text(suspect.name.uppercased())
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(DT.Colors.fog)
                        .tracking(3)

                    Text(session.connectingStatus.isEmpty ? "ENTERING INTERROGATION ROOM" : session.connectingStatus.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                        .tracking(2)
                        .animation(.easeInOut, value: session.connectingStatus)

                    // Loading dots
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(DT.Colors.warmGlow.opacity(0.4))
                                .frame(width: 4, height: 4)
                                .animation(
                                    .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                                    value: ringScale
                                )
                        }
                    }
                    .padding(.top, DT.Space.sm)
                }

                Button {
                    Task { await session.disconnect() }
                    gameState.endInterrogation()
                } label: {
                    Text("CANCEL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DT.Colors.smoke)
                        .tracking(2)
                }
                .padding(.top, DT.Space.xl)
            }
        }
        .onAppear {
            ringScale = 1.0
        }
    }

    // MARK: - Error

    private func errorOverlay(_ message: String) -> some View {
        let isReconnecting = message.contains("reconnect")
        return ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                if isReconnecting {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(.orange)
                    Text("Connection Lost")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Trying to reconnect...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Your evidence is saved")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.7))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                    Text("Interrogation Failed")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                HStack(spacing: 16) {
                    Button("Reconnect") {
                        Task {
                            await session.connect(
                                avatar: suspect.avatarConfig,
                                personality: suspect.personality,
                                startScript: suspect.startScript,
                                tools: GameTools.interrogationTools
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DT.Colors.warmGlow)
                    Button("End & Keep Evidence") { gameState.endInterrogation() }
                        .buttonStyle(.bordered)
                        .tint(DT.Colors.fog)
                }
            }
        }
    }

    // MARK: - End Confirm

    private var endConfirmOverlay: some View {
        ZStack {
            DT.Colors.void.opacity(0.8).ignoresSafeArea()
                .onTapGesture { showEndConfirm = false }
            VStack(spacing: DT.Space.lg) {
                Text("End Interrogation?")
                    .font(DT.Typo.screenTitle)
                    .foregroundStyle(DT.Colors.fog)
                Text("You've found \(gameState.discoveredClues.count) clue(s) so far.")
                    .font(DT.Typo.caption)
                    .foregroundStyle(DT.Colors.steel)
                HStack(spacing: DT.Space.lg) {
                    Button("Continue") { showEndConfirm = false }
                        .buttonStyle(.bordered)
                        .tint(DT.Colors.fog)
                    Button("End & Review") {
                        showEndConfirm = false
                        Task { await session.disconnect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DT.Colors.ember)
                }
            }
            .padding(DT.Space.xl)
            .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DT.Colors.ember.opacity(0.15), lineWidth: 0.5))
        }
    }

    // MARK: - Unified Notification Card

    private func notificationCard(_ card: NotificationCard) -> some View {
        HStack(spacing: 0) {
            // Accent stripe
            Rectangle()
                .fill(card.accentColor)
                .frame(width: 4)
                .shadow(color: card.accentColor.opacity(0.5), radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                if let label = card.label {
                    Text(label)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(card.accentColor)
                        .tracking(1)
                }
                Text(card.text)
                    .font(.system(size: 13))
                    .foregroundStyle(DT.Colors.fog)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DT.Space.md)
            .padding(.vertical, DT.Space.sm)

            Spacer(minLength: 0)

            Button {
                withAnimation { activeCard = nil }
                if let questionId = card.questionId {
                    gameState.usedQuestionIds.insert(questionId)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DT.Colors.smoke)
                    .frame(width: 32, height: 32)
            }
            .padding(.trailing, DT.Space.sm)
        }
        .frame(minHeight: 48)
        .background(DT.Colors.void.opacity(0.93))
        .overlay(alignment: .top) {
            Rectangle().fill(card.accentColor.opacity(0.15)).frame(height: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.sm))
        .shadow(color: card.accentColor.opacity(0.15), radius: 6, y: 2)
    }

    private func showCard(_ card: NotificationCard, duration: TimeInterval = 6) {
        if activeCard != nil {
            // Queue it — will show after the current card dismisses
            cardQueue.append(card)
            return
        }
        cardDismissTask?.cancel()
        withAnimation { activeCard = card }
        cardDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            withAnimation { activeCard = nil }
            // Show next queued card after a brief gap
            try? await Task.sleep(for: .seconds(0.3))
            showNextQueuedCard()
        }
    }

    private func showNextQueuedCard() {
        guard !cardQueue.isEmpty else { return }
        let next = cardQueue.removeFirst()
        showCard(next)
    }

    // MARK: - Game Master UI Events

    private func handleGameMasterUIEvent(_ event: GameMasterService.GameMasterEvent) {
        // Show clue cards from Game Master analysis
        for clue in event.cluesDetected {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCard(NotificationCard(
                label: clue.importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                text: clue.text,
                accentColor: clue.importance == "critical" ? DT.Colors.ember : DT.Colors.warmGlow
            ))
        }

        // Show contradiction
        if event.contradictionDetected != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showCard(NotificationCard(
                label: "CONTRADICTION",
                text: "You caught an inconsistency!",
                accentColor: DT.Colors.ember
            ))
        }

        // Show suggested question (if no card currently showing)
        if let suggestion = event.suggestedQuestion, activeCard == nil {
            Task {
                try? await Task.sleep(for: .seconds(2))
                if activeCard == nil {
                    showCard(NotificationCard(
                        label: "TRY ASKING",
                        text: suggestion,
                        accentColor: DT.Colors.suggestion
                    ), duration: 12)
                }
            }
        }

        // Show detective instinct
        if let instinct = event.instinct, activeCard == nil, event.cluesDetected.isEmpty {
            Task {
                try? await Task.sleep(for: .seconds(1))
                if activeCard == nil {
                    showCard(NotificationCard(
                        label: "DETECTIVE INSTINCT",
                        text: instinct,
                        accentColor: DT.Colors.instinct
                    ), duration: 8)
                }
            }
        }
    }

    // MARK: - Avatar Tool Event Handling (supplementary)

    private func handleLocalUIEvent(tool: String, args: [String: Any]) {
        switch tool {
        case "reveal_clue":
            // Skip UI if Game Master already detected this clue
            if let clueId = args["clue_id"] as? String,
               gameState.discoveredClues.contains(where: { $0.clueId == clueId }) {
                break
            }
            if let text = args["clue_text"] as? String {
                let importance = args["importance"] as? String ?? "supporting"
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showCard(NotificationCard(
                    label: importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                    text: text,
                    accentColor: importance == "critical" ? .red : .orange
                ))
            }

        case "contradiction":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showCard(NotificationCard(
                label: "CONTRADICTION",
                text: "You caught an inconsistency in their story!",
                accentColor: DT.Colors.ember
            ))

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
                showCard(NotificationCard(
                    label: "ACCUSATION",
                    text: "They're pointing the finger at \(target)",
                    accentColor: DT.Colors.suspicion
                ))
            }

        default:
            break
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

    private func emotionEmoji(_ emotion: String) -> String {
        switch emotion {
        case "nervous": "😰"
        case "angry": "😡"
        case "defensive": "😤"
        case "sad": "😢"
        case "panicked": "😱"
        case "relieved": "😌"
        case "defiant": "😠"
        default: "😐"
        }
    }
}

// MARK: - Notification Card Model

struct NotificationCard: Identifiable, Equatable {
    let id = UUID()
    let label: String?
    let text: String
    let accentColor: Color
    var questionId: String? = nil

    static func == (lhs: NotificationCard, rhs: NotificationCard) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Call Timer View

struct CallTimerView: View {
    let startDate: Date
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedTime)
            .onReceive(timer) { _ in
                elapsed = Date().timeIntervalSince(startDate)
            }
    }

    private var formattedTime: String {
        let total = Int(elapsed)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
