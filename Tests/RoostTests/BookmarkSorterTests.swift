import XCTest
@testable import Roost

final class BookmarkSorterTests: XCTestCase {
    func testCreatesWebBookmarkFromCopiedURL() {
        let bookmark = BookmarkSorter().bookmark(from: "https://developer.apple.com/documentation/swiftui")

        XCTAssertEqual(bookmark.kind, .web)
        XCTAssertEqual(bookmark.category, .code)
        XCTAssertEqual(bookmark.location, "https://developer.apple.com/documentation/swiftui")
        XCTAssertTrue(bookmark.title.contains("developer.apple.com"))
    }

    func testCreatesFileBookmarkFromPath() {
        let bookmark = BookmarkSorter().bookmark(from: "/Users/example/Downloads/Invoice.pdf")

        XCTAssertEqual(bookmark.kind, .file)
        XCTAssertEqual(bookmark.category, .docs)
        XCTAssertEqual(bookmark.title, "Invoice")
    }

    func testSortsCommonCatchAllInputsIntoSmartPiles() {
        let sorter = BookmarkSorter()

        XCTAssertEqual(sorter.category(for: "https://github.com/ivynbean/Roost"), .code)
        XCTAssertEqual(sorter.category(for: "Figma logo inspiration board"), .design)
        XCTAssertEqual(sorter.category(for: "flight hotel itinerary for June"), .travel)
        XCTAssertEqual(sorter.category(for: "receipt for credit card subscription"), .money)
        XCTAssertEqual(sorter.category(for: "totally random loose thought"), .readLater)
    }
}
