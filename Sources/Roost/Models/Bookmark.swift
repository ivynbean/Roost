import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var location: String
    var kind: BookmarkKind
    var category: BookmarkCategory
    var isImportant: Bool
    var summary: String
    var createdAt: Date
    var lastOpenedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case location
        case kind
        case category
        case isImportant
        case summary
        case createdAt
        case lastOpenedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        kind: BookmarkKind,
        category: BookmarkCategory = .inbox,
        isImportant: Bool = false,
        summary: String = "",
        createdAt: Date = Date(),
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.kind = kind
        self.category = category == .important ? .inbox : category
        self.isImportant = isImportant || category == .important
        self.summary = summary
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        location = try container.decode(String.self, forKey: .location)
        kind = try container.decode(BookmarkKind.self, forKey: .kind)
        let decodedCategory = try container.decode(BookmarkCategory.self, forKey: .category)
        category = decodedCategory == .important ? .inbox : decodedCategory
        isImportant = (try container.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false) || decodedCategory == .important
        summary = try container.decode(String.self, forKey: .summary)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
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
    case inbox = "Inbox"
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
    case screenshots = "Screenshots"
    case people = "People"
    case tools = "Tools"

    var id: String { rawValue }

    static var pileCases: [BookmarkCategory] {
        allCases.filter { $0 != .important }
    }

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
        case .screenshots: "camera.viewfinder"
        case .people: "person.2"
        case .tools: "wrench.and.screwdriver"
        }
    }
}
