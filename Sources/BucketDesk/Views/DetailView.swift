import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        if let bookmark = store.selectedBookmark {
            BookmarkDetail(bookmark: bookmark)
        } else {
            ContentUnavailableView("Select a bookmark", systemImage: "bookmark", description: Text("Captured links, files, and notes appear here."))
        }
    }
}

private struct BookmarkDetail: View {
    @EnvironmentObject private var store: BookmarkStore
    let bookmark: Bookmark

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(bookmark.category.rawValue, systemImage: bookmark.category.symbolName)
                        .foregroundStyle(.secondary)

                    Text(bookmark.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                Spacer()

                Button {
                    store.open(bookmark)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                Text(bookmark.location)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sort")
                    .font(.headline)
                Picker("Bucket", selection: Binding(
                    get: { bookmark.category },
                    set: { store.move(bookmark, to: $0) }
                )) {
                    ForEach(BookmarkCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.symbolName)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                Text(bookmark.summary.isEmpty ? "No summary yet." : bookmark.summary)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(24)
    }
}
