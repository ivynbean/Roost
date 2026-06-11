import Darwin
import Foundation
import OSLog

/// Decides whether a file is a screenshot. Checks the metadata stamp the
/// system applies to captures, falling back to filename conventions because
/// not every capture path reliably gets the stamp.
enum ScreenshotDetector {
    private static let mediaExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "pdf", "mov", "mp4"]
    private static let defaultPrefixes = ["Screenshot", "Screen Shot", "Screen Recording", "CleanShot"]

    static func isScreenshot(at url: URL, customPrefix: String? = nil) -> Bool {
        guard mediaExtensions.contains(url.pathExtension.lowercased()) else { return false }

        if getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0 {
            return true
        }

        var prefixes = defaultPrefixes
        if let customPrefix, !customPrefix.isEmpty {
            prefixes.append(customPrefix)
        }
        let name = url.lastPathComponent
        return prefixes.contains { name.hasPrefix($0) }
    }
}

/// Captures screenshots taken with the system screenshot tool (⇧⌘3/4/5)
/// into the store automatically. Two detection layers run together:
/// a directory monitor on the configured screenshot folder (primary, catches
/// everything immediately) and a Spotlight query for the screen-capture
/// metadata flag (catches screenshots saved anywhere else). Screenshots
/// already on disk when watching starts are left alone.
final class ScreenshotWatcher: NSObject, ObservableObject {
    @Published private(set) var isWatching = false

    private let query = NSMetadataQuery()
    private let logger = Logger(subsystem: "com.ivynbean.Roost", category: "screenshots")
    private weak var store: BookmarkStore?
    private var startedAt = Date()
    private var capturedPaths = Set<String>()

    private var folderSource: DispatchSourceFileSystemObject?
    private var watchedFolder: URL?
    private var knownFiles = Set<String>()

    func start(store: BookmarkStore) {
        guard !isWatching else { return }
        self.store = store
        startedAt = Date()

        startFolderMonitor()
        startSpotlightQuery()
        isWatching = true
        logger.info("Screenshot watcher started")
    }

    func stop() {
        guard isWatching else { return }
        query.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
        folderSource?.cancel()
        folderSource = nil
        isWatching = false
        logger.info("Screenshot watcher stopped")
    }

    // MARK: - Folder monitor (primary)

    private static func screenshotFolder() -> URL {
        if let configured = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) as? String {
            return URL(fileURLWithPath: (configured as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    private static func customPrefix() -> String? {
        CFPreferencesCopyAppValue("name" as CFString, "com.apple.screencapture" as CFString) as? String
    }

    private func startFolderMonitor() {
        let folder = Self.screenshotFolder()
        watchedFolder = folder

        // Listing the folder also triggers the macOS folder-access prompt the
        // first time; without that grant neither detection layer can see it.
        knownFiles = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])

        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else {
            logger.error("Cannot monitor screenshot folder \(folder.path, privacy: .public)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            self?.folderChanged()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        folderSource = source
        logger.info("Monitoring screenshot folder \(folder.path, privacy: .public) with \(self.knownFiles.count) existing files")
    }

    private func folderChanged() {
        guard let folder = watchedFolder else { return }
        let current = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let newFiles = current.subtracting(knownFiles)
        knownFiles = current

        for name in newFiles where !name.hasPrefix(".") {
            let url = folder.appendingPathComponent(name)
            // Give screencapture a beat to finish writing and stamping.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.captureIfScreenshot(url)
            }
        }
    }

    private func captureIfScreenshot(_ url: URL) {
        guard ScreenshotDetector.isScreenshot(at: url, customPrefix: Self.customPrefix()) else {
            logger.info("Ignored non-screenshot file in screenshot folder")
            return
        }
        capture(url)
    }

    private func capture(_ url: URL) {
        guard capturedPaths.insert(url.path).inserted else { return }
        logger.info("New screenshot detected")
        store?.addScreenshot(url)
    }

    // MARK: - Spotlight query (secondary, catches captures saved elsewhere)

    private func startSpotlightQuery() {
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.notificationBatchingInterval = 1

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(initialGatherFinished),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryUpdated(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
    }

    @objc private func initialGatherFinished() {
        // The initial gather lists every screenshot already on disk; those
        // stay untouched. Updates from here on are new captures.
        query.enableUpdates()
        logger.info("Spotlight baseline: \(self.query.resultCount) existing screenshots ignored")
    }

    @objc private func queryUpdated(_ notification: Notification) {
        // New screenshots usually arrive as added items, but metadata that's
        // stamped a beat after the file lands surfaces as a change instead.
        let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        let changed = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []

        for item in added + changed {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !capturedPaths.contains(path) else { continue }

            // Re-index events can replay old files; only take fresh captures.
            let created = item.value(forAttribute: NSMetadataItemContentCreationDateKey) as? Date ?? Date()
            guard created >= startedAt else { continue }

            let url = URL(fileURLWithPath: path)
            DispatchQueue.main.async { [weak self] in
                self?.capture(url)
            }
        }
    }
}
