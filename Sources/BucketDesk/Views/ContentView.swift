import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: BookmarkStore
    @State private var newBookmarkText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            BookmarkListView()
                .searchable(text: $store.searchText, prompt: "Search bucket")
        } detail: {
            DetailView()
        }
        .navigationTitle("BucketDesk")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.autoSortAll()
                } label: {
                    Label("Auto Sort", systemImage: "sparkles")
                }

                Button(role: .destructive) {
                    store.deleteSelected()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(store.selectedBookmark == nil)
            }
        }
        .safeAreaInset(edge: .bottom) {
            DropBucketView(newBookmarkText: $newBookmarkText)
                .environmentObject(store)
        }
    }
}
