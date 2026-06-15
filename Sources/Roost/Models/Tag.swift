import Foundation

struct Tag: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var colorIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }
}
