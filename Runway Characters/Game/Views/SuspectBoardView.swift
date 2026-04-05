import SwiftUI

struct SuspectBoardView: View {
    @Bindable var gameState: GameState
    @State private var showNotebook = false

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Space.xl) {
                // Top bar
                HStack {
                    Button { showNotebook = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.closed.fill")
                            Text("Case Notebook")
                        }
                        .font(DT.Typo.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DT.Colors.warmGlow)
                    }
                    Spacer()
                }
                .padding(.top, DT.Space.sm)

                // Header
                VStack(spacing: DT.Space.sm) {
                    NoirSectionLabel(text: "SUSPECT BOARD")
                    Text("Choose who to interrogate")
                        .font(DT.Typo.caption)
                        .foregroundStyle(DT.Colors.steel)
                }

                // Suspects
                ForEach(gameState.suspectsAvailable) { suspect in
                    suspectCard(suspect)
                }

                // Evidence count
                if !gameState.discoveredClues.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DT.Colors.warmGlow)
                        Text("\(gameState.discoveredClues.count) clue(s) collected")
                            .font(DT.Typo.caption)
                            .foregroundStyle(DT.Colors.steel)
                        Spacer()
                        Button("Review Evidence") { gameState.phase = .evidence }
                            .font(DT.Typo.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DT.Colors.warmGlow)
                    }
                    .evidenceCard(accent: DT.Colors.warmGlow)
                }

                // Accuse button
                if !gameState.interviewedSuspects.isEmpty {
                    Button { gameState.goToAccusation() } label: {
                        Text("Ready to Accuse")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DT.Colors.fog)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DT.Grad.buttonGradient(DT.Colors.ember), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    }
                    .breathingGlow(DT.Colors.ember)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .noirBackground(ambient: DT.Colors.warmGlow)
        .sheet(isPresented: $showNotebook) {
            CaseNotebookView(gameState: gameState)
        }
    }

    private func suspectCard(_ suspect: SuspectDefinition) -> some View {
        let interviewed = gameState.interviewedSuspects.contains(suspect.id)
        let statusColor = interviewed ? DT.Colors.success : DT.Colors.warmGlow

        return Button {
            gameState.startInterrogation(suspectId: suspect.id)
        } label: {
            HStack(spacing: 14) {
                // Avatar with status ring
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(interviewed ? DT.Colors.success.opacity(0.5) : DT.Colors.steel)
                }

                VStack(alignment: .leading, spacing: DT.Space.xs) {
                    Text(suspect.name)
                        .font(DT.Typo.cardTitle)
                        .foregroundStyle(DT.Colors.fog)
                    Text(suspect.role)
                        .font(DT.Typo.caption)
                        .foregroundStyle(DT.Colors.steel)
                    Text(suspect.briefDescription)
                        .font(DT.Typo.footnote)
                        .foregroundStyle(DT.Colors.smoke)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: DT.Space.sm) {
                    if interviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DT.Colors.success)
                    } else {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(DT.Colors.warmGlow)
                            .symbolEffect(.pulse)
                    }
                    let clueCount = gameState.discoveredClues.filter { $0.suspectId == suspect.id }.count
                    if clueCount > 0 {
                        Text("\(clueCount) clue\(clueCount == 1 ? "" : "s")")
                            .font(DT.Typo.tagLabel)
                            .foregroundStyle(DT.Colors.warmGlow)
                    }
                }
            }
            .suspectCard(status: statusColor)
        }
        .buttonStyle(.plain)
    }
}
