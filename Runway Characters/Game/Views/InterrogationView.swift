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
    @State private var cardDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Avatar video
            if let videoTrack = session.remoteVideoTrack {
                SwiftUIVideoView(videoTrack)
                    .ignoresSafeArea()
            }

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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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


    // MARK: - Game Top Bar

    private var gameTopBar: some View {
        HStack {
            // Suspect info
            VStack(alignment: .leading, spacing: 2) {
                Text(suspect.name)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text(suspect.role)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Suspicion meter
            if gameState.gameMaster.suspicionLevel > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.15))
                            Capsule()
                                .fill(suspicionColor)
                                .frame(width: geo.size.width * gameState.gameMaster.suspicionLevel)
                                .animation(.easeOut(duration: 0.5), value: gameState.gameMaster.suspicionLevel)
                        }
                    }
                    .frame(width: 40, height: 4)
                }
                .foregroundStyle(suspicionColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }

            // Clue count badge
            if !gameState.discoveredClues.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                    Text("\(gameState.discoveredClues.count)")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }

            // Timer
            if let callStart {
                CallTimerView(startDate: callStart)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Transcription

    private var transcriptionArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(session.transcriptions) { entry in
                        HStack {
                            if entry.role == "user" { Spacer(minLength: 60) }
                            Text(entry.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    entry.role == "user" ? Color.blue : Color.white.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                            if entry.role != "user" { Spacer(minLength: 60) }
                        }
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 180)
            .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
            .onChange(of: session.transcriptions.count) { _, _ in
                if let last = session.transcriptions.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Controls

    private var gameControls: some View {
        HStack(spacing: 0) {
            controlBtn(icon: isMuted ? "mic.slash.fill" : "mic.fill", label: isMuted ? "Unmute" : "Mute", active: isMuted) {
                isMuted.toggle()
                Task { try? await session._room?.localParticipant.setMicrophone(enabled: !isMuted) }
            }
            Spacer()
            controlBtn(icon: "captions.bubble.fill", label: "Captions", active: showTranscription) {
                withAnimation { showTranscription.toggle() }
            }
            Spacer()
            ZStack(alignment: .topTrailing) {
                controlBtn(icon: "magnifyingglass", label: "Investigate", active: showInvestigate) {
                    withAnimation { showInvestigate.toggle() }
                    gameState.newQuestionsAvailable = false
                }
                // Pulse dot when new questions available
                if gameState.newQuestionsAvailable && !showInvestigate {
                    Circle()
                        .fill(.orange)
                        .frame(width: 10, height: 10)
                        .offset(x: 2, y: -2)
                }
            }
            Spacer()
            // End interrogation (red)
            Button { showEndConfirm = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.red, in: Circle())
                    Text("End")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 24)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func controlBtn(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(active ? .black : .white)
                    .frame(width: 52, height: 52)
                    .background(active ? Color.white : Color.white.opacity(0.2), in: Circle())
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Connecting

    private var connectingOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange.opacity(0.6))
                    .symbolEffect(.pulse)
                Text(suspect.name)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text(session.connectingStatus.isEmpty ? "Entering interrogation room..." : session.connectingStatus)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .animation(.easeInOut, value: session.connectingStatus)

                Button {
                    Task { await session.disconnect() }
                    gameState.endInterrogation()
                } label: {
                    Text("Cancel")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 20)
            }
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
                    .tint(.orange)
                    Button("End & Keep Evidence") { gameState.endInterrogation() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
            }
        }
    }

    // MARK: - End Confirm

    private var endConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { showEndConfirm = false }
            VStack(spacing: 16) {
                Text("End Interrogation?")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("You've found \(gameState.discoveredClues.count) clue(s) so far.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 16) {
                    Button("Continue") { showEndConfirm = false }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Button("End & Review") {
                        showEndConfirm = false
                        Task { await session.disconnect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Unified Notification Card

    private func notificationCard(_ card: NotificationCard) -> some View {
        HStack(spacing: 10) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(card.accentColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                if let label = card.label {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(card.accentColor)
                }
                Text(card.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                withAnimation { activeCard = nil }
                if let questionId = card.questionId {
                    gameState.usedQuestionIds.insert(questionId)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(card.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func showCard(_ card: NotificationCard, duration: TimeInterval = 6) {
        cardDismissTask?.cancel()
        withAnimation { activeCard = card }
        cardDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            if activeCard?.id == card.id {
                withAnimation { activeCard = nil }
            }
        }
    }

    // MARK: - Game Master UI Events

    private func handleGameMasterUIEvent(_ event: GameMasterService.GameMasterEvent) {
        // Show clue cards from Game Master analysis
        for clue in event.cluesDetected {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCard(NotificationCard(
                label: clue.importance == "critical" ? "KEY EVIDENCE" : "CLUE FOUND",
                text: clue.text,
                accentColor: clue.importance == "critical" ? .red : .orange
            ))
        }

        // Show contradiction
        if event.contradictionDetected != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showCard(NotificationCard(
                label: "CONTRADICTION",
                text: "You caught an inconsistency!",
                accentColor: .red
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
                        accentColor: .blue
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
                        accentColor: .purple
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
                accentColor: .red
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
                    accentColor: .yellow
                ))
            }

        default:
            break
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
