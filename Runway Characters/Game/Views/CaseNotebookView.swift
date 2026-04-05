import SwiftUI

struct CaseNotebookView: View {
    @Bindable var gameState: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DT.Space.xl) {
                    // Case summary
                    if let mystery = gameState.mystery {
                        VStack(alignment: .leading, spacing: DT.Space.sm) {
                            NoirSectionLabel(text: "VICTIM")
                            Text(mystery.victimName)
                                .font(DT.Typo.body)
                                .fontWeight(.medium)
                                .foregroundStyle(DT.Colors.fog)

                            NoirSectionLabel(text: "LOCATION")
                            Text(mystery.setting)
                                .font(DT.Typo.caption)
                                .foregroundStyle(DT.Colors.steel)

                            NoirSectionLabel(text: "BRIEFING")
                            Text(mystery.briefing)
                                .font(DT.Typo.evidence)
                                .foregroundStyle(DT.Colors.steel)
                                .lineSpacing(3)
                        }
                        .evidenceCard(accent: DT.Colors.warmGlow)
                    }

                    // Suspects
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        NoirSectionLabel(text: "SUSPECTS")
                        ForEach(gameState.suspectsAvailable) { suspect in
                            suspectRow(suspect)
                        }
                    }

                    // Clues grouped by suspect
                    if !gameState.discoveredClues.isEmpty {
                        VStack(alignment: .leading, spacing: DT.Space.md) {
                            NoirSectionLabel(text: "CLUES (\(gameState.discoveredClues.count))")

                            HStack(spacing: DT.Space.lg) {
                                legendDot(color: DT.Colors.ember, label: "Critical")
                                legendDot(color: DT.Colors.warmGlow, label: "Supporting")
                                legendDot(color: DT.Colors.smoke, label: "Red herring")
                            }
                            .font(DT.Typo.tagLabel)
                            .foregroundStyle(DT.Colors.smoke)

                            let grouped = Dictionary(grouping: gameState.discoveredClues) { $0.suspectId }
                            ForEach(gameState.suspectsAvailable) { suspect in
                                if let clues = grouped[suspect.id], !clues.isEmpty {
                                    VStack(alignment: .leading, spacing: DT.Space.sm) {
                                        Text(suspect.name)
                                            .font(DT.Typo.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(DT.Colors.warmGlow)
                                        ForEach(clues) { clue in
                                            HStack(alignment: .top, spacing: DT.Space.sm) {
                                                Circle()
                                                    .fill(clueColor(clue.importance))
                                                    .frame(width: 6, height: 6)
                                                    .shadow(color: clueColor(clue.importance).opacity(0.4), radius: 3)
                                                    .padding(.top, 5)
                                                Text(clue.text)
                                                    .font(DT.Typo.footnote)
                                                    .foregroundStyle(DT.Colors.fog.opacity(0.8))
                                            }
                                        }
                                    }
                                    .padding(DT.Space.md)
                                    .background(DT.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                                }
                            }
                        }
                    }

                    // Contradictions
                    if !gameState.contradictions.isEmpty {
                        VStack(alignment: .leading, spacing: DT.Space.md) {
                            NoirSectionLabel(text: "CONTRADICTIONS (\(gameState.contradictions.count))", color: DT.Colors.ember)

                            ForEach(Array(gameState.contradictions.enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: DT.Space.xs) {
                                    Text(gameState.suspect(for: item.suspectId)?.name ?? item.suspectId)
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

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, DT.Space.lg)
            }
            .background(DT.Colors.void)
            .navigationTitle("Case Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DT.Colors.warmGlow)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Suspect Row

    private func suspectRow(_ suspect: SuspectDefinition) -> some View {
        let interviewed = gameState.interviewedSuspects.contains(suspect.id)
        let clueCount = gameState.discoveredClues.filter { $0.suspectId == suspect.id }.count

        return HStack(spacing: DT.Space.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(interviewed ? DT.Colors.success.opacity(0.6) : DT.Colors.smoke)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(suspect.name)
                        .font(DT.Typo.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DT.Colors.fog)
                    if interviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DT.Colors.success)
                    }
                }
                Text(suspect.role)
                    .font(DT.Typo.footnote)
                    .foregroundStyle(DT.Colors.smoke)
                Text(suspect.briefDescription)
                    .font(DT.Typo.tagLabel)
                    .foregroundStyle(DT.Colors.smoke)
                    .lineLimit(2)
            }

            Spacer()

            if clueCount > 0 {
                Text("\(clueCount) clue\(clueCount == 1 ? "" : "s")")
                    .font(DT.Typo.tagLabel)
                    .foregroundStyle(DT.Colors.warmGlow)
            }
        }
        .padding(DT.Space.md)
        .background(DT.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: DT.Radius.sm))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.4), radius: 3)
            Text(label)
        }
    }

    private func clueColor(_ importance: String) -> Color {
        switch importance {
        case "critical": DT.Colors.ember
        case "supporting": DT.Colors.warmGlow
        case "red_herring": DT.Colors.smoke
        default: DT.Colors.fog
        }
    }
}
