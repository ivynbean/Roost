import SwiftUI

struct BookmarkListView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        List(selection: $store.selectedBookmarkID) {
            ForEach(store.visibleBookmarks) { bookmark in
                BookmarkRow(bookmark: bookmark)
                    .tag(bookmark.id)
                    .contextMenu {
                        Button("Open") {
                            store.open(bookmark)
                        }

                        Menu("Move To") {
                            ForEach(BookmarkCategory.allCases) { category in
                                Button(category.rawValue) {
                                    store.move(bookmark, to: category)
                                }
                            }
                        }
                    }
            }
        }
        .navigationTitle(store.selectedCategory.rawValue)
        .overlay {
            if store.visibleBookmarks.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "tray", description: Text("Drop something into the bucket to save it."))
            }
        }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .lineLimit(1)

                Text(bookmark.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private var iconName: String {
        switch bookmark.kind {
        case .web: "globe"
        case .file: "doc"
        case .text: "text.quote"
        }
    }
}
