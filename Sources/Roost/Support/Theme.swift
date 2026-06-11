import SwiftUI
import CoreText

enum Theme {
    static let pink = Color(red: 0.83, green: 0.44, blue: 0.31)
    static let rose = Color(red: 0.78, green: 0.38, blue: 0.23)
    static let blush = Color(red: 0.95, green: 0.87, blue: 0.82)
    static let lavender = Color(red: 0.29, green: 0.42, blue: 0.60)
    static let cream = Color(red: 0.95, green: 0.91, blue: 0.85)
    static let paper = Color(red: 0.99, green: 0.96, blue: 0.93)
    static let moss = Color(red: 0.35, green: 0.54, blue: 0.42)
    static let grass = Color(red: 0.42, green: 0.60, blue: 0.48)
    static let ink = Color(red: 0.11, green: 0.09, blue: 0.19)
    static let night = Color(red: 0.11, green: 0.09, blue: 0.19)
    static let gold = Color(red: 0.91, green: 0.75, blue: 0.41)
    static let wood = Color(red: 0.60, green: 0.48, blue: 0.38)
    static let sidebar = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let selected = Color(red: 0.93, green: 0.87, blue: 0.82)

    // Semantic tokens — prefer these over ad-hoc opacities so text keeps a
    // readable floor of contrast against the paper backgrounds.
    static let textPrimary = ink
    static let textSecondary = Color(red: 0.40, green: 0.31, blue: 0.25)
    static let textTertiary = Color(red: 0.60, green: 0.48, blue: 0.38)
    static let card = Color(red: 1.00, green: 0.98, blue: 0.96)
    static let cardStroke = Color(red: 0.55, green: 0.35, blue: 0.24).opacity(0.14)
    static let field = Color(red: 0.95, green: 0.91, blue: 0.85)
    static let divider = Color(red: 0.55, green: 0.35, blue: 0.24).opacity(0.14)
    static let sidebarAccent = Color(red: 0.93, green: 0.87, blue: 0.82)
    static let destructive = Color(red: 0.75, green: 0.22, blue: 0.17)

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
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
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
        Theme.paper
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
