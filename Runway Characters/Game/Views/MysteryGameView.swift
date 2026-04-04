import SwiftUI

struct MysteryGameView: View {
    @State private var gameState = GameState()

    var body: some View {
        Group {
            switch gameState.phase {
            case .lobby:
                NavigationStack {
                    MysteryLobbyView(gameState: gameState)
                }

            case .briefing:
                CaseBriefingView(gameState: gameState)

            case .suspectBoard:
                SuspectBoardView(gameState: gameState)

            case .interrogation(let suspectId):
                if let suspect = gameState.suspect(for: suspectId) {
                    InterrogationView(gameState: gameState, suspect: suspect)
                }

            case .evidence:
                EvidenceBoardView(gameState: gameState)

            case .accusation:
                AccusationView(gameState: gameState)

            case .verdict:
                VerdictView(gameState: gameState)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState.phase)
    }
}
