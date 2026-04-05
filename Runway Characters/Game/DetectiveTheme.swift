import SwiftUI

// MARK: - Detective Noir Theme

enum DT {

    // MARK: - Colors

    enum Colors {
        // Backgrounds — deeper, richer darks
        static let void           = Color(red: 0.03, green: 0.02, blue: 0.05)
        static let surface        = Color(red: 0.07, green: 0.06, blue: 0.09)
        static let surfaceRaised  = Color(red: 0.11, green: 0.09, blue: 0.13)

        // Text hierarchy — warm-toned, high contrast
        static let fog            = Color(red: 0.92, green: 0.91, blue: 0.90)
        static let steel          = Color(red: 0.52, green: 0.54, blue: 0.60)
        static let smoke          = Color(red: 0.32, green: 0.34, blue: 0.38)

        // Semantic accents — punchy, vivid
        static let warmGlow       = Color(red: 1.0, green: 0.68, blue: 0.20)   // amber lamplight
        static let ember          = Color(red: 0.85, green: 0.25, blue: 0.25)   // danger/accusation
        static let instinct       = Color(red: 0.55, green: 0.35, blue: 0.75)   // detective intuition
        static let suggestion     = Color(red: 0.35, green: 0.55, blue: 0.80)   // guidance
        static let success        = Color(red: 0.30, green: 0.70, blue: 0.45)   // correct/interviewed
        static let suspicion      = Color(red: 0.90, green: 0.75, blue: 0.20)   // gold tension
    }

    // MARK: - Typography

    enum Typo {
        static let displayTitle   = Font.system(size: 32, weight: .bold, design: .serif)
        static let screenTitle    = Font.system(size: 24, weight: .semibold, design: .serif)
        static let cardTitle      = Font.system(size: 18, weight: .semibold, design: .serif)
        static let sectionLabel   = Font.system(size: 11, weight: .bold, design: .monospaced)
        static let tagLabel       = Font.system(size: 10, weight: .bold, design: .monospaced)
        static let body           = Font.system(size: 15)
        static let bodySerif      = Font.system(size: 15, design: .serif)
        static let caption        = Font.system(size: 13)
        static let footnote       = Font.system(size: 11)
        static let evidence       = Font.system(size: 14, design: .serif).italic()
        static let data           = Font.system(size: 14, weight: .bold).monospacedDigit()
    }

    // MARK: - Spacing

    enum Space {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm:   CGFloat = 6
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let pill: CGFloat = 100
    }

    // MARK: - Gradients

    enum Grad {
        static let screen = LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.04, blue: 0.09),
                Color(red: 0.05, green: 0.04, blue: 0.07),
                Color(red: 0.04, green: 0.03, blue: 0.05)
            ],
            startPoint: .top, endPoint: .bottom
        )

        static let vignette = RadialGradient(
            colors: [.clear, Color.black.opacity(0.5)],
            center: .center, startRadius: 200, endRadius: 500
        )

        static let cardSheen = LinearGradient(
            colors: [Color.white.opacity(0.03), .clear],
            startPoint: .top, endPoint: .center
        )

        static let bottomFade = LinearGradient(
            colors: [.clear, Colors.void.opacity(0.9)],
            startPoint: .top, endPoint: .bottom
        )

        static func ambientGlow(_ color: Color) -> RadialGradient {
            RadialGradient(
                colors: [color.opacity(0.12), .clear],
                center: .top, startRadius: 20, endRadius: 400
            )
        }

        static func buttonGradient(_ color: Color) -> LinearGradient {
            LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

// MARK: - Noir Background Modifier

struct NoirBackground: ViewModifier {
    var ambient: Color = .clear

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    DT.Grad.screen.ignoresSafeArea()

                    // Film grain — visible texture
                    Canvas { context, size in
                        for i in 0..<800 {
                            let x = CGFloat((i * 7919 + 104729) % Int(size.width))
                            let y = CGFloat((i * 6271 + 73856) % Int(size.height))
                            let s = CGFloat((i * 3571) % 3 + 1)
                            let opacity = Double((i * 2377) % 40 + 15) / 1000.0 // 0.015–0.055
                            let rect = CGRect(x: x, y: y, width: s, height: s)
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                        }
                    }
                    .ignoresSafeArea()
                    .blendMode(.screen)

                    // Ambient glow
                    if ambient != .clear {
                        DT.Grad.ambientGlow(ambient).ignoresSafeArea()
                    }

                    // Vignette
                    DT.Grad.vignette.ignoresSafeArea()
                }
            }
            .preferredColorScheme(.dark)
    }
}

extension View {
    func noirBackground(ambient: Color = .clear) -> some View {
        modifier(NoirBackground(ambient: ambient))
    }
}

// MARK: - Evidence Card Style

struct EvidenceCardStyle: ViewModifier {
    var accentColor: Color = DT.Colors.warmGlow

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .shadow(color: accentColor.opacity(0.4), radius: 4)
                .padding(.vertical, 4)

            content
                .padding(.leading, DT.Space.md)
        }
        .padding(DT.Space.md)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .fill(DT.Colors.surface)
                // Ruled line texture
                VStack(spacing: 18) {
                    ForEach(0..<6, id: \.self) { _ in
                        Rectangle().fill(Color.white.opacity(0.012)).frame(height: 0.5)
                    }
                }
                .padding(.vertical, DT.Space.sm)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.md))
                // Top light sheen
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .fill(DT.Grad.cardSheen)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

extension View {
    func evidenceCard(accent: Color = DT.Colors.warmGlow) -> some View {
        modifier(EvidenceCardStyle(accentColor: accent))
    }
}

// MARK: - Suspect Card Style

struct SuspectCardStyle: ViewModifier {
    var statusColor: Color = DT.Colors.warmGlow

    func body(content: Content) -> some View {
        content
            .padding(DT.Space.lg)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DT.Radius.lg)
                        .fill(
                            LinearGradient(
                                colors: [DT.Colors.surfaceRaised, DT.Colors.surface],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    // Top highlight edge
                    VStack {
                        RoundedRectangle(cornerRadius: DT.Radius.lg)
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.lg))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.lg)
                    .stroke(statusColor.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 14, y: 8)
    }
}

extension View {
    func suspectCard(status: Color = DT.Colors.warmGlow) -> some View {
        modifier(SuspectCardStyle(statusColor: status))
    }
}

// MARK: - Breathing Glow

struct BreathingGlow: ViewModifier {
    let color: Color
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(glowing ? 0.4 : 0.15), radius: glowing ? 16 : 8)
            .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { glowing = true } }
    }
}

extension View {
    func breathingGlow(_ color: Color) -> some View {
        modifier(BreathingGlow(color: color))
    }
}

// MARK: - Section Label

struct NoirSectionLabel: View {
    let text: String
    var color: Color = DT.Colors.warmGlow

    var body: some View {
        Text(text)
            .font(DT.Typo.sectionLabel)
            .foregroundStyle(color)
            .tracking(2)
    }
}
