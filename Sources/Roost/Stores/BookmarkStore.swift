import AppKit
import Foundation
import OSLog

final class BookmarkStore: ObservableObject {
    @Published var bookmarks: [Bookmark] = [] {
        didSet { scheduleSave() }
    }
    @Published var selectedCategory: BookmarkCategory = .inbox
    @Published var selectedBookmarkID: Bookmark.ID?
    @Published var searchText = ""
    @Published var lastImportMessage = "Paste, drop, or type anything worth keeping."

    private let sorter = BookmarkSorter()
    private let clipboardImporter = ClipboardImporter()
    private let logger = Logger(subsystem: "com.ivynbean.Roost", category: "bookmarks")
    private let saveURL: URL
    private var saveTask: Task<Void, Never>?

    init(directory: URL? = nil) {
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            saveURL = directory.appendingPathComponent("bookmarks.json")
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let support = applicationSupport.appendingPathComponent("Roost", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            saveURL = support.appendingPathComponent("bookmarks.json")
            migrateLegacyDataIfNeeded(from: applicationSupport.appendingPathComponent("Stash", isDirectory: true))
            migrateLegacyDataIfNeeded(from: applicationSupport.appendingPathComponent("Hatch", isDirectory: true))
        }
        load()
    }

    var visibleBookmarks: [Bookmark] {
        bookmarks
            .filter { selectedCategory == .inbox ? true : $0.category == selectedCategory }
            .filter { bookmark in
                guard !searchText.isEmpty else { return true }
                return bookmark.title.localizedCaseInsensitiveContains(searchText)
                    || bookmark.location.localizedCaseInsensitiveContains(searchText)
                    || bookmark.summary.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var selectedBookmark: Bookmark? {
        guard let selectedBookmarkID else { return nil }
        return bookmarks.first { $0.id == selectedBookmarkID }
    }

    @discardableResult
    func add(rawValue: String) -> Bookmark? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let bookmark = sorter.bookmark(from: trimmed)
        if let existing = existingBookmark(matching: bookmark.location) {
            selectedBookmarkID = existing.id
            lastImportMessage = "Already in your roost: \(existing.title)"
            return existing
        }

        bookmarks.insert(bookmark, at: 0)
        selectedCategory = bookmark.category
        selectedBookmarkID = bookmark.id
        lastImportMessage = "Tucked away: \(bookmark.title)"
        logger.info("Captured bookmark category=\(bookmark.category.rawValue, privacy: .public) kind=\(bookmark.kind.rawValue, privacy: .public)")
        fetchRealTitleIfNeeded(for: bookmark)
        return bookmark
    }

    /// Replaces the host/path placeholder title with the page's actual
    /// <title> once it loads. Skipped if the user already renamed nothing —
    /// the placeholder is only swapped while it still matches what the
    /// sorter generated.
    private func fetchRealTitleIfNeeded(for bookmark: Bookmark) {
        guard bookmark.kind == .web, let url = URL(string: bookmark.location) else { return }
        let placeholder = bookmark.title
        Task { [weak self] in
            guard let title = await PageTitleFetcher.fetchTitle(for: url) else { return }
            await MainActor.run {
                guard let self,
                      let index = self.bookmarks.firstIndex(where: { $0.id == bookmark.id }),
                      self.bookmarks[index].title == placeholder else { return }
                self.bookmarks[index].title = title
                self.lastImportMessage = "Tucked away: \(title)"
            }
        }
    }

    @discardableResult
    func add(url: URL) -> Bookmark? {
        if url.isFileURL {
            return addFile(url)
        } else {
            return add(rawValue: url.absoluteString)
        }
    }

    func captureClipboard() {
        clipboardImporter.captureFromClipboard(into: self)
    }

    func move(_ bookmark: Bookmark, to category: BookmarkCategory) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].category = category
        selectedCategory = category
        logger.info("Moved bookmark id=\(bookmark.id.uuidString, privacy: .public) category=\(category.rawValue, privacy: .public)")
    }

    func move(bookmarkID: Bookmark.ID, to category: BookmarkCategory) {
        guard let bookmark = bookmarks.first(where: { $0.id == bookmarkID }) else { return }
        move(bookmark, to: category)
        selectedBookmarkID = bookmarkID
    }

    func toggleImportant(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].isImportant.toggle()
        logger.info("Toggled important id=\(bookmark.id.uuidString, privacy: .public) value=\(self.bookmarks[index].isImportant, privacy: .public)")
    }

    func deleteSelected() {
        guard let selectedBookmarkID else { return }
        bookmarks.removeAll { $0.id == selectedBookmarkID }
        self.selectedBookmarkID = visibleBookmarks.first?.id
    }

    func autoSortAll() {
        bookmarks = bookmarks.map { bookmark in
            var sorted = bookmark
            sorted.category = sorter.category(for: bookmark)
            return sorted
        }
        lastImportMessage = "Auto sorted \(bookmarks.count) items."
        logger.info("Auto sorted \(self.bookmarks.count) bookmarks")
    }

    func openSelected() {
        guard let selectedBookmark else { return }
        open(selectedBookmark)
    }

    func open(_ bookmark: Bookmark) {
        let url: URL?
        if bookmark.kind == .file {
            url = URL(fileURLWithPath: bookmark.location)
        } else {
            url = URL(string: bookmark.location)
        }

        guard let url else { return }
        NSWorkspace.shared.open(url)
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].lastOpenedAt = Date()
        }
        logger.info("Opened bookmark id=\(bookmark.id.uuidString, privacy: .public)")
    }

    /// Files a system screenshot without stealing focus: no selection or
    /// category change, since captures happen while the user is mid-task.
    func addScreenshot(_ url: URL) {
        guard existingBookmark(matching: url.path) == nil else { return }

        let bookmark = Bookmark(
            title: url.deletingPathExtension().lastPathComponent,
            location: url.path,
            kind: .file,
            category: .screenshots,
            summary: url.path
        )
        bookmarks.insert(bookmark, at: 0)
        lastImportMessage = "Screenshot saved: \(bookmark.title)"
        logger.info("Captured screenshot bookmark id=\(bookmark.id.uuidString, privacy: .public)")
    }

    func updateSummary(_ bookmarkID: Bookmark.ID, summary: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmarkID }),
              bookmarks[index].summary != summary else { return }
        bookmarks[index].summary = summary
    }

    private func existingBookmark(matching location: String) -> Bookmark? {
        bookmarks.first { $0.location == location }
    }

    @discardableResult
    private func addFile(_ url: URL) -> Bookmark {
        if let existing = existingBookmark(matching: url.path) {
            selectedBookmarkID = existing.id
            lastImportMessage = "Already in your roost: \(existing.title)"
            return existing
        }

        let bookmark = Bookmark(
            title: url.deletingPathExtension().lastPathComponent,
            location: url.path,
            kind: .file,
            category: .docs,
            summary: url.path
        )
        bookmarks.insert(bookmark, at: 0)
        selectedCategory = bookmark.category
        selectedBookmarkID = bookmark.id
        lastImportMessage = "Captured \(bookmark.title)"
        return bookmark
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else {
            bookmarks = Bookmark.samples
            return
        }

        do {
            bookmarks = try JSONDecoder.roost.decode([Bookmark].self, from: data)
        } catch {
            logger.error("Failed to load bookmarks: \(error.localizedDescription, privacy: .public)")
            bookmarks = Bookmark.samples
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let bookmarks = bookmarks
        let saveURL = saveURL
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                let data = try JSONEncoder.roost.encode(bookmarks)
                try data.write(to: saveURL, options: .atomic)
            } catch {
                Logger(subsystem: "com.ivynbean.Roost", category: "persistence")
                    .error("Failed to save bookmarks: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func migrateLegacyDataIfNeeded(from legacySupport: URL) {
        let legacySaveURL = legacySupport.appendingPathComponent("bookmarks.json")
        guard !FileManager.default.fileExists(atPath: saveURL.path),
              FileManager.default.fileExists(atPath: legacySaveURL.path) else { return }

        do {
            try FileManager.default.copyItem(at: legacySaveURL, to: saveURL)
            logger.info("Migrated legacy bookmarks to Roost")
        } catch {
            logger.error("Failed to migrate legacy bookmarks: \(error.localizedDescription, privacy: .public)")
        }
    }
}
