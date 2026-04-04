import SwiftUI

struct CaseBriefingView: View {
    @Bindable var gameState: GameState
    @State private var narration = NarrationService()
    @State private var narrationStarted = false

    var body: some View {
        if let mystery = gameState.mystery {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
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
                                .font(.system(size: 15))
                                .foregroundStyle(.orange)
                            }
                            Spacer()
                        }
                        .padding(.top, 8)

                        // Case file header
                        VStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                            Text("CASE FILE")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .tracking(4)
                            Text(mystery.title)
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }

                        // Crime details
                        VStack(alignment: .leading, spacing: 16) {
                            detailRow(label: "VICTIM", value: mystery.victimName)
                            detailRow(label: "LOCATION", value: mystery.setting)
                            detailRow(label: "SUSPECTS", value: "\(mystery.suspects.count) persons of interest")

                            Divider().background(.white.opacity(0.2))

                            // Narrated briefing with synced captions
                            NarratedTextView(
                                text: mystery.briefing,
                                narration: narration
                            )
                        }
                        .padding(20)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                        // Narration controls
                        HStack(spacing: 16) {
                            Button {
                                if narration.isPlaying || narration.isLoading {
                                    narration.stop()
                                } else {
                                    Task { await narration.speak(narrationText(mystery)) }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if narration.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(.orange)
                                        Text("Loading narration...")
                                    } else {
                                        Image(systemName: narration.isPlaying ? "pause.fill" : "play.fill")
                                        Text(narration.isPlaying ? "Pause" : "Listen to Briefing")
                                    }
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.orange.opacity(0.15), in: Capsule())
                            }

                            if narration.isPlaying && !narration.isLoading {
                                HStack(spacing: 3) {
                                    ForEach(0..<4, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(.orange)
                                            .frame(width: 3, height: .random(in: 8...20))
                                            .animation(
                                                .easeInOut(duration: 0.4)
                                                .repeatForever()
                                                .delay(Double(i) * 0.1),
                                                value: narration.isPlaying
                                            )
                                    }
                                }
                            }
                        }

                        // Suspect previews
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PERSONS OF INTEREST")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .tracking(2)

                            let suspects = gameState.mode == .quickPlay
                                ? mystery.suspects.filter { $0.id == mystery.quickPlaySuspectId }
                                : mystery.suspects

                            ForEach(suspects) { suspect in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suspect.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(suspect.role)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        Spacer()
                                    }
                                    Text(suspect.briefDescription)
                                        .font(.system(size: 13, design: .serif))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .lineSpacing(2)
                                }
                                .padding(12)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        // Begin button
                        Button {
                            narration.stop()
                            gameState.proceedFromBriefing()
                        } label: {
                            Text("Begin Investigation")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // Auto-start narration
                if !narrationStarted {
                    narrationStarted = true
                    await narration.speak(narrationText(mystery))
                }
            }
            .onDisappear {
                narration.stop()
            }
        }
    }

    /// Build the full narration script from the mystery
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Narrated Text View (word-by-word highlight)

struct NarratedTextView: View {
    let text: String
    @Bindable var narration: NarrationService

    var body: some View {
        if narration.wordTimings.isEmpty || !narration.isPlaying {
            // Static text when not narrating
            Text(text)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
        } else {
            // Word-by-word highlighted text
            WrappingHStack(narration: narration)
        }
    }
}

/// Renders words with karaoke-style highlighting synced to narration
private struct WrappingHStack: View {
    @Bindable var narration: NarrationService

    var body: some View {
        let words = narration.wordTimings
        let currentIndex = narration.currentWordIndex

        // Build highlighted text by concatenating Text views
        VStack(alignment: .leading, spacing: 4) {
            words.enumerated().reduce(Text("")) { result, item in
                let (i, timing) = item
                let separator = i > 0 ? Text(" ") : Text("")
                let wordView: Text
                if i == currentIndex {
                    wordView = Text(timing.word)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                } else if i < currentIndex {
                    wordView = Text(timing.word)
                        .foregroundColor(.white)
                } else {
                    wordView = Text(timing.word)
                        .foregroundColor(.white.opacity(0.3))
                }
                return result + separator + wordView
            }
            .font(.system(size: 16, design: .serif))
            .lineSpacing(4)
            .animation(.easeOut(duration: 0.1), value: currentIndex)
        }
    }
}
