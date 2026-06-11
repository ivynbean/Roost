import Darwin
import XCTest
@testable import Roost

final class ScreenshotDetectorTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoostShotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeFile(named name: String, stamped: Bool = false) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        if stamped {
            // Minimal binary plist containing boolean true, as the system writes it.
            let value = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
            let result = value.withUnsafeBytes { bytes in
                setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", bytes.baseAddress, value.count, 0, 0)
            }
            XCTAssertEqual(result, 0)
        }
        return url
    }

    func testScreenshotNamedFileWithoutMetadataStampIsDetected() throws {
        let url = try makeFile(named: "Screenshot 2026-06-11 at 10.40.00.png")
        XCTAssertTrue(ScreenshotDetector.isScreenshot(at: url))
    }

    func testLegacyScreenShotNameIsDetected() throws {
        let url = try makeFile(named: "Screen Shot 2026-06-11 at 10.40.00.png")
        XCTAssertTrue(ScreenshotDetector.isScreenshot(at: url))
    }

    func testMetadataStampedFileWithArbitraryNameIsDetected() throws {
        let url = try makeFile(named: "whatever.png", stamped: true)
        XCTAssertTrue(ScreenshotDetector.isScreenshot(at: url))
    }

    func testCustomScreenshotPrefixIsDetected() throws {
        let url = try makeFile(named: "Grab 2026-06-11.png")
        XCTAssertFalse(ScreenshotDetector.isScreenshot(at: url))
        XCTAssertTrue(ScreenshotDetector.isScreenshot(at: url, customPrefix: "Grab"))
    }

    func testOrdinaryImageIsNotDetected() throws {
        let url = try makeFile(named: "vacation-photo.png")
        XCTAssertFalse(ScreenshotDetector.isScreenshot(at: url))
    }

    func testNonMediaFileIsNotDetected() throws {
        let url = try makeFile(named: "Screenshot notes.txt")
        XCTAssertFalse(ScreenshotDetector.isScreenshot(at: url))
    }

    func testScreenRecordingIsDetected() throws {
        let url = try makeFile(named: "Screen Recording 2026-06-11 at 10.40.00.mov")
        XCTAssertTrue(ScreenshotDetector.isScreenshot(at: url))
    }
}
