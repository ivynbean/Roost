import XCTest
@testable import Roost

final class PageTitleFetcherTests: XCTestCase {
    func testExtractsTitleFromHTML() {
        let html = "<html><head><title>Rick Astley - Never Gonna Give You Up - YouTube</title></head><body></body></html>"
        XCTAssertEqual(PageTitleFetcher.title(fromHTML: html), "Rick Astley - Never Gonna Give You Up - YouTube")
    }

    func testHandlesAttributesEntitiesAndWhitespace() {
        let html = """
        <TITLE data-rh="true">
            Tom &amp; Jerry &mdash; a &#8220;classic&#8221;
        </TITLE>
        """
        XCTAssertEqual(PageTitleFetcher.title(fromHTML: html), "Tom & Jerry — a “classic”")
    }

    func testReturnsNilWhenNoTitleTag() {
        XCTAssertNil(PageTitleFetcher.title(fromHTML: "<html><body>no title here</body></html>"))
        XCTAssertNil(PageTitleFetcher.title(fromHTML: "<title>   </title>"))
    }

    func testTruncatesVeryLongTitles() throws {
        let long = String(repeating: "a", count: 500)
        let title = try XCTUnwrap(PageTitleFetcher.title(fromHTML: "<title>\(long)</title>"))
        XCTAssertEqual(title.count, 120)
    }
}
