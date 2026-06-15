import AppKit
import SwiftUI
import WebKit

struct DetailView: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel

    var body: some View {
        if navigation.selection.isNotesDomain {
            if let note = noteStore.selectedNote {
                NoteEditorView(note: note)
                    .id(note.id)
            } else if let bookmark = store.selectedBookmark {
                BookmarkDetail(bookmark: bookmark)
            }
        } else if let bookmark = store.selectedBookmark {
            BookmarkDetail(bookmark: bookmark)
        }
    }
}

private struct BookmarkDetail: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var tagStore: TagStore
    let bookmark: Bookmark

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(bookmark.displayCategory.rawValue, systemImage: bookmark.displayCategory.symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.moss, in: Capsule())

                    Text(bookmark.displayTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                        .textSelection(.enabled)

                    Text(bookmark.secondaryLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: 10) {
                        DetailPinButton(isPinned: bookmark.isImportant) {
                            store.toggleImportant(bookmark)
                        }

                        if bookmark.kind == .file {
                            Button {
                                store.openInPreview(bookmark)
                            } label: {
                                Label("Preview", systemImage: "photo")
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.textSecondary)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }

                        Button {
                            store.open(bookmark)
                        } label: {
                            Label("Open", systemImage: "arrow.up.forward.app")
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.white)
                        .background(Theme.rose, in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Spacer()
                    }
                }

                TagEditorView(
                    tagIDs: bookmark.tagIDs,
                    onAdd: { tagID in store.addTag(tagID, to: bookmark.id) },
                    onRemove: { tagID in store.removeTag(tagID, from: bookmark.id) }
                )
                .environmentObject(tagStore)

                BookmarkNoteEditor(bookmark: bookmark)

                sections
            }
            .padding(26)
            .frame(maxWidth: 720, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(PaintedBackdrop())
    }

    @ViewBuilder
    private var sections: some View {
        if bookmark.kind == .file, let image = NSImage(contentsOfFile: bookmark.location) {
            DetailSection(title: "Preview") {
                Button {
                    store.openInPreview(bookmark)
                } label: {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Theme.cardStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Open in Preview")
                .onDrag {
                    NSItemProvider(object: URL(fileURLWithPath: bookmark.location) as NSURL)
                }

                Text("Click to open in Preview or drag the file out.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }
        } else if bookmark.kind == .file {
            DetailSection(title: "Preview") {
                Button {
                    store.openInPreview(bookmark)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Open this file in Preview")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 68)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .onDrag {
                    NSItemProvider(object: URL(fileURLWithPath: bookmark.location) as NSURL)
                }
            }
        }

        if bookmark.kind == .web, let previewURL = URL(string: bookmark.location) {
            DetailSection(title: "Viewer") {
                WebPreview(url: previewURL)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    }
            }
        }
    }
}

/// WKWebView that hands scroll events back to the enclosing SwiftUI
/// ScrollView, so hovering the preview doesn't trap scrolling inside the page.
private final class PreviewWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

private struct WebPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = PreviewWebView(frame: .zero, configuration: configuration)
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}

private struct DetailPinButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isPinned ? "Pinned" : "Pin", systemImage: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPinned ? Theme.gold : Theme.textSecondary)
        .background(isPinned ? Theme.gold.opacity(0.13) : Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isPinned ? Theme.gold.opacity(0.45) : Theme.cardStroke, lineWidth: 1)
        }
        .help(isPinned ? "Unpin" : "Pin")
    }
}

private struct BookmarkNoteEditor: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var tagStore: TagStore
    let bookmark: Bookmark
    @State private var noteText: String

    init(bookmark: Bookmark) {
        self.bookmark = bookmark
        _noteText = State(initialValue: bookmark.note)
    }

    var body: some View {
        DetailSection(title: "Note") {
            ZStack(alignment: .topLeading) {
                if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write a note about this item…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $noteText)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .onChange(of: noteText) { _, newValue in
                        store.updateNote(bookmark.id, note: newValue)
                        for tagID in tagStore.tagIDs(in: newValue) {
                            store.addTag(tagID, to: bookmark.id)
                        }
                    }
            }
            .padding(10)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            }
        }
        .onChange(of: bookmark.id) { _, _ in
            noteText = bookmark.note
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 4, tint: Theme.rose)
    }
}
