import SwiftUI

struct BucketWindowView: View {
    @EnvironmentObject private var store: BookmarkStore
    @Environment(\.openWindow) private var openWindow
    @State private var isTargeted = false
    @State private var catchAllText = ""
    @FocusState private var isInputFocused: Bool
    private let peach = Color(red: 1.0, green: 0.54, blue: 0.42)
    private let mint = Color(red: 0.28, green: 0.72, blue: 0.56)
    private let sky = Color(red: 0.36, green: 0.58, blue: 0.96)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hatch")
                        .font(.title2.weight(.bold))
                    Text("A little bag for links, notes, and useful clutter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(peach)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isTargeted ? sky.opacity(0.18) : Color.secondary.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isTargeted ? sky : Color.secondary.opacity(0.18), lineWidth: isTargeted ? 2 : 1)
                    }

                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "shippingbox.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(isTargeted ? sky : peach)

                    Text(isTargeted ? "Let it land" : store.lastImportMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 112)
            .scaleEffect(isTargeted ? 1.02 : 1)
            .animation(.snappy(duration: 0.18), value: isTargeted)

            HStack(spacing: 8) {
                TextField("Paste anything here", text: $catchAllText)
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
                    Label("Catch Clipboard", systemImage: "doc.on.clipboard")
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

        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                HatchAccentBackground(peach: peach, mint: mint, sky: sky)
            }
        }
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

private struct HatchAccentBackground: View {
    let peach: Color
    let mint: Color
    let sky: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                peach.opacity(0.14)
                mint.opacity(0.10)
                sky.opacity(0.10)
            }
            .frame(height: 5)

            Spacer()
        }
        .allowsHitTesting(false)
    }
}
