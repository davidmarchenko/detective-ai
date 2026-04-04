import SwiftUI

struct MysteryLobbyView: View {
    @Bindable var gameState: GameState
    @State private var scenarios: [MysteryScenario] = []
    @State private var selectedMode: GameMode = .quickPlay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Murder Mystery")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                    Text("Interrogate suspects. Uncover clues. Solve the case.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Mode picker
                Picker("Game Mode", selection: $selectedMode) {
                    Text("Quick Play (5 min)").tag(GameMode.quickPlay)
                    Text("Full Case (30 min)").tag(GameMode.standardPlay)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Cases
                VStack(spacing: 16) {
                    ForEach(scenarios) { scenario in
                        CaseCard(scenario: scenario, mode: selectedMode) {
                            gameState.startGame(mystery: scenario, mode: selectedMode)
                        }
                    }

                    if scenarios.isEmpty {
                        ContentUnavailableView(
                            "No Cases Available",
                            systemImage: "magnifyingglass",
                            description: Text("Mystery scenarios could not be loaded.")
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Cases")
        .onAppear {
            scenarios = MysteryLoader.loadAll()
            // Fallback: try loading by known name
            if scenarios.isEmpty, let s = MysteryLoader.load(named: "mystery_villa_morada") {
                scenarios = [s]
            }
        }
    }
}

// MARK: - Case Card

private struct CaseCard: View {
    let scenario: MysteryScenario
    let mode: GameMode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Spacer()
                    Text(mode == .quickPlay ? "5 min" : "30 min")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Text(scenario.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text("Victim: \(scenario.victimName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(scenario.suspects.count) suspects")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if mode == .quickPlay {
                    Text("Interrogate 1 suspect")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Interrogate all \(scenario.suspects.count) suspects")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
