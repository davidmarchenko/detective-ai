import SwiftUI

struct AccusationView: View {
    @Bindable var gameState: GameState
    @State private var selectedSuspect: String?
    @State private var motiveText: String = ""
    @State private var reticleRotation: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Space.xl) {
                // Back to evidence
                HStack {
                    Button { gameState.returnToEvidence() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Review Evidence")
                        }
                        .font(DT.Typo.caption)
                        .foregroundStyle(DT.Colors.warmGlow)
                    }
                    Spacer()
                }
                .padding(.top, DT.Space.sm)

                // Header with reticle
                VStack(spacing: DT.Space.md) {
                    // Reticle icon
                    ZStack {
                        Circle()
                            .stroke(DT.Colors.ember.opacity(0.3), lineWidth: 1)
                            .frame(width: 60, height: 60)
                        Circle()
                            .stroke(DT.Colors.ember.opacity(0.5), lineWidth: 1)
                            .frame(width: 40, height: 40)
                        // Crosshairs
                        Path { p in
                            p.move(to: CGPoint(x: 35, y: 0))
                            p.addLine(to: CGPoint(x: 35, y: 70))
                            p.move(to: CGPoint(x: 0, y: 35))
                            p.addLine(to: CGPoint(x: 70, y: 35))
                        }
                        .stroke(DT.Colors.ember.opacity(0.4), lineWidth: 0.5)
                        .frame(width: 70, height: 70)
                    }
                    .rotationEffect(.degrees(reticleRotation))
                    .shadow(color: DT.Colors.ember.opacity(0.3), radius: 12)
                    .onAppear {
                        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                            reticleRotation = 360
                        }
                    }

                    NoirSectionLabel(text: "MAKE YOUR ACCUSATION", color: DT.Colors.ember)

                    Text("Who killed \(gameState.mystery?.victimName ?? "the victim")?")
                        .font(DT.Typo.screenTitle)
                        .foregroundStyle(DT.Colors.fog)
                }

                // Evidence by suspect
                if !gameState.discoveredClues.isEmpty {
                    VStack(alignment: .leading, spacing: DT.Space.md) {
                        NoirSectionLabel(text: "EVIDENCE BY SUSPECT")

                        let grouped = Dictionary(grouping: gameState.discoveredClues) { $0.suspectId }
                        ForEach(gameState.suspectsAvailable) { suspect in
                            if let clues = grouped[suspect.id], !clues.isEmpty {
                                VStack(alignment: .leading, spacing: DT.Space.sm) {
                                    Text(suspect.name)
                                        .font(DT.Typo.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(DT.Colors.steel)
                                    ForEach(clues) { clue in
                                        HStack(alignment: .top, spacing: 6) {
                                            Circle()
                                                .fill(clue.importance == "critical" ? DT.Colors.ember : clue.importance == "supporting" ? DT.Colors.warmGlow : DT.Colors.smoke)
                                                .frame(width: 6, height: 6)
                                                .shadow(color: (clue.importance == "critical" ? DT.Colors.ember : DT.Colors.warmGlow).opacity(0.4), radius: 3)
                                                .padding(.top, 5)
                                            Text(clue.text)
                                                .font(DT.Typo.evidence)
                                                .foregroundStyle(DT.Colors.fog.opacity(0.8))
                                        }
                                    }
                                }
                            }
                        }

                        if !gameState.contradictions.isEmpty {
                            Text("\(gameState.contradictions.count) contradiction(s) caught")
                                .font(DT.Typo.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(DT.Colors.ember)
                        }
                    }
                    .evidenceCard(accent: DT.Colors.warmGlow)
                }

                // Suspect selection
                VStack(alignment: .leading, spacing: DT.Space.md) {
                    NoirSectionLabel(text: "SELECT THE GUILTY PARTY")

                    ForEach(gameState.suspectsAvailable) { suspect in
                        Button { withAnimation { selectedSuspect = suspect.id } } label: {
                            let isSelected = selectedSuspect == suspect.id
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? DT.Colors.ember : DT.Colors.smoke)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suspect.name)
                                        .font(DT.Typo.cardTitle)
                                        .foregroundStyle(DT.Colors.fog)
                                    Text(suspect.role)
                                        .font(DT.Typo.footnote)
                                        .foregroundStyle(DT.Colors.smoke)
                                }
                                Spacer()
                                if gameState.interviewedSuspects.contains(suspect.id) {
                                    Text("Interviewed")
                                        .font(DT.Typo.tagLabel)
                                        .foregroundStyle(DT.Colors.success)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DT.Colors.success.opacity(0.12), in: Capsule())
                                }
                            }
                            .suspectCard(status: isSelected ? DT.Colors.ember : DT.Colors.surface)
                            .overlay(
                                isSelected ?
                                RoundedRectangle(cornerRadius: DT.Radius.lg)
                                    .fill(
                                        RadialGradient(
                                            colors: [DT.Colors.ember.opacity(0.08), .clear],
                                            center: .center, startRadius: 10, endRadius: 100
                                        )
                                    )
                                : nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Motive
                VStack(alignment: .leading, spacing: DT.Space.sm) {
                    NoirSectionLabel(text: "WHAT WAS THE MOTIVE?")
                    Text("+50 bonus points for identifying the motive")
                        .font(DT.Typo.footnote)
                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.7))
                    TextField("Why did they do it?", text: $motiveText, axis: .vertical)
                        .lineLimit(2...4)
                        .font(DT.Typo.bodySerif)
                        .padding(DT.Space.md)
                        .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.md)
                                .stroke(DT.Colors.warmGlow.opacity(0.2), lineWidth: 0.5)
                        )
                        .tint(DT.Colors.warmGlow)
                }

                // Submit
                Button {
                    guard let selectedSuspect else { return }
                    gameState.submitAccusation(
                        suspectId: selectedSuspect,
                        motive: motiveText.isEmpty ? nil : motiveText
                    )
                } label: {
                    Text("Submit Accusation")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(selectedSuspect != nil ? DT.Colors.fog : DT.Colors.smoke)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DT.Space.lg)
                        .background(
                            DT.Grad.buttonGradient(selectedSuspect != nil ? DT.Colors.ember : DT.Colors.smoke.opacity(0.3)),
                            in: RoundedRectangle(cornerRadius: DT.Radius.md)
                        )
                }
                .disabled(selectedSuspect == nil)
                .breathingGlow(selectedSuspect != nil ? DT.Colors.ember : .clear)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .noirBackground(ambient: DT.Colors.ember)
    }
}
