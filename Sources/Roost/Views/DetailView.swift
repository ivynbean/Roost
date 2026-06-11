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
            } else {
                NotePlaceholderView()
            }
        } else if let bookmark = store.selectedBookmark {
            BookmarkDetail(bookmark: bookmark)
        } else {
            DetailPlaceholder()
        }
    }
}

private struct BookmarkDetail: View {
    @EnvironmentObject private var store: BookmarkStore
    let bookmark: Bookmark

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(bookmark.category.rawValue, systemImage: bookmark.category.symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.moss, in: Capsule())

                    Text(bookmark.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                        .textSelection(.enabled)

                    HStack(spacing: 10) {
                        Button {
                            store.toggleImportant(bookmark)
                        } label: {
                            Label(bookmark.isImportant ? "Flagged" : "Flag", systemImage: bookmark.isImportant ? "flag.fill" : "flag")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            store.open(bookmark)
                        } label: {
                            Label("Open", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                }

                sections
            }
            .padding(26)
            .frame(maxWidth: 760, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(PaintedBackdrop())
    }

    @ViewBuilder
    private var sections: some View {
            DetailSection(title: "Location") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbolName)
                        .foregroundStyle(Theme.rose)
                        .frame(width: 18)
                    Text(bookmark.location)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if bookmark.kind == .file, let image = NSImage(contentsOfFile: bookmark.location) {
                DetailSection(title: "Preview") {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Theme.ink.opacity(0.10), lineWidth: 1)
                        }
                }
            }

            if bookmark.kind == .web, let previewURL = URL(string: bookmark.location) {
                DetailSection(title: "Viewer") {
                    WebPreview(url: previewURL)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Theme.ink.opacity(0.10), lineWidth: 1)
                        }
                }
            }

            DetailSection(title: "Smart Bucket") {
                Picker("Smart Pile", selection: Binding(
                    get: { bookmark.category },
                    set: { store.move(bookmark, to: $0) }
                )) {
                    ForEach(BookmarkCategory.pileCases) { category in
                        Label(category.rawValue, systemImage: category.symbolName)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            DetailSection(title: "Notes") {
                TextEditor(text: Binding(
                    get: { bookmark.summary },
                    set: { store.updateSummary(bookmark.id, summary: $0) }
                ))
                .font(.callout)
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
            }
    }

    private var symbolName: String {
        switch bookmark.kind {
        case .web: "globe"
        case .file: "doc"
        case .text: "text.quote"
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

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 10, tint: Theme.rose)
    }
}

private struct DetailPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.blush.opacity(0.82))
                    .frame(width: 148, height: 112)
                    .rotationEffect(.degrees(-5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Theme.rose.opacity(0.30), lineWidth: 1)
                    }

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.cream.opacity(0.96))
                    .frame(width: 114, height: 84)
                    .overlay {
                        StarScatter()
                            .opacity(0.55)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.gold.opacity(0.50), lineWidth: 1)
                    }
                    .offset(x: 12, y: 24)
            }

            Text("Pick something from the pile")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Links, files, and notes you save in Roost appear here.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaintedBackdrop())
    }
}
