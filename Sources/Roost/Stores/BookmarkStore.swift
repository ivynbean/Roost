import AppKit
import Foundation
import OSLog

final class BookmarkStore: ObservableObject {
    @Published var bookmarks: [Bookmark] = [] {
        didSet { scheduleSave() }
    }
    @Published var selectedCategory: BookmarkCategory = .readLater
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
        bookmarks(in: selectedCategory)
            .filter { bookmark in
                guard !searchText.isEmpty else { return true }
                return bookmark.displayTitle.localizedCaseInsensitiveContains(searchText)
                    || bookmark.displayLocation.localizedCaseInsensitiveContains(searchText)
                    || bookmark.summary.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var selectedBookmark: Bookmark? {
        guard let selectedBookmarkID else { return nil }
        return bookmarks.first { $0.id == selectedBookmarkID }
    }

    func containsBookmark(id: UUID) -> Bool {
        bookmarks.contains { $0.id == id }
    }

    func bookmarks(in category: BookmarkCategory) -> [Bookmark] {
        bookmarks.filter { bookmark in
            if category == .screenshots {
                return bookmark.isScreenshot
            }
            return bookmark.displayCategory == category
        }
    }

    func bookmarks(inProject projectID: UUID) -> [Bookmark] {
        bookmarks
            .filter { $0.projectID == projectID }
            .filter { bookmark in
                guard !searchText.isEmpty else { return true }
                return bookmark.displayTitle.localizedCaseInsensitiveContains(searchText)
                    || bookmark.displayLocation.localizedCaseInsensitiveContains(searchText)
                    || bookmark.summary.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func bookmarks(withTag tagID: UUID) -> [Bookmark] {
        bookmarks
            .filter { $0.tagIDs.contains(tagID) }
            .filter { bookmark in
                guard !searchText.isEmpty else { return true }
                return bookmark.displayTitle.localizedCaseInsensitiveContains(searchText)
                    || bookmark.displayLocation.localizedCaseInsensitiveContains(searchText)
                    || bookmark.summary.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(rawValue: String, projectID: UUID? = nil, projectTagID: UUID? = nil) -> Bookmark? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let internalID = UUID(uuidString: trimmed),
           let existing = bookmarks.first(where: { $0.id == internalID }) {
            if let projectID {
                assign(existing, toProject: projectID, projectTagID: projectTagID)
            }
            selectedBookmarkID = existing.id
            selectedCategory = existing.displayCategory
            lastImportMessage = "Already in your roost: \(existing.displayTitle)"
            return existing
        }

        var bookmark = sorter.bookmark(from: trimmed)
        bookmark.projectID = projectID
        if let projectTagID {
            bookmark.tagIDs.append(projectTagID)
        }
        if let existing = existingBookmark(matching: bookmark.location) {
            if let projectID {
                assign(existing, toProject: projectID, projectTagID: projectTagID)
            }
            selectedBookmarkID = existing.id
            selectedCategory = existing.displayCategory
            lastImportMessage = "Already in your roost: \(existing.displayTitle)"
            return existing
        }

        bookmarks.insert(bookmark, at: 0)
        selectedCategory = bookmark.displayCategory
        selectedBookmarkID = bookmark.id
        lastImportMessage = "Tucked away: \(bookmark.displayTitle)"
        logger.info("Captured bookmark category=\(bookmark.displayCategory.rawValue, privacy: .public) kind=\(bookmark.kind.rawValue, privacy: .public)")
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
    func add(url: URL, projectID: UUID? = nil, projectTagID: UUID? = nil) -> Bookmark? {
        if url.isFileURL {
            return addFile(url, projectID: projectID, projectTagID: projectTagID)
        } else {
            return add(rawValue: url.absoluteString, projectID: projectID, projectTagID: projectTagID)
        }
    }

    func captureClipboard() {
        clipboardImporter.captureFromClipboard(into: self)
    }

    func move(_ bookmark: Bookmark, to category: BookmarkCategory) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].category = category.normalized
        selectedCategory = category.normalized
        selectedBookmarkID = bookmark.id
        logger.info("Moved bookmark id=\(bookmark.id.uuidString, privacy: .public) category=\(category.normalized.rawValue, privacy: .public)")
    }

    func move(bookmarkID: Bookmark.ID, to category: BookmarkCategory) {
        guard let bookmark = bookmarks.first(where: { $0.id == bookmarkID }) else { return }
        move(bookmark, to: category)
        selectedBookmarkID = bookmarkID
    }

    func assign(_ bookmark: Bookmark, toProject projectID: UUID?, projectTagID: UUID? = nil) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].projectID = projectID
        if let projectTagID, !bookmarks[index].tagIDs.contains(projectTagID) {
            bookmarks[index].tagIDs.append(projectTagID)
        }
        selectedBookmarkID = bookmark.id
        logger.info("Assigned bookmark id=\(bookmark.id.uuidString, privacy: .public) project=\(projectID?.uuidString ?? "none", privacy: .public)")
    }

    func assign(bookmarkID: Bookmark.ID, toProject projectID: UUID?, projectTagID: UUID? = nil) {
        guard let bookmark = bookmarks.first(where: { $0.id == bookmarkID }) else { return }
        assign(bookmark, toProject: projectID, projectTagID: projectTagID)
    }

    func clearProjects(_ projectIDs: Set<UUID>) {
        guard !projectIDs.isEmpty else { return }
        bookmarks = bookmarks.map { bookmark in
            var bookmark = bookmark
            if let projectID = bookmark.projectID, projectIDs.contains(projectID) {
                bookmark.projectID = nil
            }
            return bookmark
        }
    }

    func addProjectTag(_ tagID: UUID, toProject projectID: UUID) {
        bookmarks = bookmarks.map { bookmark in
            var bookmark = bookmark
            if bookmark.projectID == projectID, !bookmark.tagIDs.contains(tagID) {
                bookmark.tagIDs.append(tagID)
            }
            return bookmark
        }
    }

    func toggleImportant(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].isImportant.toggle()
        logger.info("Toggled important id=\(bookmark.id.uuidString, privacy: .public) value=\(self.bookmarks[index].isImportant, privacy: .public)")
    }

