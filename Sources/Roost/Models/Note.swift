import Foundation

struct Project: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var parentID: UUID?
    var tagID: UUID?
    var symbolName: String
    var colorIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        parentID: UUID? = nil,
        tagID: UUID? = nil,
        symbolName: String = "folder",
        colorIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.tagID = tagID
        self.symbolName = symbolName
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentID
        case tagID
        case symbolName
        case colorIndex
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
        tagID = try container.decodeIfPresent(UUID.self, forKey: .tagID)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "folder"
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var projectID: UUID?
    var date: Date?
    var isTask: Bool
    var isOnAgenda: Bool
    var isDone: Bool
    var tagIDs: [UUID]
    var linkedBookmarkIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        projectID: UUID? = nil,
        date: Date? = nil,
        isTask: Bool = false,
        isOnAgenda: Bool = false,
        isDone: Bool = false,
        tagIDs: [UUID] = [],
        linkedBookmarkIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.projectID = projectID
        self.date = date
        self.isTask = isTask
        self.isOnAgenda = isOnAgenda
        self.isDone = isDone
        self.tagIDs = tagIDs
        self.linkedBookmarkIDs = linkedBookmarkIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case projectID
        case date
        case isTask
        case isOnAgenda
        case isDone
        case tagIDs
        case linkedBookmarkIDs
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        isTask = try container.decodeIfPresent(Bool.self, forKey: .isTask) ?? false
        isOnAgenda = try container.decodeIfPresent(Bool.self, forKey: .isOnAgenda) ?? false
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        linkedBookmarkIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedBookmarkIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    /// The day this note belongs to on the timeline: its assigned date when
    /// scheduled, otherwise the day it was captured.
    var timelineDate: Date {
        date ?? createdAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstContentLine = content.firstLine(maxLength: 48)
        return firstContentLine.isEmpty ? "Untitled note" : firstContentLine
    }
}
