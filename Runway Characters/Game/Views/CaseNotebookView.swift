import SwiftUI

struct CaseNotebookView: View {
    @Bindable var gameState: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Case summary
                    if let mystery = gameState.mystery {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                notebookLabel("VICTIM")
                                Text(mystery.victimName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)

                                notebookLabel("LOCATION")
                                Text(mystery.setting)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))

                                notebookLabel("BRIEFING")
                                Text(mystery.briefing)
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Suspects
                    Section {
                        notebookLabel("SUSPECTS")
                        ForEach(gameState.suspectsAvailable) { suspect in
                            suspectRow(suspect)
                        }
                    }

                    // Clues grouped by suspect
                    if !gameState.discoveredClues.isEmpty {
                        Section {
                            notebookLabel("CLUES (\(gameState.discoveredClues.count))")
                            legendRow

                            let grouped = Dictionary(grouping: gameState.discoveredClues) { $0.suspectId }
                            ForEach(gameState.suspectsAvailable) { suspect in
                                if let clues = grouped[suspect.id], !clues.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(suspect.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.orange)
                                        ForEach(clues) { clue in
                                            HStack(alignment: .top, spacing: 8) {
                                                Circle()
                                                    .fill(clueColor(clue.importance))
                                                    .frame(width: 6, height: 6)
                                                    .padding(.top, 5)
                                                Text(clue.text)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Contradictions
                    if !gameState.contradictions.isEmpty {
                        Section {
                            notebookLabel("CONTRADICTIONS (\(gameState.contradictions.count))")
                            ForEach(Array(gameState.contradictions.enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(gameState.suspect(for: item.suspectId)?.name ?? item.suspectId)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.red)
                                    Text("Said: \"\(item.original)\"")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .strikethrough()
                                    Text("Then: \"\(item.corrected)\"")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .padding(8)
                                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
            }
            .background(Color.black)
            .navigationTitle("Case Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Components

    private func suspectRow(_ suspect: SuspectDefinition) -> some View {
        let interviewed = gameState.interviewedSuspects.contains(suspect.id)
        let clueCount = gameState.discoveredClues.filter { $0.suspectId == suspect.id }.count

        return HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(interviewed ? .green.opacity(0.6) : .white.opacity(0.3))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(suspect.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if interviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    }
                }
                Text(suspect.role)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                Text(suspect.briefDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }

            Spacer()

            if clueCount > 0 {
                Text("\(clueCount) clue\(clueCount == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendDot(color: .red, label: "Critical")
            legendDot(color: .orange, label: "Supporting")
            legendDot(color: .gray, label: "Red herring")
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.4))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }

    private func notebookLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.orange)
            .tracking(2)
    }

    private func clueColor(_ importance: String) -> Color {
        switch importance {
        case "critical": .red
        case "supporting": .orange
        case "red_herring": .gray
        default: .white
        }
    }
}
