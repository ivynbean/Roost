import Foundation

extension Bookmark {
    static let samples: [Bookmark] = [
        Bookmark(
            title: "developer.apple.com / swiftui",
            location: "https://developer.apple.com/documentation/swiftui",
            kind: .web,
            category: .code,
            summary: "SwiftUI reference"
        ),
        Bookmark(
            title: "Design inspiration board",
            location: "https://www.figma.com/community",
            kind: .web,
            category: .design,
            summary: "Saved from figma.com"
        ),
        Bookmark(
            title: "Article to read later",
            location: "https://example.com/long-read",
            kind: .web,
            category: .readLater,
            summary: "A placeholder read-later item"
        )
    ]
}
