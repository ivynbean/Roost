import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        List(selection: $store.selectedCategory) {
            Section("Smart Piles") {
                ForEach(BookmarkCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.symbolName)
                        .badge(count(for: category))
                        .tag(category)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Smart Piles")
    }

    private func count(for category: BookmarkCategory) -> Int {
        if category == .inbox {
            return store.bookmarks.count
        }
        return store.bookmarks.filter { $0.category == category }.count
    }
}
