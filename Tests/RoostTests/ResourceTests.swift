import XCTest
@testable import Roost

final class ResourceTests: XCTestCase {
    func testAppImageResourceLoads() {
        XCTAssertNotNil(RoostImage.nsImage())
    }
}
