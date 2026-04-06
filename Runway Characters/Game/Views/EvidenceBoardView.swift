import SwiftUI

struct EvidenceBoardView: View {
    @Bindable var gameState: GameState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: DT.Space.sm) {
                    Image(systemName: "pin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DT.Colors.warmGlow)
                    NoirSectionLabel(text: "EVIDENCE BOARD")
                }
                .frame(maxWidth: .infinity)
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
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                // Clues
                if !gameState.discoveredClues.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
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
                            clueCard(clue)
                        }
                    }
                }

                // Contradictions
                if !gameState.contradictions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        NoirSectionLabel(text: "CONTRADICTIONS (\(gameState.contradictions.count))", color: DT.Colors.ember)

                        ForEach(Array(gameState.contradictions.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(suspectName(item.suspectId))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(DT.Colors.ember)
                                Text("Said: \"\(item.original)\"")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DT.Colors.smoke)
                                    .strikethrough()
                                Text("Then: \"\(item.corrected)\"")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DT.Colors.fog.opacity(0.85))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DT.Colors.ember.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }
                }

                // Suspicion shifts
                if !gameState.suspicionShifts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        NoirSectionLabel(text: "SUSPECT ACCUSATIONS", color: DT.Colors.suspicion)

                        ForEach(Array(gameState.suspicionShifts.enumerated()), id: \.offset) { _, shift in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(DT.Colors.suspicion)
                                    .padding(.top, 2)
                                Text("\(suspectName(shift.from)) blames \(shift.target): \"\(shift.reason)\"")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DT.Colors.fog.opacity(0.7))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                // Navigation
                HStack(spacing: 12) {
                    Button { gameState.returnToSuspectBoard() } label: {
                        Text("Back to Suspects")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DT.Colors.fog)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DT.Colors.steel.opacity(0.2), lineWidth: 0.5))
                    }

                    Button { gameState.goToAccusation() } label: {
                        Text("Make Accusation")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DT.Colors.fog)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DT.Colors.ember, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .noirBackground(ambient: DT.Colors.suggestion)
    }

    // MARK: - Clue Card (simple, no evidenceCard modifier)

    private func clueCard(_ clue: DiscoveredClue) -> some View {
        let color = clueColor(clue.importance)
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(clue.text)
                    .font(.system(size: 14))
                    .foregroundStyle(DT.Colors.fog.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Text("From: \(suspectName(clue.suspectId))")
                    .font(.system(size: 11))
                    .foregroundStyle(DT.Colors.smoke)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

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
            Text(label)
        }
    }
}
