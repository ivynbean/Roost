import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } content: {
            Group {
                if navigation.selection.isNotesDomain {
                    NotesListView()
                        .searchable(text: $noteStore.searchText, prompt: "Search notes")
                } else {
                    BookmarkListView()
                        .searchable(text: $store.searchText, prompt: "Search Roost")
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 380)
            .toolbarBackground(Theme.paper, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
        } detail: {
            DetailView()
                .frame(minWidth: 320)
                .toolbarBackground(Theme.paper, for: .windowToolbar)
                .toolbarBackground(.visible, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Theme.paper)
        .navigationTitle("Roost")
        .toolbar {
            if !navigation.selection.isNotesDomain {
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
