import Foundation
import UniformTypeIdentifiers

enum BookmarkDropHandler {
    static let acceptedTypes: [UTType] = [.url, .fileURL, .plainText]

    static func handle(_ providers: [NSItemProvider], store: BookmarkStore) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                loadURL(from: provider, type: .url, store: store)
                return true
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadURL(from: provider, type: .fileURL, store: store)
                return true
            }

            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { item, _ in
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

    private static func loadURL(from provider: NSItemProvider, type: UTType, store: BookmarkStore) {
        provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                if let data = item as? Data,
                   let value = String(data: data, encoding: .utf8),
                   let url = URL(string: value) {
                    store.add(url: url)
                } else if let url = item as? URL {
                    store.add(url: url)
                }
            }
        }
    }
}
