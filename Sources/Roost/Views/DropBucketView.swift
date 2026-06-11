import SwiftUI
import UniformTypeIdentifiers

struct DropBucketView: View {
    @EnvironmentObject private var store: BookmarkStore
    @Binding var newBookmarkText: String
    @State private var isTargeted = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            catchBar(showText: true, showClipboardText: true)
            catchBar(showText: false, showClipboardText: false)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            Theme.sidebar
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)
        }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private func catchBar(showText: Bool, showClipboardText: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isTargeted ? Theme.field : Theme.card)
                Image(systemName: isTargeted ? "sparkles" : "tray.and.arrow.down")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isTargeted ? Theme.gold : Theme.textTertiary)
            }
            .frame(width: 40, height: 40)
            .symbolEffect(.bounce, value: isTargeted)

            if showText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Save")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.lastImportMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 240, alignment: .leading)
            }

            TextField("Paste any URL, file path, or note", text: $newBookmarkText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .onSubmit(addTypedBookmark)
                .frame(minWidth: showText ? 260 : 180)
                .layoutPriority(1)

            Button {
                store.captureClipboard()
            } label: {
                if showClipboardText {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                } else {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                        .labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.bordered)
            .help("Save Clipboard")

            Button {
                addTypedBookmark()
            } label: {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .help("Add")
            .disabled(newBookmarkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addTypedBookmark() {
        store.add(rawValue: newBookmarkText)
        newBookmarkText = ""
    }

}
