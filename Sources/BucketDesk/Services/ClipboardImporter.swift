import AppKit
import Foundation

struct ClipboardImporter {
    func captureFromClipboard(into store: BookmarkStore) {
        let pasteboard = NSPasteboard.general

        if let url = pasteboard.bucketDeskURL {
            store.add(url: url)
            return
        }

        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.add(rawValue: string)
            return
        }

        store.lastImportMessage = "Clipboard is empty."
    }
}

private extension NSPasteboard {
    var bucketDeskURL: URL? {
        if let urls = readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first {
            return url
        }

        if let string = string(forType: .fileURL),
           let url = URL(string: string) {
            return url
        }

        if let string = string(forType: .URL),
           let url = URL(string: string) {
            return url
        }

        return nil
    }
}
