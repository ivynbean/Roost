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
            ZStack {
                Theme.sidebar
                StarScatter().opacity(0.16)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(colors: [Theme.moss.opacity(0.36), Theme.rose.opacity(0.34), Theme.gold.opacity(0.30)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private func catchBar(showText: Bool, showClipboardText: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isTargeted ? Theme.blush.opacity(0.72) : Theme.grass.opacity(0.18))
                Image(systemName: isTargeted ? "sparkles" : "tray.and.arrow.down")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isTargeted ? Theme.pink : Theme.moss)
            }
            .frame(width: 40, height: 40)
            .symbolEffect(.bounce, value: isTargeted)

            if showText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Save")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.pink)
                    Text(store.lastImportMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.ink.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(width: 240, alignment: .leading)
            }

            TextField("Paste any URL, file path, or note", text: $newBookmarkText)
                .textFieldStyle(.roundedBorder)
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
            }
            .buttonStyle(.borderedProminent)
            .help("Add")
            .disabled(newBookmarkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addTypedBookmark() {
        store.add(rawValue: newBookmarkText)
        newBookmarkText = ""
    }

}
