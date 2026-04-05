import SwiftUI

struct EvidenceBoardView: View {
    @Bindable var gameState: GameState

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Space.xl) {
                // Header
                VStack(spacing: DT.Space.sm) {
                    Image(systemName: "pin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DT.Colors.warmGlow)
                        .shadow(color: DT.Colors.warmGlow.opacity(0.3), radius: 10)
                    NoirSectionLabel(text: "EVIDENCE BOARD")
                }
                .padding(.top, DT.Space.lg)

                if gameState.discoveredClues.isEmpty && gameState.contradictions.isEmpty {
                    VStack(spacing: DT.Space.md) {
                        Image(systemName: "questionmark.folder.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(DT.Colors.smoke)
                        Text("No evidence collected yet")
                            .font(DT.Typo.caption)
                            .foregroundStyle(DT.Colors.smoke)
                    }
                    .padding(.top, 40)
                }

                // Clues
                if !gameState.discoveredClues.isEmpty {
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        NoirSectionLabel(text: "CLUES (\(gameState.discoveredClues.count))")

                        // Legend
                        HStack(spacing: DT.Space.lg) {
                            legendDot(color: DT.Colors.ember, label: "Critical")
                            legendDot(color: DT.Colors.warmGlow, label: "Supporting")
                            legendDot(color: DT.Colors.smoke, label: "Red herring")
                        }
                        .font(DT.Typo.tagLabel)
                        .foregroundStyle(DT.Colors.smoke)

                        ForEach(gameState.discoveredClues) { clue in
                            HStack(alignment: .top, spacing: DT.Space.md) {
                                Circle()
                                    .fill(clueColor(clue.importance))
                                    .frame(width: 8, height: 8)
                                    .shadow(color: clueColor(clue.importance).opacity(0.5), radius: 4)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(clue.text)
                                        .font(DT.Typo.evidence)
                                        .foregroundStyle(DT.Colors.fog.opacity(0.85))
                                    Text("From: \(suspectName(clue.suspectId))")
                                        .font(DT.Typo.tagLabel)
                                        .foregroundStyle(DT.Colors.smoke)
                                }
                            }
                            .evidenceCard(accent: clueColor(clue.importance))
                        }
                    }
                }

                // Contradictions
                if !gameState.contradictions.isEmpty {
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        NoirSectionLabel(text: "CONTRADICTIONS (\(gameState.contradictions.count))", color: DT.Colors.ember)

                        ForEach(Array(gameState.contradictions.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: DT.Space.sm) {
                                Text(suspectName(item.suspectId))
                                    .font(DT.Typo.tagLabel)
                                    .foregroundStyle(DT.Colors.ember)
                                Text("Said: \"\(item.original)\"")
                                    .font(DT.Typo.footnote)
                                    .foregroundStyle(DT.Colors.smoke)
                                    .strikethrough()
                                Text("Then: \"\(item.corrected)\"")
                                    .font(DT.Typo.footnote)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DT.Colors.fog.opacity(0.85))
                            }
                            .evidenceCard(accent: DT.Colors.ember)
                        }
                    }
                }

                // Suspicion shifts
                if !gameState.suspicionShifts.isEmpty {
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        NoirSectionLabel(text: "SUSPECT ACCUSATIONS", color: DT.Colors.suspicion)

                        ForEach(Array(gameState.suspicionShifts.enumerated()), id: \.offset) { _, shift in
                            HStack(spacing: DT.Space.sm) {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(DT.Colors.suspicion)
                                Text("\(suspectName(shift.from)) blames \(shift.target): \"\(shift.reason)\"")
                                    .font(DT.Typo.footnote)
                                    .foregroundStyle(DT.Colors.fog.opacity(0.7))
                            }
                            .evidenceCard(accent: DT.Colors.suspicion)
                        }
                    }
                }

                // Navigation
                HStack(spacing: DT.Space.md) {
                    Button { gameState.returnToSuspectBoard() } label: {
                        Text("Back to Suspects")
                            .font(DT.Typo.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DT.Colors.fog)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.Colors.steel.opacity(0.2), lineWidth: 0.5))
                    }

                    Button { gameState.goToAccusation() } label: {
                        Text("Make Accusation")
                            .font(DT.Typo.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DT.Colors.fog)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DT.Grad.buttonGradient(DT.Colors.ember), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    }
                }
                .padding(.top, DT.Space.sm)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .noirBackground(ambient: DT.Colors.suggestion)
    }

    private func suspectName(_ id: String) -> String {
        gameState.suspect(for: id)?.name ?? id
    }

    private func clueColor(_ importance: String) -> Color {
        switch importance {
        case "critical": DT.Colors.ember
        case "supporting": DT.Colors.warmGlow
        case "red_herring": DT.Colors.smoke
        default: DT.Colors.fog
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.4), radius: 3)
            Text(label)
        }
    }
}
