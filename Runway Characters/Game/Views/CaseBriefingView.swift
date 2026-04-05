import SwiftUI

struct CaseBriefingView: View {
    @Bindable var gameState: GameState
    @State private var narration = NarrationService()
    @State private var narrationStarted = false
    @State private var revealPhase = 0  // 0=nothing, 1=header, 2=details, 3=briefing, 4=suspects, 5=button

    var body: some View {
        if let mystery = gameState.mystery {
            ZStack {
                // Background — dark desk with warm pool of light
                DT.Colors.void.ignoresSafeArea()
                RadialGradient(
                    colors: [DT.Colors.warmGlow.opacity(0.06), .clear],
                    center: UnitPoint(x: 0.5, y: 0.2),
                    startRadius: 50, endRadius: 500
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Back button
                        HStack {
                            Button {
                                narration.stop()
                                gameState.resetToLobby()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Cases")
                                }
                                .font(DT.Typo.caption)
                                .foregroundStyle(DT.Colors.warmGlow)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, DT.Space.md)

                        Spacer().frame(height: 30)

                        // Classified stamp + case file
                        VStack(spacing: 0) {
                            // Classified header bar
                            HStack {
                                Text("CLASSIFIED")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(DT.Colors.ember.opacity(0.7))
                                    .tracking(4)
                                Spacer()
                                Text("CASE FILE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                    .tracking(2)
                            }
                            .padding(.horizontal, DT.Space.lg)
                            .padding(.vertical, DT.Space.sm)
                            .background(DT.Colors.surfaceRaised)
                            .opacity(revealPhase >= 1 ? 1 : 0)

                            // Case title
                            VStack(spacing: DT.Space.md) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.6))

                                Text(mystery.title)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundStyle(DT.Colors.fog)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: DT.Colors.warmGlow.opacity(0.15), radius: 12)
                            }
                            .padding(.vertical, DT.Space.xl)
                            .frame(maxWidth: .infinity)
                            .background(DT.Colors.surface)
                            .opacity(revealPhase >= 1 ? 1 : 0)
                            .offset(y: revealPhase >= 1 ? 0 : 10)

                            // Divider
                            Rectangle()
                                .fill(DT.Colors.warmGlow.opacity(0.15))
                                .frame(height: 0.5)

                            // Details section
                            VStack(alignment: .leading, spacing: DT.Space.md) {
                                caseField("VICTIM", mystery.victimName, icon: "person.fill.xmark")
                                thinDivider
                                caseField("LOCATION", mystery.setting, icon: "mappin.and.ellipse")
                                thinDivider
                                caseField("SUSPECTS", "\(mystery.suspects.count) persons of interest", icon: "person.3.fill")
                            }
                            .padding(DT.Space.lg)
                            .background(DT.Colors.surface)
                            .opacity(revealPhase >= 2 ? 1 : 0)
                            .offset(y: revealPhase >= 2 ? 0 : 8)

                            Rectangle()
                                .fill(DT.Colors.warmGlow.opacity(0.15))
                                .frame(height: 0.5)

                            // Briefing text
                            VStack(alignment: .leading, spacing: DT.Space.md) {
                                Text("BRIEFING")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                    .tracking(3)

                                NarratedTextView(text: mystery.briefing, narration: narration)
                            }
                            .padding(DT.Space.lg)
                            .background(DT.Colors.surface)
                            .opacity(revealPhase >= 3 ? 1 : 0)
                            .offset(y: revealPhase >= 3 ? 0 : 8)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.md)
                                .stroke(DT.Colors.warmGlow.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                        .padding(.horizontal, 16)

                        // Narration controls
                        HStack(spacing: DT.Space.lg) {
                            Button {
                                if narration.isPlaying || narration.isLoading {
                                    narration.stop()
                                } else {
                                    Task { await narration.speakBriefing(scenarioId: mystery.id, text: narrationText(mystery)) }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if narration.isLoading {
                                        ProgressView().scaleEffect(0.7).tint(DT.Colors.warmGlow)
                                        Text("Loading...")
                                    } else {
                                        Image(systemName: narration.isPlaying ? "pause.fill" : "play.fill")
                                        Text(narration.isPlaying ? "Pause" : "Listen")
                                    }
                                }
                                .font(DT.Typo.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(DT.Colors.warmGlow)
                                .padding(.horizontal, DT.Space.lg)
                                .padding(.vertical, DT.Space.md)
                                .background(DT.Colors.warmGlow.opacity(0.08), in: Capsule())
                                .overlay(Capsule().stroke(DT.Colors.warmGlow.opacity(0.2), lineWidth: 0.5))
                            }

                            if narration.isPlaying && !narration.isLoading {
                                HStack(spacing: 3) {
                                    ForEach(0..<4, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(DT.Colors.warmGlow)
                                            .frame(width: 3, height: .random(in: 8...20))
                                            .animation(
                                                .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.1),
                                                value: narration.isPlaying
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.top, DT.Space.lg)
                        .opacity(revealPhase >= 3 ? 1 : 0)

                        Spacer().frame(height: DT.Space.xxl)

                        // Suspects
                        VStack(alignment: .leading, spacing: DT.Space.md) {
                            Text("PERSONS OF INTEREST")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                .tracking(3)
                                .padding(.horizontal, DT.Space.xl)

                            let suspects = gameState.mode == .quickPlay
                                ? mystery.suspects.filter { $0.id == mystery.quickPlaySuspectId }
                                : mystery.suspects

                            ForEach(suspects) { suspect in
                                suspectDossier(suspect)
                            }
                        }
                        .opacity(revealPhase >= 4 ? 1 : 0)
                        .offset(y: revealPhase >= 4 ? 0 : 10)

                        Spacer().frame(height: DT.Space.xxl)

                        // Begin button
                        Button {
                            narration.stop()
                            gameState.proceedFromBriefing()
                        } label: {
                            HStack(spacing: DT.Space.sm) {
                                Image(systemName: "phone.fill")
                                Text("Begin Investigation")
                            }
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DT.Colors.void)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DT.Space.lg)
                            .background(DT.Grad.buttonGradient(DT.Colors.warmGlow), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                        }
                        .breathingGlow(DT.Colors.warmGlow)
                        .padding(.horizontal, DT.Space.xl)
                        .opacity(revealPhase >= 5 ? 1 : 0)
                        .scaleEffect(revealPhase >= 5 ? 1 : 0.95)

                        Spacer().frame(height: 60)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // Staggered reveal
                for phase in 1...5 {
                    try? await Task.sleep(for: .seconds(phase == 1 ? 0.3 : 0.25))
                    withAnimation(.easeOut(duration: 0.4)) { revealPhase = phase }
                }
                // Auto-start narration
                if !narrationStarted {
                    narrationStarted = true
                    await narration.speakBriefing(scenarioId: mystery.id, text: narrationText(mystery))
                }
            }
            .onDisappear { narration.stop() }
        }
    }

    // MARK: - Components

    private func caseField(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: DT.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.4))
                    .tracking(2)
                Text(value)
                    .font(DT.Typo.caption)
                    .foregroundStyle(DT.Colors.fog)
            }
        }
    }

    private var thinDivider: some View {
        Rectangle().fill(DT.Colors.warmGlow.opacity(0.06)).frame(height: 0.5)
    }

    private func suspectDossier(_ suspect: SuspectDefinition) -> some View {
        HStack(spacing: DT.Space.md) {
            // Mugshot placeholder
            ZStack {
                RoundedRectangle(cornerRadius: DT.Radius.sm)
                    .fill(DT.Colors.surfaceRaised)
                    .frame(width: 50, height: 60)
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DT.Colors.smoke)
            }

            VStack(alignment: .leading, spacing: DT.Space.xs) {
                Text(suspect.name)
                    .font(DT.Typo.cardTitle)
                    .foregroundStyle(DT.Colors.fog)
                Text(suspect.role.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                    .tracking(1)
                Text(suspect.briefDescription)
                    .font(DT.Typo.footnote)
                    .foregroundStyle(DT.Colors.steel)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(DT.Space.md)
        .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .stroke(DT.Colors.warmGlow.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }

    private func narrationText(_ mystery: MysteryScenario) -> String {
        var script = mystery.briefing
        let suspects = gameState.mode == .quickPlay
            ? mystery.suspects.filter { $0.id == mystery.quickPlaySuspectId }
            : mystery.suspects
        script += "\n\nPersons of interest: "
        script += suspects.map { "\($0.name), \($0.role). \($0.briefDescription)" }.joined(separator: ". ")
        script += ". The investigation begins now."
        return script
    }
}

// MARK: - Narrated Text View

/// Always renders text as split sentences. During narration, highlights the active sentence.
/// Layout never changes between playing and paused states.
struct NarratedTextView: View {
    let text: String
    @Bindable var narration: NarrationService

    private var isNarrating: Bool {
        !narration.wordTimings.isEmpty && narration.isPlaying
    }

    var body: some View {
        let staticSentences = splitIntoSentences(text)
        let narrationSentences = isNarrating ? buildNarrationSentences() : []
        let currentIndex = isNarrating ? findCurrentSentence(narrationSentences) : -1

        // Always use the same sentence layout (from the raw text) to prevent shifts
        VStack(alignment: .leading, spacing: DT.Space.sm) {
            ForEach(Array(staticSentences.enumerated()), id: \.offset) { index, sentence in
                Text(sentence)
                    .font(DT.Typo.bodySerif)
                    .lineSpacing(6)
                    .foregroundStyle(sentenceColor(index: index, current: currentIndex, total: staticSentences.count, narrating: isNarrating))
                    .animation(.easeOut(duration: 0.3), value: currentIndex)
            }
        }
    }

    /// Split raw text into sentences by punctuation
    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if ".!?:".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { sentences.append(trimmed) }
        return sentences
    }

    private func sentenceColor(index: Int, current: Int, total: Int, narrating: Bool) -> Color {
        if !narrating {
            return DT.Colors.fog.opacity(0.85)  // uniform when not playing
        }
        if index == current { return DT.Colors.fog }         // active
        if index < current { return DT.Colors.steel }         // past
        return DT.Colors.smoke                                // future
    }

    // MARK: - Narration sentence mapping

    private struct NarrationSentence {
        let startWordIndex: Int
        let endWordIndex: Int
    }

    private func buildNarrationSentences() -> [NarrationSentence] {
        let words = narration.wordTimings
        guard !words.isEmpty else { return [] }

        var sentences: [NarrationSentence] = []
        var startIndex = 0

        for (i, timing) in words.enumerated() {
            let isEnd = timing.word.hasSuffix(".") || timing.word.hasSuffix("!") || timing.word.hasSuffix("?") || timing.word.hasSuffix(":") || i == words.count - 1
            if isEnd {
                sentences.append(NarrationSentence(startWordIndex: startIndex, endWordIndex: i))
                startIndex = i + 1
            }
        }

        return sentences
    }

    private func findCurrentSentence(_ sentences: [NarrationSentence]) -> Int {
        let current = narration.currentWordIndex
        for (i, sentence) in sentences.enumerated() {
            if current >= sentence.startWordIndex && current <= sentence.endWordIndex {
                return i
            }
        }
        return -1
    }
}
