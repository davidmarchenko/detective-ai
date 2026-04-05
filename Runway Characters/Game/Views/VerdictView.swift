import SwiftUI

struct VerdictView: View {
    @Bindable var gameState: GameState
    @State private var revealPhase = 0
    @State private var showExplanation = false
    @State private var scanLineOffset: CGFloat = 0
    @State private var typewriterText = ""
    @State private var scoreValues: [Int] = [0, 0, 0, 0, 0] // animated counters

    var body: some View {
        let isCorrect = gameState.score?.correctAccusation ?? false

        ScrollView {
            VStack(spacing: DT.Space.xxl) {
                Spacer().frame(height: 40)

                // Phase 0: Analyzing
                if revealPhase == 0 {
                    VStack(spacing: DT.Space.lg) {
                        // Scanning line
                        ZStack {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DT.Colors.warmGlow.opacity(0.6))
                                .frame(width: 200, height: 2)
                                .offset(y: scanLineOffset)
                                .shadow(color: DT.Colors.warmGlow.opacity(0.4), radius: 6)
                        }
                        .frame(height: 60)
                        .clipped()

                        Text("Analyzing evidence...")
                            .font(DT.Typo.bodySerif)
                            .foregroundStyle(DT.Colors.steel)
                    }
                }

                // Phase 1: "The killer was..."
                if revealPhase >= 1 {
                    Text(typewriterText)
                        .font(DT.Typo.bodySerif)
                        .foregroundStyle(DT.Colors.steel)
                        .transition(.opacity)
                }

                // Phase 2: Name + seal
                if revealPhase >= 2, let mystery = gameState.mystery {
                    let guilty = mystery.suspects.first { $0.id == mystery.solution.guiltySubjectId }

                    VStack(spacing: DT.Space.lg) {
                        Text(guilty?.name ?? "Unknown")
                            .font(DT.Typo.displayTitle)
                            .foregroundStyle(DT.Colors.fog)
                            .shadow(color: (isCorrect ? DT.Colors.success : DT.Colors.ember).opacity(0.3), radius: 16)
                            .transition(.scale.combined(with: .opacity))

                        Image(systemName: isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(isCorrect ? DT.Colors.success : DT.Colors.ember)
                            .shadow(color: (isCorrect ? DT.Colors.success : DT.Colors.ember).opacity(0.5), radius: 12)
                            .symbolEffect(.bounce, value: revealPhase)

                        NoirSectionLabel(
                            text: isCorrect ? "CASE CLOSED" : "WRONG SUSPECT",
                            color: isCorrect ? DT.Colors.success : DT.Colors.ember
                        )
                        .tracking(3)

                        if let score = gameState.score {
                            Text(score.rating)
                                .font(DT.Typo.screenTitle)
                                .foregroundStyle(DT.Colors.fog)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Phase 3: Score breakdown
                if revealPhase >= 3, let score = gameState.score {
                    VStack(spacing: DT.Space.md) {
                        scoreRow("Clues Found", value: "\(score.cluesFound)/\(score.totalClues)", pts: scoreValues[0], target: score.cluesFound * 10)
                        scoreRow("Contradictions", value: "\(score.contradictionsCaught)", pts: scoreValues[1], target: score.contradictionsCaught * 25)
                        scoreRow("Correct Suspect", value: score.correctAccusation ? "Yes" : "No", pts: scoreValues[2], target: score.correctAccusation ? 100 : 0)
                        scoreRow("Correct Motive", value: score.correctMotive ? "Yes" : "No", pts: scoreValues[3], target: score.correctMotive ? 50 : 0)

                        Divider().background(DT.Colors.warmGlow.opacity(0.2))

                        HStack {
                            Text("TOTAL")
                                .font(DT.Typo.sectionLabel)
                                .foregroundStyle(DT.Colors.warmGlow)
                            Spacer()
                            Text("\(scoreValues[4]) pts")
                                .font(.system(size: 22, weight: .bold).monospacedDigit())
                                .foregroundStyle(DT.Colors.warmGlow)
                                .shadow(color: DT.Colors.warmGlow.opacity(0.3), radius: 8)
                        }
                    }
                    .evidenceCard(accent: DT.Colors.warmGlow)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Phase 4: The truth
                if revealPhase >= 4, let mystery = gameState.mystery {
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        Button { withAnimation { showExplanation.toggle() } } label: {
                            HStack {
                                NoirSectionLabel(text: "THE FULL STORY")
                                Spacer()
                                Image(systemName: showExplanation ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(DT.Colors.warmGlow)
                            }
                        }

                        if showExplanation {
                            VStack(alignment: .leading, spacing: DT.Space.md) {
                                NoirSectionLabel(text: "MOTIVE")
                                Text(mystery.solution.motive)
                                    .font(DT.Typo.bodySerif)
                                    .foregroundStyle(DT.Colors.fog.opacity(0.8))
                                    .lineSpacing(3)

                                NoirSectionLabel(text: "WHAT HAPPENED")
                                Text(mystery.solution.explanation)
                                    .font(DT.Typo.bodySerif)
                                    .foregroundStyle(DT.Colors.fog.opacity(0.8))
                                    .lineSpacing(3)
                            }
                            .transition(.opacity)
                        }
                    }
                    .evidenceCard(accent: DT.Colors.steel)
                    .transition(.opacity)

                    // Action buttons
                    VStack(spacing: DT.Space.md) {
                        Button { gameState.replayCurrentCase() } label: {
                            Text("Play Again")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(DT.Colors.void)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DT.Grad.buttonGradient(DT.Colors.warmGlow), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                        }

                        Button { gameState.resetToLobby() } label: {
                            Text("Return to Cases")
                                .font(DT.Typo.caption)
                                .foregroundStyle(DT.Colors.steel)
                        }
                    }
                    .padding(.top, DT.Space.sm)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .noirBackground(ambient: revealPhase >= 2 ? (isCorrect ? DT.Colors.success : DT.Colors.ember) : .clear)
        .animation(.easeOut(duration: 0.5), value: revealPhase)
        .task {
            // Scanning line animation
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                scanLineOffset = 20
            }

            // Phase 0 → 1
            try? await Task.sleep(for: .seconds(1.5))
            revealPhase = 1

            // Typewriter effect
            let fullText = "The killer was..."
            for (i, char) in fullText.enumerated() {
                try? await Task.sleep(for: .seconds(0.06))
                typewriterText = String(fullText.prefix(i + 1))
                _ = char // suppress warning
            }

            // Phase 2: reveal
            try? await Task.sleep(for: .seconds(0.8))
            revealPhase = 2

            // Phase 3: score
            try? await Task.sleep(for: .seconds(1.5))
            revealPhase = 3
            await animateScores()

            // Phase 4: truth
            try? await Task.sleep(for: .seconds(0.5))
            revealPhase = 4
            try? await Task.sleep(for: .seconds(0.5))
            showExplanation = true
        }
    }

    // MARK: - Score Animation

    private func animateScores() async {
        guard let score = gameState.score else { return }
        let targets = [
            score.cluesFound * 10,
            score.contradictionsCaught * 25,
            score.correctAccusation ? 100 : 0,
            score.correctMotive ? 50 : 0,
            score.totalPoints
        ]

        for (index, target) in targets.enumerated() {
            let steps = 20
            for step in 0...steps {
                let value = Int(Double(target) * Double(step) / Double(steps))
                scoreValues[index] = value
                try? await Task.sleep(for: .seconds(0.02))
            }
            try? await Task.sleep(for: .seconds(0.1))
        }
    }

    // MARK: - Score Row

    private func scoreRow(_ label: String, value: String, pts: Int, target: Int) -> some View {
        HStack {
            Text(label)
                .font(DT.Typo.caption)
                .foregroundStyle(DT.Colors.steel)
            Spacer()
            Text(value)
                .font(DT.Typo.caption)
                .fontWeight(.medium)
                .foregroundStyle(DT.Colors.fog)
            Text("+\(pts)")
                .font(DT.Typo.data)
                .foregroundStyle(DT.Colors.warmGlow)
                .frame(width: 50, alignment: .trailing)
        }
    }
}
