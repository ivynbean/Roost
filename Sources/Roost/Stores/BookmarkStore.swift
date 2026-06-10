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

    init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let support = applicationSupport.appendingPathComponent("Roost", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        saveURL = support.appendingPathComponent("bookmarks.json")
        migrateLegacyDataIfNeeded(from: applicationSupport.appendingPathComponent("Stash", isDirectory: true))
        migrateLegacyDataIfNeeded(from: applicationSupport.appendingPathComponent("Hatch", isDirectory: true))
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

    func selectCategory(_ category: BookmarkCategory) {
        selectedCategory = category
        selectedBookmarkID = visibleBookmarks.first?.id
    }

    func add(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let bookmark = sorter.bookmark(from: trimmed)
        bookmarks.insert(bookmark, at: 0)
        selectedCategory = bookmark.category
        selectedBookmarkID = bookmark.id
        lastImportMessage = "Tucked away: \(bookmark.title)"
        logger.info("Captured bookmark category=\(bookmark.category.rawValue, privacy: .public) kind=\(bookmark.kind.rawValue, privacy: .public)")
    }

    func add(url: URL) {
        if url.isFileURL {
            addFile(url)
        } else {
            add(rawValue: url.absoluteString)
        }
    }

    func captureClipboard() {
        clipboardImporter.captureFromClipboard(into: self)
    }

    func move(_ bookmark: Bookmark, to category: BookmarkCategory) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].category = category
        selectedCategory = category
        selectedBookmarkID = bookmark.id
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

    private func addFile(_ url: URL) {
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
