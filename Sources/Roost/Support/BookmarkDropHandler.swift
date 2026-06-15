import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

enum BookmarkDropHandler {
    // .item is the root type: the catch-all surfaces accept every drag, and
    // the handler sorts out what's actually readable. Browsers vary wildly in
    // which flavors they declare, so filtering up front loses real drops.
    static let acceptedTypes: [UTType] = [.url, .fileURL, .utf8PlainText, .plainText, .text, .item]

    private static let logger = Logger(subsystem: "com.ivynbean.Roost", category: "drop")

    /// Captures every dropped item into the store. `onCapture` fires once per
    /// saved bookmark (on the main queue), so callers can chain follow-up
    /// work such as attaching the bookmark to a note.
    @discardableResult
    static func handle(
        _ providers: [NSItemProvider],
        store: BookmarkStore,
        onCapture: ((Bookmark) -> Void)? = nil
    ) -> Bool {
        if captureURLsFromDragPasteboard(store: store, onCapture: onCapture) {
            return true
        }

        var handled = false

        for provider in providers {
            logger.info("Drop provider types=[\(provider.registeredTypeIdentifiers.joined(separator: ", "), privacy: .public)]")
            if capture(provider, store: store, onCapture: onCapture) {
                handled = true
            } else {
                logger.error("No readable payload in drop provider")
            }
        }

        // Last resort: browsers using legacy pasteboard flavors can produce
        // providers with no readable payload. The drag pasteboard is still
        // live during the drop, so read the URL or text straight off it.
        if !handled {
            handled = captureFromDragPasteboard(store: store, onCapture: onCapture)
        }

        return handled
    }

    private static func captureURLsFromDragPasteboard(
        store: BookmarkStore,
        onCapture: ((Bookmark) -> Void)?
    ) -> Bool {
        let pasteboard = NSPasteboard(name: .drag)

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            logger.info("Drop recovered \(urls.count) URL(s) from the live drag pasteboard")
            for url in urls {
                deliver(url: url, error: nil, store: store, onCapture: onCapture)
            }
            return true
        }

        for type in [NSPasteboard.PasteboardType.URL, .fileURL, .string] {
            if let string = pasteboard.string(forType: type).map(sanitize),
               let url = urlFromDroppedString(string) {
                logger.info("Drop recovered URL from live drag pasteboard type=\(type.rawValue, privacy: .public)")
                deliver(url: url, error: nil, store: store, onCapture: onCapture)
                return true
            }

            if let data = pasteboard.data(forType: type),
               let url = url(fromLoadedItem: data as NSData) {
                logger.info("Drop recovered URL data from live drag pasteboard type=\(type.rawValue, privacy: .public)")
                deliver(url: url, error: nil, store: store, onCapture: onCapture)
                return true
            }
        }

        guard let string = pasteboard.string(forType: .string).map(sanitize),
              let url = urlFromDroppedString(string) else {
            return false
        }

