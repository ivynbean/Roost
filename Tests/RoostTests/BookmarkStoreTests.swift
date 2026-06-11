import XCTest
@testable import Roost

final class BookmarkStoreTests: XCTestCase {
    private var tempDirectory: URL!
    private var store: BookmarkStore!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoostStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = BookmarkStore(directory: tempDirectory)
        store.bookmarks = []
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testAddScreenshotFilesIntoScreenshotsCollection() {
        store.addScreenshot(URL(fileURLWithPath: "/Users/example/Desktop/Screenshot 2026-06-11 at 10.00.00.png"))

        XCTAssertEqual(store.bookmarks.count, 1)
        let bookmark = store.bookmarks[0]
        XCTAssertEqual(bookmark.kind, .file)
        XCTAssertEqual(bookmark.category, .screenshots)
        XCTAssertEqual(bookmark.title, "Screenshot 2026-06-11 at 10.00.00")
    }

    func testAddScreenshotDoesNotStealSelection() {
        store.selectedCategory = .inbox
        store.selectedBookmarkID = nil

        store.addScreenshot(URL(fileURLWithPath: "/Users/example/Desktop/Screenshot.png"))

        XCTAssertEqual(store.selectedCategory, .inbox)
        XCTAssertNil(store.selectedBookmarkID)
    }

    func testAddScreenshotDedupesSamePath() {
        let url = URL(fileURLWithPath: "/Users/example/Desktop/Screenshot.png")
        store.addScreenshot(url)
        store.addScreenshot(url)

        XCTAssertEqual(store.bookmarks.count, 1)
    }

    func testAddRawValueDedupesExistingLocation() {
        store.add(rawValue: "https://example.com/article")
        let again = store.add(rawValue: "https://example.com/article")

        XCTAssertEqual(store.bookmarks.count, 1)
        XCTAssertEqual(again?.id, store.bookmarks[0].id)
    }
}
