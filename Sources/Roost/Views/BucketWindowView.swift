import SwiftUI

struct BucketWindowView: View {
    @EnvironmentObject private var store: BookmarkStore
    @Environment(\.openWindow) private var openWindow
    @State private var isTargeted = false
    @State private var catchAllText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            header
            dropZone
            inputBar
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Theme.paper
        }
        .contentShape(Rectangle())
        .onAppear { isInputFocused = true }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
        .onPasteCommand(of: [.url, .fileURL, .plainText]) { providers in
            _ = BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppLogoMark()

            VStack(alignment: .leading, spacing: 2) {
                Text("Roost")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Capture links, files, and notes")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                openWindow(id: "library")
            } label: {
                Label("Library", systemImage: "sidebar.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Library")
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isTargeted ? Theme.field : Theme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isTargeted ? Theme.gold : Theme.cardStroke, lineWidth: isTargeted ? 2 : 1)
                }

            HStack(spacing: 14) {
                Image(systemName: isTargeted ? "sparkles" : "tray.and.arrow.down")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isTargeted ? Theme.gold : Theme.textTertiary)
                    .symbolEffect(.bounce, value: isTargeted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isTargeted ? "Drop to capture" : "Drop anything here")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.lastImportMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 92)
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private var inputBar: some View {
        ViewThatFits(in: .horizontal) {
            inputRow(showClipboardText: true)
            inputRow(showClipboardText: false)
        }
    }

    private func inputRow(showClipboardText: Bool) -> some View {
        HStack(spacing: 8) {
            TextField("Paste a URL, path, or note", text: $catchAllText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .focused($isInputFocused)
                .onSubmit(captureTypedText)
                .frame(minWidth: 180)
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
                captureTypedText()
            } label: {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .disabled(catchAllText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Add")
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

private struct AppLogoMark: View {
    var body: some View {
        Group {
            if let logoImage = RoostImage.nsImage() {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .frame(width: 52, height: 52)
        .padding(5)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Theme.wood.opacity(0.16), lineWidth: 1)
        }
        .accessibilityLabel("Roost logo")
    }
}