        logger.info("Drop recovered URL text from the live drag pasteboard")
        deliver(url: url, error: nil, store: store, onCapture: onCapture)
        return true
    }

    private static func captureFromDragPasteboard(
        store: BookmarkStore,
        onCapture: ((Bookmark) -> Void)?
    ) -> Bool {
        let pasteboard = NSPasteboard(name: .drag)

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            logger.info("Drop recovered \(urls.count) URL(s) from the drag pasteboard")
            for url in urls {
                deliver(url: url, error: nil, store: store, onCapture: onCapture)
            }
            return true
        }

        if let string = pasteboard.string(forType: .string), !sanitize(string).isEmpty {
            logger.info("Drop recovered text from the drag pasteboard")
            deliver(rawValue: sanitize(string), error: nil, store: store, onCapture: onCapture)
            return true
        }

        logger.error("Drag pasteboard had no readable URL or text either; types=[\(pasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "", privacy: .public)]")
        return false
    }

    private static func capture(
        _ provider: NSItemProvider,
        store: BookmarkStore,
        onCapture: ((Bookmark) -> Void)?
    ) -> Bool {
        // 1) URL flavors (public.url / public.file-url), decoded defensively.
        // Browsers are sloppy here: Chromium-family apps deliver the URL as
        // raw bytes with a trailing NUL, and letting Foundation decode that
        // via loadObject(ofClass: URL.self) yields a half-initialized NSURL
        // that crashes on first use. loadItem + manual decoding handles
        // NSURL, Data, and String payloads safely.
        if loadRawURL(from: provider, store: store, onCapture: onCapture) {
            return true
        }

        // 2) Plain text (loose notes, or URLs dragged as text). Handled
        // before the URL-object fallback because Foundation's text-to-NSURL
        // decode percent-encodes stray whitespace into the URL.
        if provider.canLoadObject(ofClass: NSString.self) {
            _ = provider.loadObject(ofClass: NSString.self) { item, error in
                deliver(rawValue: (item as? String).map(sanitize), error: error, store: store, onCapture: onCapture)
            }
            return true
        }

        // 3) Anything that at least conforms to text, delivered as raw bytes.
        for identifier in provider.registeredTypeIdentifiers
        where UTType(identifier)?.conforms(to: .text) == true {
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, error in
                deliver(rawValue: string(fromLoadedItem: item), error: error, store: store, onCapture: onCapture)
            }
            return true
        }

        // 4) Last resort: providers that only expose a URL through the
        // object interface.
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                deliver(url: url, error: error, store: store, onCapture: onCapture)
            }
            return true
        }

        return false
    }

    @discardableResult
    private static func loadRawURL(
        from provider: NSItemProvider,
        store: BookmarkStore,
        onCapture: ((Bookmark) -> Void)?
    ) -> Bool {
        for identifier in [UTType.url.identifier, UTType.fileURL.identifier]
        where provider.hasItemConformingToTypeIdentifier(identifier) {
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, error in
                deliver(url: url(fromLoadedItem: item), error: error, store: store, onCapture: onCapture)
            }
            return true
        }
        return false
    }

    private static func deliver(
        url: URL? = nil,
        rawValue: String? = nil,
        error: Error?,
        store: BookmarkStore,
        onCapture: ((Bookmark) -> Void)?
    ) {
        DispatchQueue.main.async {
            if let error {
                logger.error("Drop payload failed to load: \(error.localizedDescription, privacy: .public)")
            }

            let bookmark: Bookmark?
            if let url {
                bookmark = store.add(url: cleaned(url))
            } else if let rawValue {
                bookmark = store.add(rawValue: rawValue)
            } else {
                bookmark = nil
            }

            guard let bookmark else { return }
            logger.info("Drop captured bookmark id=\(bookmark.id.uuidString, privacy: .public)")
            onCapture?(bookmark)
        }
    }

    private static func url(fromLoadedItem item: (any NSSecureCoding)?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let nsURL = item as? NSURL {
            return nsURL as URL
        }
        if let data = item as? Data {
            // Strip the trailing null bytes some sources append before decoding.
            let trimmed = Data(data.reversed().drop { $0 == 0 }.reversed())
            if let url = URL(dataRepresentation: trimmed, relativeTo: nil) {
                return url
            }
            if let string = String(data: trimmed, encoding: .utf8) {
                return URL(string: sanitize(string))
            }
            return nil
        }
        if let string = item as? String {
            return URL(string: sanitize(string))
        }
        return nil
    }

    private static func urlFromDroppedString(_ string: String) -> URL? {
        if let url = URL(string: string),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "file"].contains(scheme) {
            return url
        }

        let expandedPath = NSString(string: string).expandingTildeInPath
        if expandedPath.hasPrefix("/"), FileManager.default.fileExists(atPath: expandedPath) {
            return URL(fileURLWithPath: expandedPath)
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              match.range.location != NSNotFound,
              let range = Range(match.range, in: string) else {
            return nil
        }

        let candidate = String(string[range])
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "file"].contains(scheme) else {
            return nil
        }
        return url
    }

    private static func string(fromLoadedItem item: (any NSSecureCoding)?) -> String? {
        if let string = item as? String {
            return sanitize(string)
        }
        if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
            return sanitize(string)
        }
        return nil
    }

    private static func sanitize(_ string: String) -> String {
        string.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
    }

    /// Some flavors percent-encode stray trailing whitespace into the URL
    /// itself (e.g. a dragged "https://…\n" arrives as "https://…%0A").
    private static func cleaned(_ url: URL) -> URL {
        var string = url.absoluteString
        let encodedWhitespace = ["%0A", "%0D", "%09", "%20"]
        var changed = false
        while let suffix = encodedWhitespace.first(where: { string.hasSuffix($0) }) {
            string.removeLast(suffix.count)
            changed = true
        }
        guard changed, let cleanedURL = URL(string: string) else { return url }
        return cleanedURL
    }
}