    func rename(_ id: Bookmark.ID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        bookmarks[index].title = trimmed
        logger.info("Renamed bookmark id=\(id.uuidString, privacy: .public)")
    }

    func deleteSelected() {
        guard let selectedBookmarkID else { return }
        bookmarks.removeAll { $0.id == selectedBookmarkID }
        self.selectedBookmarkID = visibleBookmarks.first?.id
    }

    func delete(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks.remove(at: index)
        if selectedBookmarkID == bookmark.id {
            selectedBookmarkID = visibleBookmarks.first?.id
        }
        lastImportMessage = "Removed \(bookmark.displayTitle)"
        logger.info("Deleted bookmark id=\(bookmark.id.uuidString, privacy: .public)")
    }

    func openSelected() {
        guard let selectedBookmark else { return }
        open(selectedBookmark)
    }

    func open(_ bookmark: Bookmark) {
        guard let url = resolvedOpenURL(for: bookmark) else {
            lastImportMessage = "Couldn't open \(bookmark.displayTitle)."
            logger.error("Failed to resolve open URL for bookmark id=\(bookmark.id.uuidString, privacy: .public)")
            return
        }
        let didStartSecurityScope = startSecurityScopeIfNeeded(for: url, bookmark: bookmark)
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let didOpen: Bool
        if bookmark.kind == .file {
            let path = url.path
            guard FileManager.default.fileExists(atPath: path) else {
                lastImportMessage = "File not found: \(bookmark.displayTitle)"
                logger.error("Open failed, missing file path=\(path, privacy: .public)")
                return
            }
            didOpen = NSWorkspace.shared.openFile(path) || NSWorkspace.shared.open(url)
        } else {
            didOpen = NSWorkspace.shared.open(url)
        }

        guard didOpen else {
            lastImportMessage = "Couldn't open \(bookmark.displayTitle)."
            logger.error("Workspace refused open for bookmark id=\(bookmark.id.uuidString, privacy: .public)")
            return
        }

        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].lastOpenedAt = Date()
        }
        logger.info("Opened bookmark id=\(bookmark.id.uuidString, privacy: .public)")
    }

    func openInPreview(_ bookmark: Bookmark) {
        guard let url = resolvedOpenURL(for: bookmark), url.isFileURL else {
            open(bookmark)
            return
        }
        let didStartSecurityScope = startSecurityScopeIfNeeded(for: url, bookmark: bookmark)

        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            lastImportMessage = "File not found: \(bookmark.displayTitle)"
            logger.error("Preview failed, missing file path=\(path, privacy: .public)")
            return
        }

        guard let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            open(bookmark)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: previewAppURL, configuration: configuration) { [weak self] _, error in
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastImportMessage = "Couldn't open \(bookmark.displayTitle) in Preview."
                    self.logger.error("Preview app open failed id=\(bookmark.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    return
                }

                if let index = self.bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
                    self.bookmarks[index].lastOpenedAt = Date()
                }
                self.lastImportMessage = "Opened \(bookmark.displayTitle) in Preview"
                self.logger.info("Opened bookmark in Preview id=\(bookmark.id.uuidString, privacy: .public)")
            }
        }
    }

    /// Files a system screenshot without stealing focus: no selection or
    /// category change, since captures happen while the user is mid-task.
    func addScreenshot(_ url: URL) {
        guard existingBookmark(matching: url.path) == nil else { return }

        var bookmark = Bookmark(
            title: Bookmark.friendlyFileTitle(for: url.path, fallback: url.deletingPathExtension().lastPathComponent),
            location: url.path,
            kind: .file,
            category: .screenshots,
            summary: url.path
        )
        bookmark.securityScopedBookmarkData = securityScopedBookmarkData(for: url)
        bookmarks.insert(bookmark, at: 0)
        lastImportMessage = "Screenshot saved: \(bookmark.displayTitle)"
        logger.info("Captured screenshot bookmark id=\(bookmark.id.uuidString, privacy: .public)")
    }

    func updateSummary(_ bookmarkID: Bookmark.ID, summary: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmarkID }),
              bookmarks[index].summary != summary else { return }
        bookmarks[index].summary = summary
    }

    func updateNote(_ bookmarkID: Bookmark.ID, note: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmarkID }),
              bookmarks[index].note != note else { return }
        bookmarks[index].note = note
    }

    func addTag(_ tagID: UUID, to bookmarkID: Bookmark.ID) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmarkID }),
              !bookmarks[index].tagIDs.contains(tagID) else { return }
        bookmarks[index].tagIDs.append(tagID)
    }

    func removeTag(_ tagID: UUID, from bookmarkID: Bookmark.ID) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { return }
        bookmarks[index].tagIDs.removeAll { $0 == tagID }
    }

    private func existingBookmark(matching location: String) -> Bookmark? {
        bookmarks.first { $0.location == location }
    }

    @discardableResult
    private func addFile(_ url: URL, projectID: UUID? = nil, projectTagID: UUID? = nil) -> Bookmark {
        if let existing = existingBookmark(matching: url.path) {
            if let projectID {
                assign(existing, toProject: projectID, projectTagID: projectTagID)
            }
            selectedBookmarkID = existing.id
            selectedCategory = existing.displayCategory
            lastImportMessage = "Already in your roost: \(existing.displayTitle)"
            return existing
        }

        var bookmark = Bookmark(
            title: Bookmark.friendlyFileTitle(for: url.path, fallback: url.deletingPathExtension().lastPathComponent),
            location: url.path,
            kind: .file,
            category: .docs,
            projectID: projectID,
            tagIDs: projectTagID.map { [$0] } ?? [],
            summary: url.path
        )
        bookmark.securityScopedBookmarkData = securityScopedBookmarkData(for: url)
        bookmarks.insert(bookmark, at: 0)
        selectedCategory = bookmark.displayCategory
        selectedBookmarkID = bookmark.id
        lastImportMessage = "Captured \(bookmark.displayTitle)"
        return bookmark
    }

    private func resolvedOpenURL(for bookmark: Bookmark) -> URL? {
        let rawLocation = bookmark.location.trimmingCharacters(in: .whitespacesAndNewlines)

        if bookmark.kind == .file {
            if let bookmarkData = bookmark.securityScopedBookmarkData,
               let url = resolveSecurityScopedBookmark(bookmarkData) {
                return url
            }

            if let url = URL(string: rawLocation), url.isFileURL {
                return url
            }

            let expandedPath = (rawLocation as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }

        if let url = URL(string: rawLocation), url.scheme != nil {
            return url
        }

        guard let encoded = rawLocation.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
            return nil
        }
        return URL(string: encoded)
    }

    private func securityScopedBookmarkData(for url: URL) -> Data? {
        guard url.isFileURL else { return nil }
        return try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    private func resolveSecurityScopedBookmark(_ data: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private func startSecurityScopeIfNeeded(for url: URL, bookmark: Bookmark) -> Bool {
        guard bookmark.securityScopedBookmarkData != nil else { return false }
        return url.startAccessingSecurityScopedResource()
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else {
            bookmarks = Bookmark.samples
            return
        }

        do {
            bookmarks = normalizeLegacyBookmarks(try JSONDecoder.roost.decode([Bookmark].self, from: data))
        } catch {
            logger.error("Failed to load bookmarks: \(error.localizedDescription, privacy: .public)")
            bookmarks = Bookmark.samples
        }
    }

    private func normalizeLegacyBookmarks(_ decoded: [Bookmark]) -> [Bookmark] {
        let existingIDs = Set(decoded.map(\.id))

        return decoded.compactMap { bookmark in
            if bookmark.kind == .text,
               bookmark.title == bookmark.location,
               bookmark.location == bookmark.summary,
               let referencedID = UUID(uuidString: bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)),
               existingIDs.contains(referencedID) {
                logger.info("Dropping internal drag ghost bookmark id=\(bookmark.id.uuidString, privacy: .public) referenced=\(referencedID.uuidString, privacy: .public)")
                return nil
            }

            var normalized = bookmark
            normalized.category = bookmark.displayCategory
            if normalized.kind == .file {
                normalized.title = Bookmark.friendlyFileTitle(for: normalized.location, fallback: normalized.title)
            }
            return normalized
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
