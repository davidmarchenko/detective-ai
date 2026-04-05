import SwiftUI

struct CaseBriefingView: View {
    @Bindable var gameState: GameState
    @State private var narration = NarrationService()
    @State private var narrationStarted = false
    @State private var showContent = false

    var body: some View {
        if let mystery = gameState.mystery {
            ScrollView {
                VStack(spacing: DT.Space.xl) {
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
                    .padding(.top, DT.Space.sm)

                    // Case file header — staggered entrance
                    VStack(spacing: DT.Space.sm) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(DT.Colors.warmGlow)
                            .shadow(color: DT.Colors.warmGlow.opacity(0.3), radius: 12)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 10)

                        Text("CASE FILE")
                            .font(DT.Typo.sectionLabel)
                            .foregroundStyle(DT.Colors.warmGlow)
                            .tracking(4)
                            .opacity(showContent ? 1 : 0)

                        Text(mystery.title)
                            .font(DT.Typo.screenTitle)
                            .foregroundStyle(DT.Colors.fog)
                            .multilineTextAlignment(.center)
                            .shadow(color: DT.Colors.warmGlow.opacity(0.15), radius: 16)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 8)
                    }

                    // Crime details card
                    VStack(alignment: .leading, spacing: DT.Space.lg) {
                        detailRow(label: "VICTIM", value: mystery.victimName)
                        Divider().background(DT.Colors.warmGlow.opacity(0.15))
                        detailRow(label: "LOCATION", value: mystery.setting)
                        Divider().background(DT.Colors.warmGlow.opacity(0.15))
                        detailRow(label: "SUSPECTS", value: "\(mystery.suspects.count) persons of interest")
                        Divider().background(DT.Colors.warmGlow.opacity(0.15))

                        NarratedTextView(text: mystery.briefing, narration: narration)
                    }
                    .evidenceCard(accent: DT.Colors.warmGlow)

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
                            .background(DT.Colors.warmGlow.opacity(0.12), in: Capsule())
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

                    // Suspects
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        NoirSectionLabel(text: "PERSONS OF INTEREST")

                        let suspects = gameState.mode == .quickPlay
                            ? mystery.suspects.filter { $0.id == mystery.quickPlaySuspectId }
                            : mystery.suspects

                        ForEach(suspects) { suspect in
                            VStack(alignment: .leading, spacing: DT.Space.sm) {
                                HStack(spacing: DT.Space.md) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(DT.Colors.steel)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suspect.name)
                                            .font(DT.Typo.cardTitle)
                                            .foregroundStyle(DT.Colors.fog)
                                        Text(suspect.role)
                                            .font(DT.Typo.footnote)
                                            .foregroundStyle(DT.Colors.steel)
                                    }
                                    Spacer()
                                }
                                Text(suspect.briefDescription)
                                    .font(DT.Typo.evidence)
                                    .foregroundStyle(DT.Colors.smoke)
                                    .lineSpacing(2)
                            }
                            .suspectCard(status: DT.Colors.warmGlow)
                        }
                    }

                    // Begin button
                    Button {
                        narration.stop()
                        gameState.proceedFromBriefing()
                    } label: {
                        Text("Begin Investigation")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DT.Colors.void)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DT.Space.lg)
                            .background(DT.Grad.buttonGradient(DT.Colors.warmGlow), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    }
                    .breathingGlow(DT.Colors.warmGlow)
                    .padding(.top, DT.Space.sm)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .noirBackground(ambient: DT.Colors.warmGlow)
            .task {
                withAnimation(.easeOut(duration: 0.8)) { showContent = true }
                if !narrationStarted {
                    narrationStarted = true
                    await narration.speakBriefing(scenarioId: mystery.id, text: narrationText(mystery))
                }
            }
            .onDisappear { narration.stop() }
        }
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

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(DT.Typo.tagLabel)
                .foregroundStyle(DT.Colors.warmGlow)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(DT.Typo.caption)
                .foregroundStyle(DT.Colors.fog.opacity(0.8))
        }
    }
}

// MARK: - Narrated Text View

struct NarratedTextView: View {
    let text: String
    @Bindable var narration: NarrationService

    var body: some View {
        if narration.wordTimings.isEmpty || !narration.isPlaying {
            Text(text)
                .font(DT.Typo.bodySerif)
                .foregroundStyle(DT.Colors.fog.opacity(0.85))
                .lineSpacing(4)
        } else {
            WrappingHStack(narration: narration)
        }
    }
}

private struct WrappingHStack: View {
    @Bindable var narration: NarrationService

    var body: some View {
        let words = narration.wordTimings
        let currentIndex = narration.currentWordIndex

        VStack(alignment: .leading, spacing: 4) {
            words.enumerated().reduce(Text("")) { result, item in
                let (i, timing) = item
                let separator = i > 0 ? Text(" ") : Text("")
                let wordView: Text
                if i == currentIndex {
                    wordView = Text(timing.word)
                        .foregroundColor(DT.Colors.warmGlow)
                        .fontWeight(.semibold)
                } else if i < currentIndex {
                    wordView = Text(timing.word)
                        .foregroundColor(DT.Colors.fog)
                } else {
                    wordView = Text(timing.word)
                        .foregroundColor(DT.Colors.smoke)
                }
                return result + separator + wordView
            }
            .font(DT.Typo.bodySerif)
            .lineSpacing(4)
            .animation(.easeOut(duration: 0.1), value: currentIndex)
        }
    }
}
