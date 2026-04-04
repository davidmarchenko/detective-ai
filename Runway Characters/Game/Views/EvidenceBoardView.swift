import SwiftUI

struct EvidenceBoardView: View {
    @Bindable var gameState: GameState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    VStack(spacing: 8) {
                        Image(systemName: "pin.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text("EVIDENCE BOARD")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .tracking(3)
                    }

                    if gameState.discoveredClues.isEmpty && gameState.contradictions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "questionmark.folder.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.2))
                            Text("No evidence collected yet")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 40)
                    }

                    // Clues
                    if !gameState.discoveredClues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CLUES (\(gameState.discoveredClues.count))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .tracking(2)

                            // Legend
                            HStack(spacing: 16) {
                                legendDot(color: .red, label: "Critical")
                                legendDot(color: .orange, label: "Supporting")
                                legendDot(color: .gray, label: "Red herring")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))

                            ForEach(gameState.discoveredClues) { clue in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(clueColor(clue.importance))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(clue.text)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.85))
                                        Text("From: \(suspectName(clue.suspectId))")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                                .padding(12)
                                .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Contradictions
                    if !gameState.contradictions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONTRADICTIONS (\(gameState.contradictions.count))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .tracking(2)

                            ForEach(Array(gameState.contradictions.enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                        Text(suspectName(item.suspectId))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.red)
                                    }
                                    Text("Said: \"\(item.original)\"")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .strikethrough()
                                    Text("Then: \"\(item.corrected)\"")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                .padding(12)
                                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Suspicion shifts
                    if !gameState.suspicionShifts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUSPECT ACCUSATIONS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.yellow)
                                .tracking(2)

                            ForEach(Array(gameState.suspicionShifts.enumerated()), id: \.offset) { _, shift in
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    Text("\(suspectName(shift.from)) blames \(shift.target): \"\(shift.reason)\"")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(10)
                                .background(.yellow.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Navigation
                    HStack(spacing: 12) {
                        Button {
                            gameState.returnToSuspectBoard()
                        } label: {
                            Text("Back to Suspects")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            gameState.goToAccusation()
                        } label: {
                            Text("Make Accusation")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.red, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func suspectName(_ id: String) -> String {
        gameState.suspect(for: id)?.name ?? id
    }

    private func clueColor(_ importance: String) -> Color {
        switch importance {
        case "critical": .red
        case "supporting": .orange
        case "red_herring": .gray
        default: .white
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}
