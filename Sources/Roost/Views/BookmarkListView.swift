import SwiftUI

struct BookmarkListView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(store.visibleBookmarks) { bookmark in
                    BookmarkRow(
                        bookmark: bookmark,
                        isSelected: bookmark.id == store.selectedBookmarkID
                    )
                    .onDrag {
                        NSItemProvider(object: bookmark.id.uuidString as NSString)
                    }
                    .contextMenu {
                        Button("Open") {
                            store.open(bookmark)
                        }

                        Menu("Move To") {
                            ForEach(BookmarkCategory.pileCases) { category in
                                Button(category.rawValue) {
                                    store.move(bookmark, to: category)
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(PaintedBackdrop())
        .navigationTitle(store.selectedCategory.rawValue)
        .overlay {
            if store.visibleBookmarks.isEmpty {
                EmptyPileView()
            }
        }
    }
}

private struct BookmarkRow: View {
    @EnvironmentObject private var store: BookmarkStore
    let bookmark: Bookmark
    let isSelected: Bool

    var body: some View {
        Button {
            store.selectedBookmarkID = bookmark.id
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconTint.opacity(isSelected ? 0.26 : 0.18))
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconTint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Theme.ink)
                        .lineLimit(1)

                    Text(bookmark.location)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Theme.ink.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Button {
                    store.toggleImportant(bookmark)
                } label: {
                    Image(systemName: bookmark.isImportant ? "flag.fill" : "flag")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(bookmark.isImportant ? Theme.pink : (isSelected ? Color.white.opacity(0.62) : Theme.ink.opacity(0.34)))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(bookmark.isImportant ? "Unflag" : "Flag important")

                Text(bookmark.category.rawValue)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.80) : Theme.moss)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.white.opacity(0.14) : Theme.grass.opacity(0.16), in: Capsule())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.pink : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch bookmark.kind {
        case .web: "globe"
        case .file: "doc"
        case .text: "text.quote"
        }
    }

    private var iconTint: Color {
        switch bookmark.kind {
        case .web: Theme.lavender
        case .file: Theme.wood
        case .text: Theme.rose
        }
    }
}

private struct EmptyPileView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.night)
                    .rotationEffect(.degrees(-2))
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .frame(width: 118, height: 92)

            Text("Nothing tucked away yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Paste, drop, or type anything into Roost to save it.")
                .font(.callout)
                .foregroundStyle(Theme.ink.opacity(0.66))
        }
        .padding(28)
        .paperPanel(cornerRadius: 12, tint: Theme.grass, fillOpacity: 0.9)
    }
}
