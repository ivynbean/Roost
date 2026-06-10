import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        VStack(spacing: 0) {
            SidebarLogo()
                .padding(.top, 24)
                .padding(.bottom, 18)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Collections")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink.opacity(0.68))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                    ForEach(BookmarkCategory.pileCases) { category in
                        SidebarRow(
                            category: category,
                            count: count(for: category),
                            isSelected: category == store.selectedCategory,
                            store: store
                        ) {
                            store.selectCategory(category)
                        }
                    }
                }
                .padding(.leading, 28)
                .padding(.trailing, 14)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.visible)
        }
        .background(Theme.sidebar)
        .navigationTitle("piles")
        .onAppear {
            if store.selectedCategory == .important {
                store.selectCategory(.inbox)
            }
        }
    }

    private func count(for category: BookmarkCategory) -> Int {
        if category == .inbox {
            return store.bookmarks.count
        }
        return store.bookmarks.filter { $0.category == category }.count
    }
}

private struct SidebarLogo: View {
    var body: some View {
        VStack(spacing: 6) {
            if let logoImage = RoostImage.nsImage() {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .shadow(color: Theme.wood.opacity(0.10), radius: 7, y: 3)
            } else {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 96, height: 96)
            }

            Text("Roost")
                .font(Theme.logoFont(size: 34))
                .foregroundStyle(Theme.pink)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SidebarRow: View {
    let category: BookmarkCategory
    let count: Int
    let isSelected: Bool
    let store: BookmarkStore
    let action: () -> Void
    @State private var isTargeted = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.pink : Theme.ink.opacity(0.72))
                    .frame(width: 22)

                Text(category.rawValue)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.pink : Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.pink.opacity(0.82) : Theme.ink.opacity(0.52))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowFill)
            }
        }
        .buttonStyle(.plain)
        .onDrop(of: [.plainText], isTargeted: $isTargeted) { providers in
            moveDroppedBookmark(from: providers)
        }
    }

    private var rowFill: Color {
        if isTargeted {
            return Theme.gold.opacity(0.22)
        }

        return isSelected ? Theme.selected.opacity(0.10) : Color.clear
    }

    private func moveDroppedBookmark(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let rawID = item as? String,
                  let id = UUID(uuidString: rawID) else { return }

            DispatchQueue.main.async {
                store.move(bookmarkID: id, to: category)
            }
        }

        return true
    }
}
