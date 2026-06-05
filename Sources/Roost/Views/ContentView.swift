import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: BookmarkStore
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 300)
        } content: {
            BookmarkListView()
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 560)
        } detail: {
            DetailView()
        }
        .background(Theme.paper)
        .navigationTitle("Roost")
        .searchable(text: $store.searchText, prompt: "Search Roost")
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
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.gold.opacity(0.85), lineWidth: 3)
                    .padding(14)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
    }
}
