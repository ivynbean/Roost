import SwiftUI
import CoreText

enum Theme {
    static let pink = Color(red: 0.86, green: 0.24, blue: 0.36)
    static let rose = Color(red: 0.96, green: 0.45, blue: 0.55)
    static let blush = Color(red: 0.99, green: 0.79, blue: 0.78)
    static let lavender = Color(red: 0.73, green: 0.68, blue: 0.91)
    static let cream = Color(red: 0.98, green: 0.94, blue: 0.86)
    static let paper = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let moss = Color(red: 0.46, green: 0.61, blue: 0.39)
    static let grass = Color(red: 0.68, green: 0.76, blue: 0.54)
    static let ink = Color(red: 0.15, green: 0.19, blue: 0.25)
    static let night = Color(red: 0.08, green: 0.14, blue: 0.28)
    static let gold = Color(red: 0.97, green: 0.78, blue: 0.25)
    static let wood = Color(red: 0.50, green: 0.34, blue: 0.23)
    static let sidebar = Color(red: 0.94, green: 0.91, blue: 0.84)
    static let selected = Color(red: 0.23, green: 0.25, blue: 0.24)

    static func logoFont(size: CGFloat) -> Font {
        .custom("Sophiecomic Regular", size: size)
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
    var fillOpacity: Double = 0.82

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.paper.opacity(fillOpacity))
                    .shadow(color: tint.opacity(0.12), radius: 12, y: 5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
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
