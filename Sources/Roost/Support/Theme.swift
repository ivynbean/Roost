import SwiftUI
import CoreText

enum Theme {
    static let pink = Color(red: 0.80, green: 0.16, blue: 0.30)
    static let rose = Color(red: 0.92, green: 0.38, blue: 0.48)
    static let blush = Color(red: 0.99, green: 0.79, blue: 0.78)
    static let lavender = Color(red: 0.52, green: 0.45, blue: 0.78)
    static let cream = Color(red: 0.98, green: 0.94, blue: 0.86)
    static let paper = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let moss = Color(red: 0.33, green: 0.48, blue: 0.26)
    static let grass = Color(red: 0.68, green: 0.76, blue: 0.54)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let night = Color(red: 0.08, green: 0.14, blue: 0.28)
    static let gold = Color(red: 0.85, green: 0.62, blue: 0.10)
    static let wood = Color(red: 0.50, green: 0.34, blue: 0.23)
    static let sidebar = Color(red: 0.93, green: 0.89, blue: 0.81)
    static let selected = Color(red: 0.23, green: 0.25, blue: 0.24)

    // Semantic tokens — prefer these over ad-hoc opacities so text keeps a
    // readable floor of contrast against the paper backgrounds.
    static let textPrimary = ink
    static let textSecondary = ink.opacity(0.78)
    static let textTertiary = ink.opacity(0.60)
    static let card = Color.white
    static let cardStroke = wood.opacity(0.22)

    static func logoFont(size: CGFloat) -> Font {
        .custom("Sophiecomic Regular", size: size)
    }

    private static let projectPalette: [Color] = [pink, moss, lavender, gold, wood, rose]

    static func projectColor(_ index: Int) -> Color {
        projectPalette[((index % projectPalette.count) + projectPalette.count) % projectPalette.count]
    }
}

enum RoostFontRegistrar {
    static func registerFonts() {
        guard let url = Bundle.module.url(forResource: "Sophiecomic-Regular", withExtension: "ttf") else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

struct PaperPanel: ViewModifier {
    var cornerRadius: CGFloat = 10
    var tint: Color = Theme.rose
    var fillOpacity: Double = 0.94

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card.opacity(fillOpacity))
                    .shadow(color: Theme.ink.opacity(0.10), radius: 10, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.55), lineWidth: 1)
            }
    }
}

extension View {
    func paperPanel(cornerRadius: CGFloat = 10, tint: Color = Theme.rose, fillOpacity: Double = 0.82) -> some View {
        modifier(PaperPanel(cornerRadius: cornerRadius, tint: tint, fillOpacity: fillOpacity))
    }
}

struct PaintedBackdrop: View {
    var body: some View {
        ZStack {
            Theme.paper
            LinearGradient(
                colors: [
                    Theme.paper,
                    Theme.blush.opacity(0.18),
                    Theme.grass.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            StarScatter()
                .opacity(0.36)
        }
        .ignoresSafeArea()
    }
}

enum RoostImage {
    /// Status-bar sized copy of the app icon for the MenuBarExtra.
    static func menuBarNSImage() -> NSImage? {
        guard let source = nsImage() else { return nil }
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
        return icon
    }

    static func nsImage() -> NSImage? {
        if let url = Bundle.module.url(forResource: "roost-chick-icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.module.url(forResource: "roost-illustration", withExtension: "jpg"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.module.url(forResource: "roost-birkin", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.module.url(forResource: "roost-logo", withExtension: "jpg"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.module.url(forResource: "roost-logo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        return NSImage(named: "roost-logo")
    }
}

struct StarScatter: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                Image(systemName: "sparkle")
                    .font(.system(size: star.size, weight: .semibold))
                    .foregroundStyle(Theme.gold.opacity(star.opacity))
                    .rotationEffect(.degrees(star.rotation))
                    .position(
                        x: proxy.size.width * star.x,
                        y: proxy.size.height * star.y
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private let stars: [PaintedStar] = [
        .init(x: 0.76, y: 0.12, size: 16, rotation: 9, opacity: 0.62),
        .init(x: 0.88, y: 0.22, size: 11, rotation: -14, opacity: 0.48),
        .init(x: 0.67, y: 0.34, size: 13, rotation: 20, opacity: 0.42),
        .init(x: 0.18, y: 0.83, size: 10, rotation: -8, opacity: 0.38),
        .init(x: 0.54, y: 0.88, size: 12, rotation: 16, opacity: 0.32)
    ]
}

private struct PaintedStar {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let rotation: Double
    let opacity: Double
}
