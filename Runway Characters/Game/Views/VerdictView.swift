import SwiftUI

struct VerdictView: View {
    @Bindable var gameState: GameState
    @State private var revealPhase = 0
    @State private var showExplanation = false
    @State private var scanLineOffset: CGFloat = -30
    @State private var typewriterText = ""
    @State private var scoreValues: [Int] = [0, 0, 0, 0, 0]
    @State private var sealScale: CGFloat = 0.3
    @State private var sealOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0

    private var isCorrect: Bool { gameState.score?.correctAccusation ?? false }
    private var resultColor: Color { isCorrect ? DT.Colors.success : DT.Colors.ember }

    var body: some View {
        ZStack {
            // Background
            DT.Colors.void.ignoresSafeArea()

            // Phase-dependent ambient
            if revealPhase >= 2 {
                RadialGradient(
                    colors: [resultColor.opacity(0.1), .clear],
                    center: .center, startRadius: 30, endRadius: 400
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: DT.Space.xxl) {
                    Spacer().frame(height: 50)

                    // Phase 0: Analyzing
                    if revealPhase == 0 {
                        VStack(spacing: DT.Space.xl) {
                            // Scanning line
                            ZStack {
                                Rectangle()
                                    .fill(DT.Colors.warmGlow.opacity(0.5))
                                    .frame(width: 180, height: 1.5)
                                    .blur(radius: 1)
                                    .shadow(color: DT.Colors.warmGlow.opacity(0.6), radius: 8)
                                    .offset(y: scanLineOffset)
                            }
                            .frame(height: 60)
                            .clipped()

                            Text("ANALYZING EVIDENCE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                .tracking(4)

                            // Dot animation
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(DT.Colors.warmGlow.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                        .scaleEffect(1.0)
                                        .animation(
                                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.2),
                                            value: revealPhase
                                        )
                                }
                            }
                        }
                    }

                    // Phase 1: Typewriter
                    if revealPhase >= 1 && revealPhase < 2 {
                        Text(typewriterText)
                            .font(.system(size: 18, design: .serif))
                            .foregroundStyle(DT.Colors.steel)
                            .frame(height: 30)
                    }

                    // Phase 2: Name + Seal
                    if revealPhase >= 2, let mystery = gameState.mystery {
                        let guilty = mystery.suspects.first { $0.id == mystery.solution.guiltySubjectId }

                        VStack(spacing: DT.Space.xl) {
                            // Name
                            Text(guilty?.name ?? "Unknown")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundStyle(DT.Colors.fog)
                                .shadow(color: resultColor.opacity(0.4), radius: 20)

                            // Seal with glow burst
                            ZStack {
                                // Glow burst behind seal
                                Circle()
                                    .fill(resultColor.opacity(0.15))
                                    .frame(width: glowRadius * 2, height: glowRadius * 2)
                                    .blur(radius: 20)

                                Image(systemName: isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(resultColor)
                                    .shadow(color: resultColor.opacity(0.5), radius: 12)
                                    .scaleEffect(sealScale)
                                    .opacity(sealOpacity)
                            }

                            // Result label
                            VStack(spacing: DT.Space.sm) {
                                Text(isCorrect ? "CASE CLOSED" : "WRONG SUSPECT")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(resultColor)
                                    .tracking(4)

                                if let score = gameState.score {
                                    Text(score.rating)
                                        .font(DT.Typo.screenTitle)
                                        .foregroundStyle(DT.Colors.fog)
                                }
                            }
                        }
                    }

                    // Phase 3: Score
                    if revealPhase >= 3, let score = gameState.score {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("SCORE BREAKDOWN")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                    .tracking(3)
                                Spacer()
                            }
                            .padding(.horizontal, DT.Space.lg)
                            .padding(.vertical, DT.Space.sm)
                            .background(DT.Colors.surfaceRaised)

                            VStack(spacing: DT.Space.md) {
                                scoreRow("Clues Found", value: "\(score.cluesFound)/\(score.totalClues)", pts: scoreValues[0])
                                scoreRow("Contradictions", value: "\(score.contradictionsCaught)", pts: scoreValues[1])
                                scoreRow("Correct Suspect", value: score.correctAccusation ? "Yes" : "No", pts: scoreValues[2])
                                scoreRow("Correct Motive", value: score.correctMotive ? "Yes" : "No", pts: scoreValues[3])

                                Rectangle().fill(DT.Colors.warmGlow.opacity(0.15)).frame(height: 0.5)

                                HStack {
                                    Text("TOTAL")
                                        .font(DT.Typo.sectionLabel)
                                        .foregroundStyle(DT.Colors.warmGlow)
                                    Spacer()
                                    (Text("\(scoreValues[4])")
                                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                                        .foregroundColor(DT.Colors.warmGlow)
                                    + Text(" pts")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(DT.Colors.warmGlow.opacity(0.6)))
                                    .shadow(color: DT.Colors.warmGlow.opacity(0.3), radius: 8)
                                }
                            }
                            .padding(DT.Space.lg)
                            .background(DT.Colors.surface)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.md)
                                .stroke(DT.Colors.warmGlow.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Phase 4: The truth
                    if revealPhase >= 4, let mystery = gameState.mystery {
                        VStack(alignment: .leading, spacing: DT.Space.md) {
                            Button { withAnimation { showExplanation.toggle() } } label: {
                                HStack {
                                    Text("THE FULL STORY")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                        .tracking(3)
                                    Spacer()
                                    Image(systemName: showExplanation ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                                }
                            }

                            if showExplanation {
                                VStack(alignment: .leading, spacing: DT.Space.lg) {
                                    VStack(alignment: .leading, spacing: DT.Space.sm) {
                                        Text("MOTIVE")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(DT.Colors.warmGlow.opacity(0.4))
                                            .tracking(2)
                                        Text(mystery.solution.motive)
                                            .font(DT.Typo.bodySerif)
                                            .foregroundStyle(DT.Colors.fog.opacity(0.85))
                                            .lineSpacing(3)
                                    }

                                    VStack(alignment: .leading, spacing: DT.Space.sm) {
                                        Text("WHAT HAPPENED")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(DT.Colors.warmGlow.opacity(0.4))
                                            .tracking(2)
                                        Text(mystery.solution.explanation)
                                            .font(DT.Typo.bodySerif)
                                            .foregroundStyle(DT.Colors.fog.opacity(0.85))
                                            .lineSpacing(3)
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(DT.Space.lg)
                        .background(DT.Colors.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.md)
                                .stroke(DT.Colors.steel.opacity(0.1), lineWidth: 0.5)
                                .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        .transition(.opacity)

                        // Actions
                        VStack(spacing: DT.Space.md) {
                            Button { gameState.replayCurrentCase() } label: {
                                HStack(spacing: DT.Space.sm) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Play Again")
                                }
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(DT.Colors.void)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DT.Grad.buttonGradient(DT.Colors.warmGlow), in: RoundedRectangle(cornerRadius: DT.Radius.md))
                            }

                            Button { gameState.resetToLobby() } label: {
                                Text("Return to Cases")
                                    .font(DT.Typo.caption)
                                    .foregroundStyle(DT.Colors.steel)
                            }
                        }
                        .padding(.top, DT.Space.sm)
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.6), value: revealPhase)
        .task { await runRevealSequence() }
    }

    // MARK: - Reveal Sequence

    private func runRevealSequence() async {
        // Scanning line
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            scanLineOffset = 30
        }

        // Phase 1: typewriter
        try? await Task.sleep(for: .seconds(2.0))
        revealPhase = 1

        let fullText = "The killer was..."
        for (i, _) in fullText.enumerated() {
            try? await Task.sleep(for: .seconds(0.07))
            typewriterText = String(fullText.prefix(i + 1))
        }

        // Phase 2: name + seal
        try? await Task.sleep(for: .seconds(1.0))
        revealPhase = 2
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            sealScale = 1.0
            sealOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8)) { glowRadius = 80 }
        withAnimation(.easeOut(duration: 1.5).delay(0.5)) { glowRadius = 40 }

        // Phase 3: score
        try? await Task.sleep(for: .seconds(1.5))
        revealPhase = 3
        await animateScores()

        // Phase 4: truth
        try? await Task.sleep(for: .seconds(0.5))
        revealPhase = 4
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation { showExplanation = true }
    }

    private func animateScores() async {
        guard let score = gameState.score else { return }
        let targets = [
            score.cluesFound * 10,
            score.contradictionsCaught * 25,
            score.correctAccusation ? 100 : 0,
            score.correctMotive ? 50 : 0,
            score.totalPoints
        ]
        for (index, target) in targets.enumerated() {
            let steps = 15
            for step in 0...steps {
                scoreValues[index] = Int(Double(target) * Double(step) / Double(steps))
                try? await Task.sleep(for: .seconds(0.025))
            }
            try? await Task.sleep(for: .seconds(0.08))
        }
    }

    // MARK: - Score Row

    private func scoreRow(_ label: String, value: String, pts: Int) -> some View {
        HStack {
            Text(label)
                .font(DT.Typo.caption)
                .foregroundStyle(DT.Colors.steel)
            Spacer()
            Text(value)
                .font(DT.Typo.caption)
                .fontWeight(.medium)
                .foregroundStyle(DT.Colors.fog)
            Text("+\(pts)")
                .font(DT.Typo.data)
                .foregroundStyle(DT.Colors.warmGlow)
                .frame(width: 55, alignment: .trailing)
        }
    }
}
