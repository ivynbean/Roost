import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var location: String
    var kind: BookmarkKind
    var category: BookmarkCategory
    var projectID: UUID?
    var tagIDs: [UUID]
    var isImportant: Bool
    var summary: String
    var note: String
    var createdAt: Date
    var lastOpenedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case location
        case kind
        case category
        case projectID
        case tagIDs
        case isImportant
        case summary
        case note
        case createdAt
        case lastOpenedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        kind: BookmarkKind,
        category: BookmarkCategory = .readLater,
        projectID: UUID? = nil,
        tagIDs: [UUID] = [],
        isImportant: Bool = false,
        summary: String = "",
        note: String = "",
        createdAt: Date = Date(),
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.kind = kind
        self.category = category.normalized
        self.projectID = projectID
        self.tagIDs = tagIDs
        self.isImportant = isImportant || category == .important
        self.summary = summary
        self.note = note
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
        category = decodedCategory.normalized
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        isImportant = (try container.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false) || decodedCategory == .important
        summary = try container.decode(String.self, forKey: .summary)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    }

    var displayTitle: String {
        if kind == .file {
            return Self.friendlyFileTitle(for: location, fallback: title)
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? location : trimmed
    }

    var displayLocation: String {
        guard kind == .file else { return location }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if location.hasPrefix(home) {
            return "~" + location.dropFirst(home.count)
        }
        return location
    }

    var displayCategory: BookmarkCategory {
        category.normalized
    }

    var secondaryLabel: String {
        switch kind {
        case .web:
            if let url = URL(string: location),
               let host = url.host(percentEncoded: false) {
                return host.replacingOccurrences(of: "www.", with: "")
            }
            return "Saved link"
        case .file:
            if isScreenshot {
                return "Screenshot capture"
            }

            let path = (location as NSString).expandingTildeInPath
            let folder = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
            return folder.isEmpty ? "Local file" : "From \(folder)"
        case .text:
            return summary.isEmpty ? "Quick note" : summary.firstLine(maxLength: 72)
        }
    }

    var isScreenshot: Bool {
        guard kind == .file else { return false }
        return Self.looksLikeScreenshot(location) || Self.looksLikeScreenshot(title)
    }

    static func friendlyFileTitle(for path: String, fallback: String) -> String {
        let url = URL(fileURLWithPath: path)
        let stem = url.deletingPathExtension().lastPathComponent
        let source = stem.isEmpty ? fallback : stem

        if let screenshotTitle = friendlyScreenshotTitle(from: source) {
            return screenshotTitle
        }

        let decoded = source.removingPercentEncoding ?? source
        let spaced = decoded
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return spaced.isEmpty ? fallback : spaced
    }

    private static func friendlyScreenshotTitle(from rawTitle: String) -> String? {
        let pattern = #"^Screenshot (\d{4})-(\d{2})-(\d{2}) at (\d{1,2})[.:](\d{2})(?:[.:](\d{2}))?\s*([AP]M)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(rawTitle.startIndex..<rawTitle.endIndex, in: rawTitle)
        guard let match = regex.firstMatch(in: rawTitle, range: range),
              match.numberOfRanges >= 6,
              let year = component(at: 1, in: rawTitle, match: match),
              let month = component(at: 2, in: rawTitle, match: match),
              let day = component(at: 3, in: rawTitle, match: match),
              let hour = component(at: 4, in: rawTitle, match: match),
              let minute = component(at: 5, in: rawTitle, match: match) else {
            return nil
        }

        let marker = component(at: 7, in: rawTitle, match: match) ?? ""
        let input = "\(year)-\(month)-\(day) \(hour):\(minute) \(marker)".trimmingCharacters(in: .whitespaces)
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = marker.isEmpty ? "yyyy-MM-dd H:mm" : "yyyy-MM-dd h:mm a"

        guard let date = parser.date(from: input) else {
            return "Screenshot - \(month)/\(day) \(hour):\(minute)"
        }

        let output = DateFormatter()
        output.locale = Locale.current
        output.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
        return "Screenshot - \(output.string(from: date))"
    }

    private static func looksLikeScreenshot(_ rawValue: String) -> Bool {
        let source: String
        if rawValue.hasPrefix("/") || rawValue.hasPrefix("~") {
            let path = (rawValue as NSString).expandingTildeInPath
            source = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        } else {
            source = rawValue
        }

        return friendlyScreenshotTitle(from: source) != nil
    }

    private static func component(at index: Int, in string: String, match: NSTextCheckingResult) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: string) else {
            return nil
        }
        return String(string[range])
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
        allCases.filter { $0 != .important && $0 != .inbox }
    }

    var normalized: BookmarkCategory {
        switch self {
        case .inbox, .important: .readLater
        default: self
        }
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
