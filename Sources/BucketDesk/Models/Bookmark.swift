import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var location: String
    var kind: BookmarkKind
    var category: BookmarkCategory
    var summary: String
    var createdAt: Date
    var lastOpenedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        kind: BookmarkKind,
        category: BookmarkCategory = .inbox,
        summary: String = "",
        createdAt: Date = Date(),
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.kind = kind
        self.category = category
        self.summary = summary
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }
}

enum BookmarkKind: String, Codable, CaseIterable {
    case web
    case file
    case text

    var label: String {
        switch self {
        case .web: "Web"
        case .file: "File"
        case .text: "Text"
        }
    }
}

enum BookmarkCategory: String, Codable, CaseIterable, Identifiable {
    case inbox = "Catch All"
    case important = "Important"
    case work = "Work"
    case readLater = "Read Later"
    case docs = "Docs"
    case code = "Code"
    case design = "Design"
    case money = "Money"
    case travel = "Travel"
    case shopping = "Shopping"
    case media = "Media"
    case people = "People"
    case tools = "Tools"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .important: "flag"
        case .work: "briefcase"
        case .readLater: "text.book.closed"
        case .docs: "doc.text"
        case .code: "curlybraces"
        case .design: "paintpalette"
        case .money: "creditcard"
        case .travel: "airplane"
        case .shopping: "bag"
        case .media: "play.rectangle"
        case .people: "person.2"
        case .tools: "wrench.and.screwdriver"
        }
    }
}
