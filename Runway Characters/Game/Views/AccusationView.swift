import SwiftUI

struct AccusationView: View {
    @Bindable var gameState: GameState
    @State private var selectedSuspect: String?
    @State private var motiveText: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Back to evidence
                    HStack {
                        Button {
                            gameState.returnToEvidence()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Review Evidence")
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)
                        Text("MAKE YOUR ACCUSATION")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                            .tracking(3)
                        Text("Who killed \(gameState.mystery?.victimName ?? "the victim")?")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                    }

                    // Evidence summary — grouped by suspect
                    if !gameState.discoveredClues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EVIDENCE BY SUSPECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .tracking(2)

                            let grouped = Dictionary(grouping: gameState.discoveredClues) { $0.suspectId }
                            ForEach(gameState.suspectsAvailable) { suspect in
                                if let clues = grouped[suspect.id], !clues.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(suspect.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.6))
                                        ForEach(clues) { clue in
                                            HStack(alignment: .top, spacing: 6) {
                                                Circle()
                                                    .fill(clue.importance == "critical" ? .red : clue.importance == "supporting" ? .orange : .gray)
                                                    .frame(width: 6, height: 6)
                                                    .padding(.top, 5)
                                                Text(clue.text)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                }
                            }

                            if !gameState.contradictions.isEmpty {
                                Text("\(gameState.contradictions.count) contradiction(s) caught")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Suspect selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELECT THE GUILTY PARTY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .tracking(2)

                        ForEach(gameState.suspectsAvailable) { suspect in
                            Button {
                                withAnimation { selectedSuspect = suspect.id }
                            } label: {
                                HStack {
                                    Image(systemName: selectedSuspect == suspect.id
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedSuspect == suspect.id ? .red : .white.opacity(0.4))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suspect.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(suspect.role)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    if gameState.interviewedSuspects.contains(suspect.id) {
                                        Text("Interviewed")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.green.opacity(0.15), in: Capsule())
                                    }
                                }
                                .padding(14)
                                .background(
                                    selectedSuspect == suspect.id
                                        ? Color.red.opacity(0.15)
                                        : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            selectedSuspect == suspect.id ? .red : .clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Motive
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHAT WAS THE MOTIVE?")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .tracking(2)
                        Text("+50 bonus points for identifying the motive")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange.opacity(0.7))
                        TextField("Why did they do it?", text: $motiveText, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .tint(.orange)
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
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedSuspect != nil ? Color.red : Color.gray,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                    .disabled(selectedSuspect == nil)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}
