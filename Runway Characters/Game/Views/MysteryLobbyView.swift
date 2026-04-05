import SwiftUI

struct MysteryLobbyView: View {
    @Bindable var gameState: GameState
    @State private var scenarios: [MysteryScenario] = []
    @State private var selectedMode: GameMode = .quickPlay
    @State private var appeared = false
    @State private var flickerOpacity: Double = 0.7

    var body: some View {
        ZStack {
            // Layered background
            DT.Colors.void.ignoresSafeArea()

            // Desk texture — overlapping angled rectangles
            GeometryReader { geo in
                // Wood grain lines
                ForEach(0..<20, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.008))
                        .frame(height: 1)
                        .offset(y: CGFloat(i) * (geo.size.height / 20))
                }

                // Warm desk lamp spotlight from top-left
                RadialGradient(
                    colors: [DT.Colors.warmGlow.opacity(0.08), .clear],
                    center: UnitPoint(x: 0.2, y: 0.05),
                    startRadius: 20,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Badge / logo area
                    VStack(spacing: DT.Space.lg) {
                        // Detective badge
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(DT.Colors.warmGlow.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 80, height: 80)
                            // Inner ring
                            Circle()
                                .stroke(DT.Colors.warmGlow.opacity(0.15), lineWidth: 1)
                                .frame(width: 60, height: 60)
                            // Star
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 28))
                                .foregroundStyle(DT.Colors.warmGlow)
                                .shadow(color: DT.Colors.warmGlow.opacity(flickerOpacity), radius: 12)
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                                flickerOpacity = 0.3
                            }
                        }

                        Text("DETECTIVE\nBUREAU")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(DT.Colors.warmGlow.opacity(0.6))
                            .tracking(6)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("Murder Mystery")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(DT.Colors.fog)
                            .shadow(color: DT.Colors.warmGlow.opacity(0.2), radius: 20)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 15)

                        // Divider line with diamond
                        HStack(spacing: DT.Space.sm) {
                            Rectangle().fill(DT.Colors.warmGlow.opacity(0.2)).frame(height: 0.5)
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(DT.Colors.warmGlow.opacity(0.4))
                            Rectangle().fill(DT.Colors.warmGlow.opacity(0.2)).frame(height: 0.5)
                        }
                        .padding(.horizontal, 60)
                    }

                    Spacer().frame(height: 40)

                    // Mode selector — styled as case stamps
                    HStack(spacing: DT.Space.md) {
                        modeStamp("QUICK\nBRIEF", time: "5 MIN", mode: .quickPlay)
                        modeStamp("FULL\nCASE", time: "30 MIN", mode: .standardPlay)
                    }
                    .padding(.horizontal, DT.Space.xl)

                    Spacer().frame(height: DT.Space.xxl)

                    // Case files
                    VStack(spacing: DT.Space.lg) {
                        ForEach(scenarios) { scenario in
                            caseFileCard(scenario)
                        }

                        if scenarios.isEmpty {
                            VStack(spacing: DT.Space.md) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(DT.Colors.smoke)
                                Text("No active cases")
                                    .font(DT.Typo.caption)
                                    .foregroundStyle(DT.Colors.smoke)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, DT.Space.xl)

                    Spacer().frame(height: 60)
                }
            }
        }
        .onAppear {
            scenarios = MysteryLoader.loadAll()
            if scenarios.isEmpty, let s = MysteryLoader.load(named: "mystery_villa_morada") {
                scenarios = [s]
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { appeared = true }
        }
    }

    // MARK: - Mode Stamp

    private func modeStamp(_ label: String, time: String, mode: GameMode) -> some View {
        let isSelected = selectedMode == mode
        return Button { withAnimation(.spring(duration: 0.3)) { selectedMode = mode } } label: {
            VStack(spacing: DT.Space.sm) {
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(time)
                    .font(.system(size: 18, weight: .bold, design: .serif))
            }
            .foregroundStyle(isSelected ? DT.Colors.warmGlow : DT.Colors.smoke)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DT.Space.lg)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DT.Radius.md)
                        .fill(isSelected ? DT.Colors.warmGlow.opacity(0.08) : DT.Colors.surface)
                    // Stamp border — double line
                    RoundedRectangle(cornerRadius: DT.Radius.md)
                        .stroke(isSelected ? DT.Colors.warmGlow.opacity(0.4) : DT.Colors.smoke.opacity(0.15), lineWidth: 1.5)
                    RoundedRectangle(cornerRadius: DT.Radius.md - 3)
                        .stroke(isSelected ? DT.Colors.warmGlow.opacity(0.15) : .clear, lineWidth: 0.5)
                        .padding(3)
                }
            }
            .shadow(color: isSelected ? DT.Colors.warmGlow.opacity(0.15) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Case File Card

    private func caseFileCard(_ scenario: MysteryScenario) -> some View {
        Button { gameState.startGame(mystery: scenario, mode: selectedMode) } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Manila tab at top
                HStack {
                    Text("CASE #\(scenario.id.prefix(6).uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DT.Colors.void)
                        .padding(.horizontal, DT.Space.md)
                        .padding(.vertical, DT.Space.xs)
                        .background(DT.Colors.warmGlow.opacity(0.7), in: UnevenRoundedRectangle(topLeadingRadius: DT.Radius.sm, topTrailingRadius: DT.Radius.sm))
                    Spacer()
                    // Classification stamp
                    Text(selectedMode == .quickPlay ? "URGENT" : "CLASSIFIED")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(DT.Colors.ember.opacity(0.6))
                        .padding(.horizontal, DT.Space.sm)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(DT.Colors.ember.opacity(0.4), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(-3))
                        .padding(.trailing, DT.Space.lg)
                }

                // Card body
                VStack(alignment: .leading, spacing: DT.Space.md) {
                    Text(scenario.title)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(DT.Colors.fog)
                        .padding(.top, DT.Space.sm)

                    // Details in typewriter style
                    VStack(alignment: .leading, spacing: DT.Space.xs) {
                        caseDetail("VICTIM", scenario.victimName)
                        caseDetail("LOCATION", scenario.setting)
                        caseDetail("SUSPECTS", "\(scenario.suspects.count) persons of interest")
                    }

                    // Bottom row
                    HStack {
                        HStack(spacing: DT.Space.xs) {
                            ForEach(0..<scenario.suspects.count, id: \.self) { _ in
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DT.Colors.steel)
                            }
                        }
                        Spacer()
                        Text("OPEN CASE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(DT.Colors.warmGlow)
                            .tracking(2)
                    }
                }
                .padding(DT.Space.lg)
                .background(DT.Colors.surface)
                .overlay(
                    // Paper texture lines
                    VStack(spacing: 20) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle().fill(Color.white.opacity(0.015)).frame(height: 0.5)
                        }
                    }
                    .padding(.vertical, DT.Space.lg)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .stroke(DT.Colors.warmGlow.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func caseDetail(_ label: String, _ value: String) -> some View {
        HStack(spacing: DT.Space.sm) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DT.Colors.warmGlow.opacity(0.5))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(DT.Typo.footnote)
                .foregroundStyle(DT.Colors.steel)
        }
    }
}
