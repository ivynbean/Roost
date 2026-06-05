import XCTest
@testable import Roost

final class BookmarkCodingTests: XCTestCase {
    func testImportantLegacyCategoryDecodesToInboxWithFlag() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "title": "Important thing",
          "location": "https://example.com",
          "kind": "web",
          "category": "Important",
          "summary": "Legacy important category",
          "createdAt": "2026-06-05T00:00:00Z"
        }
        """.data(using: .utf8)!

        let bookmark = try JSONDecoder.roost.decode(Bookmark.self, from: json)

        XCTAssertEqual(bookmark.category, .inbox)
        XCTAssertTrue(bookmark.isImportant)
    }

    func testRoostEncoderRoundTripsSampleBookmarks() throws {
        let data = try JSONEncoder.roost.encode(Bookmark.samples)
        let decoded = try JSONDecoder.roost.decode([Bookmark].self, from: data)

        XCTAssertEqual(decoded.count, Bookmark.samples.count)
        XCTAssertEqual(decoded.map(\.title), Bookmark.samples.map(\.title))
        XCTAssertEqual(decoded.map(\.location), Bookmark.samples.map(\.location))
        XCTAssertEqual(decoded.map(\.kind), Bookmark.samples.map(\.kind))
        XCTAssertEqual(decoded.map(\.category), Bookmark.samples.map(\.category))
        XCTAssertEqual(decoded.map(\.summary), Bookmark.samples.map(\.summary))
    }
}
