import SwiftUI

struct MysteryLobbyView: View {
    @Bindable var gameState: GameState
    @State private var scenarios: [MysteryScenario] = []
    @State private var selectedMode: GameMode = .quickPlay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Space.xl) {
                // Header
                VStack(alignment: .leading, spacing: DT.Space.sm) {
                    Text("Murder Mystery")
                        .font(DT.Typo.displayTitle)
                        .foregroundStyle(DT.Colors.fog)
                        .shadow(color: DT.Colors.warmGlow.opacity(0.3), radius: 20)

                    Text("Interrogate suspects. Uncover clues. Solve the case.")
                        .font(DT.Typo.caption)
                        .foregroundStyle(DT.Colors.steel)
                }
                .padding(.horizontal, DT.Space.lg)
                .padding(.top, DT.Space.xl)

                // Mode toggle
                HStack(spacing: DT.Space.sm) {
                    modeButton("Quick Play", subtitle: "5 min", mode: .quickPlay)
                    modeButton("Full Case", subtitle: "30 min", mode: .standardPlay)
                }
                .padding(.horizontal, DT.Space.lg)

                // Cases
                VStack(spacing: DT.Space.lg) {
                    ForEach(scenarios) { scenario in
                        caseCard(scenario)
                    }

                    if scenarios.isEmpty {
                        VStack(spacing: DT.Space.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(DT.Colors.smoke)
                            Text("No cases available")
                                .font(DT.Typo.caption)
                                .foregroundStyle(DT.Colors.smoke)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, DT.Space.lg)

                Spacer().frame(height: 40)
            }
        }
        .noirBackground(ambient: DT.Colors.warmGlow)
        .onAppear {
            scenarios = MysteryLoader.loadAll()
            if scenarios.isEmpty, let s = MysteryLoader.load(named: "mystery_villa_morada") {
                scenarios = [s]
            }
        }
    }

    // MARK: - Mode Toggle Button

    private func modeButton(_ title: String, subtitle: String, mode: GameMode) -> some View {
        let isSelected = selectedMode == mode
        return Button { selectedMode = mode } label: {
            VStack(spacing: DT.Space.xs) {
                Text(title)
                    .font(DT.Typo.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(subtitle)
                    .font(DT.Typo.footnote)
                    .foregroundStyle(isSelected ? DT.Colors.warmGlow : DT.Colors.smoke)
            }
            .foregroundStyle(isSelected ? DT.Colors.fog : DT.Colors.steel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DT.Space.md)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .fill(isSelected ? DT.Colors.warmGlow.opacity(0.12) : DT.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .stroke(isSelected ? DT.Colors.warmGlow.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Case Card

    private func caseCard(_ scenario: MysteryScenario) -> some View {
        Button {
            gameState.startGame(mystery: scenario, mode: selectedMode)
        } label: {
            VStack(alignment: .leading, spacing: DT.Space.md) {
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(DT.Colors.ember)
                        .frame(width: 40, height: 40)
                        .background(DT.Colors.ember.opacity(0.12), in: Circle())
                    Spacer()
                    Text(selectedMode == .quickPlay ? "5 min" : "30 min")
                        .font(DT.Typo.tagLabel)
                        .foregroundStyle(DT.Colors.warmGlow)
                        .padding(.horizontal, DT.Space.sm)
                        .padding(.vertical, DT.Space.xs)
                        .background(DT.Colors.surfaceRaised, in: Capsule())
                }

                Text(scenario.title)
                    .font(DT.Typo.cardTitle)
                    .foregroundStyle(DT.Colors.fog)
                    .multilineTextAlignment(.leading)

                HStack(spacing: DT.Space.lg) {
                    Label(scenario.victimName, systemImage: "person.fill.xmark")
                        .font(DT.Typo.footnote)
                        .foregroundStyle(DT.Colors.steel)
                    Label("\(scenario.suspects.count) suspects", systemImage: "person.3.fill")
                        .font(DT.Typo.footnote)
                        .foregroundStyle(DT.Colors.steel)
                }
            }
            .suspectCard(status: DT.Colors.warmGlow)
        }
        .buttonStyle(.plain)
    }
}
