import Foundation

struct BookmarkSorter {
    private let rules: [(BookmarkCategory, [String])] = [
        (.important, ["urgent", "important", "must", "deadline", "invoice due", "renewal", "appointment", "reservation", "boarding pass", "ticket"]),
        (.work, ["slack", "linear", "jira", "asana", "trello", "notion.so", "confluence", "meeting", "project", "roadmap", "workspace", "drive.google.com"]),
        (.code, ["github", "gitlab", "bitbucket", "stackoverflow", "developer.apple", "api.", "docs.", "swift", "javascript", "typescript", "python", "rust", "package", "sdk", "terminal", "pull request"]),
        (.design, ["figma", "dribbble", "behance", "palette", "typography", "font", "design", "mockup", "wireframe", "brand", "logo"]),
        (.money, ["bank", "stripe", "paypal", "wise", "invoice", "receipt", "tax", "irs", "salary", "budget", "billing", "subscription", "credit card"]),
        (.travel, ["airbnb", "booking.com", "maps.google", "flight", "hotel", "train", "uber", "lyft", "travel", "visa", "itinerary"]),
        (.shopping, ["amazon", "etsy", "shop", "cart", "product", "price", "deal", "order", "wishlist", "store"]),
        (.media, ["youtube", "vimeo", "spotify", "netflix", "podcast", "movie", "music", "video", "watch"]),
        (.people, ["linkedin", "twitter", "x.com", "instagram", "profile", "contact", "people", "person", "resume", "portfolio"]),
        (.docs, ["pdf", "manual", "reference", "guide", "paper", "whitepaper", "spec", "document", ".docx", ".pptx", ".xlsx"]),
        (.readLater, ["article", "blog", "newsletter", "essay", "read", "medium.com", "substack", "news", "magazine"]),
        (.tools, ["app", "tool", "utility", "download", "installer", "extension", "plugin", "shortcut", "automation"])
    ]

    func bookmark(from rawValue: String) -> Bookmark {
        if let url = URL(string: rawValue), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
            return Bookmark(
                title: title(for: url),
                location: url.absoluteString,
                kind: .web,
                category: category(for: url.absoluteString),
                summary: summary(for: url)
            )
        }

        if rawValue.hasPrefix("/") || rawValue.hasPrefix("file://") {
            let url = rawValue.hasPrefix("file://") ? URL(string: rawValue) : URL(fileURLWithPath: rawValue)
            if let url {
                return Bookmark(
                    title: url.deletingPathExtension().lastPathComponent,
                    location: url.path,
                    kind: .file,
                    category: .docs,
                    summary: url.path
                )
            }
        }

        return Bookmark(
            title: rawValue.firstLine(maxLength: 48),
            location: rawValue,
            kind: .text,
            category: category(for: rawValue),
            summary: rawValue
        )
    }

    func category(for bookmark: Bookmark) -> BookmarkCategory {
        category(for: "\(bookmark.title) \(bookmark.location) \(bookmark.summary)")
    }

    func category(for text: String) -> BookmarkCategory {
        let lowercased = text.lowercased()
        let scores = rules.map { category, needles in
            let score = needles.reduce(0) { partial, needle in
                partial + (lowercased.contains(needle) ? weight(for: needle, in: lowercased) : 0)
            }
            return (category: category, score: score)
        }

        return scores.max { $0.score < $1.score }.flatMap { $0.score > 0 ? $0.category : nil } ?? .inbox
    }

    private func weight(for needle: String, in text: String) -> Int {
        if text.contains("://\(needle)") || text.contains(".\(needle)") {
            return 4
        }

        if needle.contains(".") || needle.contains(" ") {
            return 3
        }

        return 1
    }

    private func title(for url: URL) -> String {
        if let host = url.host(percentEncoded: false), !url.lastPathComponent.isEmpty {
            return "\(host) / \(url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent)"
        }

        return url.host(percentEncoded: false) ?? url.absoluteString
    }

    private func summary(for url: URL) -> String {
        guard let host = url.host(percentEncoded: false) else { return url.absoluteString }
        return "Saved from \(host)"
    }
}
