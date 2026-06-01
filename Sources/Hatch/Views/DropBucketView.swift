import SwiftUI
import UniformTypeIdentifiers

struct DropBucketView: View {
    @EnvironmentObject private var store: BookmarkStore
    @Binding var newBookmarkText: String
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.title2)
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Hatch Catch Bar")
                    .font(.headline)
                Text(store.lastImportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("Paste any URL, file path, or note", text: $newBookmarkText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTypedBookmark)

            Button {
                store.captureClipboard()
            } label: {
                Label("Catch Clipboard", systemImage: "doc.on.clipboard")
            }

            Button {
                addTypedBookmark()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .disabled(newBookmarkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private func addTypedBookmark() {
        store.add(rawValue: newBookmarkText)
        newBookmarkText = ""
    }

}
