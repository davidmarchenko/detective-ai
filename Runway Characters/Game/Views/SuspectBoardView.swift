import SwiftUI

struct SuspectBoardView: View {
    @Bindable var gameState: GameState
    @State private var showNotebook = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background — dark with cool undertone
            DT.Colors.void.ignoresSafeArea()
            RadialGradient(
                colors: [DT.Colors.warmGlow.opacity(0.04), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 20, endRadius: 500
            )
            .ignoresSafeArea()

            // Red string connections (decorative)
            GeometryReader { geo in
                Path { p in
                    let centerX = geo.size.width / 2
                    p.move(to: CGPoint(x: centerX, y: 80))
                    p.addLine(to: CGPoint(x: centerX - 60, y: 180))
                    p.move(to: CGPoint(x: centerX, y: 80))
                    p.addLine(to: CGPoint(x: centerX + 60, y: 180))
                    p.move(to: CGPoint(x: centerX - 60, y: 180))
                    p.addLine(to: CGPoint(x: centerX + 60, y: 180))
                }
                .stroke(DT.Colors.ember.opacity(0.08), lineWidth: 0.5)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: DT.Space.xl) {
                    // Top bar
                    HStack {
                        Button { showNotebook = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "book.closed.fill")
                                Text("Notebook")
                            }
                            .font(DT.Typo.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(DT.Colors.warmGlow)
                        }
                        Spacer()
                        if !gameState.discoveredClues.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10))
                                Text("\(gameState.discoveredClues.count)")
                                    .font(DT.Typo.data)
                            }
                            .foregroundStyle(DT.Colors.warmGlow)
                            .padding(.horizontal, DT.Space.md)
                            .padding(.vertical, DT.Space.xs)
                            .background(DT.Colors.warmGlow.opacity(0.08), in: Capsule())
                        }
                    }
                    .padding(.top, DT.Space.md)

                    // Header
                    VStack(spacing: DT.Space.sm) {
                        // Pin icon
                        Image(systemName: "pin.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DT.Colors.ember)
                            .rotationEffect(.degrees(-30))
                            .shadow(color: DT.Colors.ember.opacity(0.3), radius: 6)

                        Text("SUSPECT BOARD")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                            .tracking(4)
                        Text("Choose who to interrogate")
                            .font(DT.Typo.caption)
                            .foregroundStyle(DT.Colors.steel)
                    }

                    // Suspects
                    ForEach(Array(gameState.suspectsAvailable.enumerated()), id: \.element.id) { index, suspect in
                        suspectCard(suspect, index: index)
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : (index % 2 == 0 ? -20 : 20))
                    }

                    // Evidence review link
                    if !gameState.discoveredClues.isEmpty {
                        Button { gameState.phase = .evidence } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(DT.Colors.warmGlow)
                                Text("Review Evidence")
                                    .font(DT.Typo.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DT.Colors.warmGlow)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DT.Colors.smoke)
                            }
                            .padding(DT.Space.lg)
                            .background(DT.Colors.warmGlow.opacity(0.06), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DT.Radius.md)
                                    .stroke(DT.Colors.warmGlow.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }

                    // Accuse button
                    if !gameState.interviewedSuspects.isEmpty {
                        Button { gameState.goToAccusation() } label: {
                            HStack(spacing: DT.Space.sm) {
                                Image(systemName: "exclamationmark.shield.fill")
                                Text("Ready to Accuse")
                            }
                            .font(.system(size: 16, weight: .bold))
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
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNotebook) {
            CaseNotebookView(gameState: gameState)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Suspect Card

    private func suspectCard(_ suspect: SuspectDefinition, index: Int) -> some View {
        let interviewed = gameState.interviewedSuspects.contains(suspect.id)
        let clueCount = gameState.discoveredClues.filter { $0.suspectId == suspect.id }.count

        return Button { gameState.startInterrogation(suspectId: suspect.id) } label: {
            HStack(spacing: DT.Space.lg) {
                // Mugshot frame
                ZStack {
                    RoundedRectangle(cornerRadius: DT.Radius.sm)
                        .fill(DT.Colors.surfaceRaised)
                        .frame(width: 56, height: 68)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(interviewed ? DT.Colors.success.opacity(0.4) : DT.Colors.smoke)
                    // Status dot
                    Circle()
                        .fill(interviewed ? DT.Colors.success : DT.Colors.warmGlow)
                        .frame(width: 10, height: 10)
                        .shadow(color: (interviewed ? DT.Colors.success : DT.Colors.warmGlow).opacity(0.5), radius: 4)
                        .offset(x: 22, y: -28)
                }

                VStack(alignment: .leading, spacing: DT.Space.xs) {
                    Text(suspect.name)
                        .font(DT.Typo.cardTitle)
                        .foregroundStyle(DT.Colors.fog)
                    Text(suspect.role.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                        .tracking(1)
                    Text(suspect.briefDescription)
                        .font(DT.Typo.footnote)
                        .foregroundStyle(DT.Colors.smoke)
                        .lineLimit(2)

                    if clueCount > 0 {
                        Text("\(clueCount) clue\(clueCount == 1 ? "" : "s") found")
                            .font(DT.Typo.tagLabel)
                            .foregroundStyle(DT.Colors.warmGlow)
                    }
                }

                Spacer()

                // Action indicator
                VStack(spacing: DT.Space.xs) {
                    if interviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DT.Colors.success)
                    } else {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DT.Colors.warmGlow)
                            .symbolEffect(.pulse)
                    }
                    Text(interviewed ? "Done" : "Call")
                        .font(DT.Typo.tagLabel)
                        .foregroundStyle(interviewed ? DT.Colors.success : DT.Colors.warmGlow)
                }
            }
            .padding(DT.Space.lg)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DT.Radius.lg)
                        .fill(DT.Colors.surface)
                    DT.Grad.cardSheen
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.lg))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.lg)
                    .stroke(
                        interviewed ? DT.Colors.success.opacity(0.15) : DT.Colors.warmGlow.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}
