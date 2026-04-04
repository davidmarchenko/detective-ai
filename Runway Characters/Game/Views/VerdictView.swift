import SwiftUI

struct VerdictView: View {
    @Bindable var gameState: GameState
    @State private var revealPhase = 0  // 0=analyzing, 1=killer name, 2=result, 3=score, 4=truth
    @State private var showExplanation = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    // Phase 0: Analyzing
                    if revealPhase >= 0 {
                        VStack(spacing: 12) {
                            if revealPhase == 0 {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.orange)
                                Text("Analyzing evidence...")
                                    .font(.system(size: 16, design: .serif))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }

                    // Phase 1: The killer was...
                    if revealPhase >= 1 {
                        VStack(spacing: 8) {
                            Text("The killer was...")
                                .font(.system(size: 16, design: .serif))
                                .foregroundStyle(.white.opacity(0.5))
                                .transition(.opacity)
                        }
                    }

                    if revealPhase >= 2, let mystery = gameState.mystery {
                        let guilty = mystery.suspects.first { $0.id == mystery.solution.guiltySubjectId }
                        let correct = gameState.score?.correctAccusation ?? false

                        VStack(spacing: 16) {
                            // Guilty suspect name
                            Text(guilty?.name ?? "Unknown")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))

                            // Result seal
                            Image(systemName: correct ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(correct ? .green : .red)
                                .symbolEffect(.bounce, value: revealPhase)

                            Text(correct ? "CASE CLOSED" : "WRONG SUSPECT")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(correct ? .green : .red)
                                .tracking(3)

                            if let score = gameState.score {
                                Text(score.rating)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundStyle(.white)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Phase 3: Score breakdown
                    if revealPhase >= 3, let score = gameState.score {
                        VStack(spacing: 12) {
                            scoreRow("Clues Found", value: "\(score.cluesFound)/\(score.totalClues)", pts: score.cluesFound * 10)
                            scoreRow("Contradictions", value: "\(score.contradictionsCaught)", pts: score.contradictionsCaught * 25)
                            scoreRow("Correct Suspect", value: score.correctAccusation ? "Yes" : "No", pts: score.correctAccusation ? 100 : 0)
                            scoreRow("Correct Motive", value: score.correctMotive ? "Yes" : "No", pts: score.correctMotive ? 50 : 0)

                            Divider().background(.white.opacity(0.2))

                            HStack {
                                Text("TOTAL")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.orange)
                                Spacer()
                                Text("\(score.totalPoints) pts")
                                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(20)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Phase 4: The truth
                    if revealPhase >= 4, let mystery = gameState.mystery {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation { showExplanation.toggle() }
                            } label: {
                                HStack {
                                    Text("THE FULL STORY")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.orange)
                                        .tracking(2)
                                    Spacer()
                                    Image(systemName: showExplanation ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(.orange)
                                }
                            }

                            if showExplanation {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Motive")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.orange)
                                    Text(mystery.solution.motive)
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineSpacing(3)

                                    Text("What Happened")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.orange)
                                        .padding(.top, 4)
                                    Text(mystery.solution.explanation)
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineSpacing(3)
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(20)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity)

                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                gameState.replayCurrentCase()
                            } label: {
                                Text("Play Again")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                gameState.resetToLobby()
                            } label: {
                                Text("Return to Cases")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(.top, 8)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.5), value: revealPhase)
        .task {
            // Dramatic reveal sequence
            try? await Task.sleep(for: .seconds(1.5))
            revealPhase = 1
            try? await Task.sleep(for: .seconds(1.5))
            revealPhase = 2
            try? await Task.sleep(for: .seconds(1.5))
            revealPhase = 3
            try? await Task.sleep(for: .seconds(1.0))
            revealPhase = 4
            try? await Task.sleep(for: .seconds(0.5))
            showExplanation = true
        }
    }

    private func scoreRow(_ label: String, value: String, pts: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("+\(pts)")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(.orange)
                .frame(width: 50, alignment: .trailing)
        }
    }
}
