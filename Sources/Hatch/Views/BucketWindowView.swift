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
            ZStack {
                Theme.paper
                LinearGradient(
                    colors: [Theme.paper, Theme.cream.opacity(0.86), Theme.blush.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
                Text("Stash")
                    .font(Theme.logoFont(size: 30))
                    .foregroundStyle(Theme.pink)
                Text("Capture links, files, and notes")
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.64))
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isTargeted ? Theme.night.opacity(0.96) : Theme.ink.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isTargeted ? Theme.gold : Theme.wood.opacity(0.18), lineWidth: isTargeted ? 2 : 1)
                }

            HStack(spacing: 14) {
                Image(systemName: isTargeted ? "sparkles" : "tray.and.arrow.down")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isTargeted ? Theme.gold : Theme.paper.opacity(0.90))
                    .symbolEffect(.bounce, value: isTargeted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isTargeted ? "Drop to capture" : "Drop anything here")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.paper)
                    Text(store.lastImportMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.paper.opacity(0.68))
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
                .textFieldStyle(.roundedBorder)
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
            }
            .buttonStyle(.borderedProminent)
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
            if let logoImage = HatchImage.nsImage() {
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
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.wood.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Theme.ink.opacity(0.10), radius: 8, y: 4)
        .accessibilityLabel("Stash logo")
    }
}
