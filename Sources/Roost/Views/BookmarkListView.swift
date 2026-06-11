import SwiftUI

struct BookmarkListView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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

                        Button("Delete", role: .destructive) {
                            store.delete(bookmark)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    @EnvironmentObject private var noteStore: NoteStore
    let bookmark: Bookmark
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            noteStore.selectedNoteID = nil
            store.selectedBookmarkID = bookmark.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(iconTint)

                        Text(bookmark.displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        if bookmark.isImportant {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                    }

                    Text(bookmark.secondaryLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(shortTime(bookmark.createdAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)

                        if bookmark.displayCategory != .readLater {
                            Text("•")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accentColor)

                            Text(bookmark.displayCategory.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 10)

                if showsActions {
                    HStack(spacing: 10) {
                        BookmarkRowGlyphAction(symbolName: "arrow.up.forward", help: "Open") {
                            store.open(bookmark)
                        }
                        BookmarkRowGlyphAction(symbolName: "doc.on.doc", help: "Copy link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(bookmark.location, forType: .string)
                        }
                        BookmarkRowGlyphAction(
                            symbolName: bookmark.isImportant ? "pin.fill" : "pin",
                            isActive: bookmark.isImportant,
                            help: bookmark.isImportant ? "Unpin" : "Pin"
                        ) {
                            store.toggleImportant(bookmark)
                        }
                        BookmarkRowGlyphAction(symbolName: "trash", tint: Theme.destructive, help: "Delete") {
                            store.delete(bookmark)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.card.opacity(isSelected ? 0.96 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var showsActions: Bool {
        isHovered
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

    private var accentColor: Color {
        switch bookmark.displayCategory {
        case .work: Theme.rose
        case .code: Theme.lavender
        case .design: Theme.gold
        case .docs, .screenshots: Theme.wood
        default: iconTint
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private struct BookmarkRowGlyphAction: View {
    let symbolName: String
    var isActive = false
    var tint: Color? = nil
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint ?? (isActive ? Theme.gold : Theme.textTertiary))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct EmptyPileView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.night)
                    .rotationEffect(.degrees(-2))
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .frame(width: 118, height: 92)

            Text("Nothing tucked away yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Paste, drop, or type anything into Roost to save it.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(28)
        .paperPanel(cornerRadius: 4, tint: Theme.grass)
    }
}
