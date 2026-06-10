import Foundation
import UniformTypeIdentifiers

enum BookmarkDropHandler {
    static let acceptedTypes: [UTType] = [.url, .fileURL, .plainText]

    static func handle(_ providers: [NSItemProvider], store: BookmarkStore) -> Bool {
        for provider in providers {
            // Use loadObject(ofClass: URL.self) for both web URLs (public.url) and
            // file URLs (public.file-url). This avoids the raw-Data path where
            // macOS includes a trailing newline/null that breaks URL(string:).
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    DispatchQueue.main.async {
                        if let url { store.add(url: url) }
                    }
                }
                return true
            }

            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                    DispatchQueue.main.async {
                        if let string = item as? String {
                            store.add(rawValue: string)
                        }
                    }
                }
                return true
            }
        }

        return false
    }
}
