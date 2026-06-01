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
                .searchable(text: $store.searchText, prompt: "Search Hatch")
        } detail: {
            DetailView()
        }
        .navigationTitle("Hatch")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.autoSortAll()
                } label: {
                    Label("Tidy Up", systemImage: "sparkles")
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
