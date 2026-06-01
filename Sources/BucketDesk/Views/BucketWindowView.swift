import SwiftUI

struct BucketWindowView: View {
    @EnvironmentObject private var store: BookmarkStore
    @Environment(\.openWindow) private var openWindow
    @State private var isTargeted = false
    @State private var catchAllText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 6)

            ZStack {
                Circle()
                    .fill(isTargeted ? Color.accentColor.opacity(0.24) : Color.secondary.opacity(0.12))
                    .frame(width: 92, height: 92)

                Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            }
            .scaleEffect(isTargeted ? 1.06 : 1)
            .animation(.snappy(duration: 0.18), value: isTargeted)

            VStack(spacing: 4) {
                Text(isTargeted ? "Drop it here" : "BucketDesk")
                    .font(.title3.weight(.semibold))

                Text(store.lastImportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 34)
            }

            HStack(spacing: 8) {
                TextField("Paste a link, file path, or random note", text: $catchAllText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit(captureTypedText)

                Button {
                    captureTypedText()
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .disabled(catchAllText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 10) {
                Button {
                    store.captureClipboard()
                } label: {
                    Label("Grab Clipboard", systemImage: "doc.on.clipboard")
                }

                Button {
                    openWindow(id: "library")
                } label: {
                    Label("Library", systemImage: "sidebar.left")
                }

                Button {
                    store.autoSortAll()
                } label: {
                    Label("Sort", systemImage: "sparkles")
                }
            }

            Spacer(minLength: 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onAppear {
            isInputFocused = true
        }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
        .onPasteCommand(of: [.url, .fileURL, .plainText]) { providers in
            _ = BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private func captureTypedText() {
        let trimmed = catchAllText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.add(rawValue: trimmed)
        catchAllText = ""
        isInputFocused = true
    }
}
