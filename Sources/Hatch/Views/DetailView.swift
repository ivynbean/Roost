import SwiftUI
import WebKit

struct DetailView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        if let bookmark = store.selectedBookmark {
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(bookmark.category.rawValue, systemImage: bookmark.category.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.moss)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.grass.opacity(0.16), in: Capsule())

                    Text(bookmark.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                Spacer()

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
            }

            DetailSection(title: "Location") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbolName)
                        .foregroundStyle(Theme.rose)
                        .frame(width: 18)
                    Text(bookmark.location)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(Theme.ink.opacity(0.68))
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
                Text(bookmark.summary.isEmpty ? "No summary yet." : bookmark.summary)
                    .foregroundStyle(Theme.ink.opacity(0.68))
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PaintedBackdrop())
    }

    private var symbolName: String {
        switch bookmark.kind {
        case .web: "globe"
        case .file: "doc"
        case .text: "text.quote"
        }
    }
}

private struct WebPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
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
                .foregroundStyle(Theme.ink)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 10, tint: Theme.rose, fillOpacity: 0.72)
    }
}

private struct DetailPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.wood.opacity(0.85))
                    .frame(width: 148, height: 112)
                    .rotationEffect(.degrees(-5))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.night)
                    .frame(width: 114, height: 84)
                    .overlay {
                        StarScatter()
                            .opacity(0.95)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .offset(x: 12, y: 24)
            }

            Text("Pick something from the pile")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Links, files, and notes you save in Stash appear here.")
                .font(.callout)
                .foregroundStyle(Theme.ink.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaintedBackdrop())
    }
}
