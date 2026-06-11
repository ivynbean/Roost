import UniformTypeIdentifiers
import XCTest
@testable import Roost

final class BookmarkDropHandlerTests: XCTestCase {
    private var tempDirectory: URL!
    private var store: BookmarkStore!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoostDropTests-\(UUID().uuidString)", isDirectory: true)
        store = BookmarkStore(directory: tempDirectory)
        store.bookmarks = []
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testCapturesNativeURLObjectDrop() {
        let provider = NSItemProvider(object: NSURL(string: "https://example.com/article")!)

        let captured = expectation(description: "captured")
        let handled = BookmarkDropHandler.handle([provider], store: store) { bookmark in
            XCTAssertEqual(bookmark.location, "https://example.com/article")
            XCTAssertEqual(bookmark.kind, .web)
            captured.fulfill()
        }

        XCTAssertTrue(handled)
        wait(for: [captured], timeout: 5)
    }

    func testCapturesRawURLDataWithTrailingNullByte() {
        // Chromium-style payload: public.url delivered as bytes with a
        // trailing NUL instead of an NSURL object.
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all) { completion in
            completion("https://example.com/from-chromium\u{0}".data(using: .utf8), nil)
            return nil
        }

        let captured = expectation(description: "captured")
        let handled = BookmarkDropHandler.handle([provider], store: store) { bookmark in
            XCTAssertEqual(bookmark.location, "https://example.com/from-chromium")
            captured.fulfill()
        }

        XCTAssertTrue(handled)
        wait(for: [captured], timeout: 5)
    }

    func testCapturesURLDraggedAsPlainText() {
        let provider = NSItemProvider(object: "https://example.com/text-flavor\n" as NSString)

        let captured = expectation(description: "captured")
        let handled = BookmarkDropHandler.handle([provider], store: store) { bookmark in
            XCTAssertEqual(bookmark.location, "https://example.com/text-flavor")
            XCTAssertEqual(bookmark.kind, .web)
            captured.fulfill()
        }

        XCTAssertTrue(handled)
        wait(for: [captured], timeout: 5)
    }

    func testCapturesEveryProviderInAMultiItemDrop() {
        let providers = [
            NSItemProvider(object: NSURL(string: "https://example.com/one")!),
            NSItemProvider(object: NSURL(string: "https://example.com/two")!)
        ]

        let captured = expectation(description: "captured both")
        captured.expectedFulfillmentCount = 2
        let handled = BookmarkDropHandler.handle(providers, store: store) { _ in
            captured.fulfill()
        }

        XCTAssertTrue(handled)
        wait(for: [captured], timeout: 5)
        XCTAssertEqual(store.bookmarks.count, 2)
    }

    func testLooseTextDropBecomesTextBookmark() {
        let provider = NSItemProvider(object: "remember to water the plants" as NSString)

        let captured = expectation(description: "captured")
        let handled = BookmarkDropHandler.handle([provider], store: store) { bookmark in
            XCTAssertEqual(bookmark.kind, .text)
            captured.fulfill()
        }

        XCTAssertTrue(handled)
        wait(for: [captured], timeout: 5)
    }
}
