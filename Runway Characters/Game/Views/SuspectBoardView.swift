import SwiftUI

struct SuspectBoardView: View {
    @Bindable var gameState: GameState
    @State private var showNotebook = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Top bar with case file button
                    HStack {
                        Button {
                            showNotebook = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "book.closed.fill")
                                Text("Case Notebook")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text("SUSPECT BOARD")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .tracking(3)
                        Text("Choose who to interrogate")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Suspects
                    ForEach(gameState.suspectsAvailable) { suspect in
                        suspectCard(suspect)
                    }

                    // Evidence count
                    if !gameState.discoveredClues.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.orange)
                            Text("\(gameState.discoveredClues.count) clue(s) collected")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Button("Review Evidence") {
                                gameState.phase = .evidence
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        }
                        .padding(16)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Ready to accuse
                    if !gameState.interviewedSuspects.isEmpty {
                        Button {
                            gameState.goToAccusation()
                        } label: {
                            Text("Ready to Accuse")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.red, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNotebook) {
            CaseNotebookView(gameState: gameState)
        }
    }

    private func suspectCard(_ suspect: SuspectDefinition) -> some View {
        let interviewed = gameState.interviewedSuspects.contains(suspect.id)

        return Button {
            gameState.startInterrogation(suspectId: suspect.id)
        } label: {
            HStack(spacing: 14) {
                // Avatar icon
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(interviewed ? .green.opacity(0.5) : .white.opacity(0.4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(suspect.name)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text(suspect.role)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(suspect.briefDescription)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 6) {
                    if interviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.orange)
                    }
                    let clueCount = gameState.discoveredClues.filter { $0.suspectId == suspect.id }.count
                    if clueCount > 0 {
                        Text("\(clueCount) clue\(clueCount == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(interviewed ? .green.opacity(0.3) : .orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
