import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var projectBeingRenamed: Project?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            SidebarLogo()
                .padding(.top, 24)
                .padding(.bottom, 18)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("Overview")

                    SidebarRow(
                        title: "Today",
                        symbolName: "sun.max",
                        count: noteStore.noteCount(for: .today),
                        isSelected: navigation.selection == .today
                    ) {
                        navigation.selection = .today
                    }

                    SidebarRow(
                        title: "On the Agenda",
                        symbolName: "star",
                        count: noteStore.noteCount(for: .agenda),
                        isSelected: navigation.selection == .agenda
                    ) {
                        navigation.selection = .agenda
                    }

                    SidebarRow(
                        title: "All Notes",
                        symbolName: "note.text",
                        count: noteStore.noteCount(for: .allNotes),
                        isSelected: navigation.selection == .allNotes
                    ) {
                        navigation.selection = .allNotes
                    }

                    HStack {
                        sectionHeader("Projects")
                        Spacer()
                        Button {
                            newProjectName = ""
                            isAddingProject = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("New Project")
                        .padding(.trailing, 14)
                    }
                    .padding(.top, 14)

                    ForEach(noteStore.projects) { project in
                        SidebarRow(
                            title: project.name,
                            symbolName: project.symbolName,
                            count: noteStore.notes(inProject: project.id).count,
                            isSelected: navigation.selection == .project(project.id),
                            tint: Theme.projectColor(project.colorIndex)
                        ) {
                            navigation.selection = .project(project.id)
                        }
                        .contextMenu {
                            Button("Rename…") {
                                renameText = project.name
                                projectBeingRenamed = project
                            }
                            Button("Delete", role: .destructive) {
                                if navigation.selection == .project(project.id) {
                                    navigation.selection = .allNotes
                                }
                                noteStore.deleteProject(project.id)
                            }
                        }
                    }

                    sectionHeader("Collections")
                        .padding(.top, 14)

                    ForEach(BookmarkCategory.pileCases) { category in
                        CollectionRow(
                            category: category,
                            count: count(for: category),
                            isSelected: navigation.selection == .collection(category),
                            store: store
                        ) {
                            navigation.selection = .collection(category)
                            store.selectedCategory = category
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
        .navigationTitle("Roost")
        .alert("New Project", isPresented: $isAddingProject) {
            TextField("Project name", text: $newProjectName)
            Button("Create") {
                let project = noteStore.addProject(name: newProjectName)
                navigation.selection = .project(project.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Group your notes by what you're working on.")
        }
        .alert("Rename Project", isPresented: Binding(
            get: { projectBeingRenamed != nil },
            set: { if !$0 { projectBeingRenamed = nil } }
        )) {
            TextField("Project name", text: $renameText)
            Button("Rename") {
                if let project = projectBeingRenamed {
                    noteStore.renameProject(project.id, to: renameText)
                }
                projectBeingRenamed = nil
            }
            Button("Cancel", role: .cancel) {
                projectBeingRenamed = nil
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .kerning(0.8)
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
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
                    .frame(width: 72, height: 72)
                    .shadow(color: Theme.wood.opacity(0.10), radius: 7, y: 3)
            } else {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 72, height: 72)
            }

            Text("Roost")
                .font(Theme.logoFont(size: 28))
                .foregroundStyle(Theme.pink)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SidebarRow: View {
    let title: String
    let symbolName: String
    let count: Int
    let isSelected: Bool
    var tint: Color = Theme.pink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : tint)
                    .frame(width: 22)

                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? tint : Color.white)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : Theme.ink.opacity(0.45), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? tint : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CollectionRow: View {
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
                    .foregroundStyle(isSelected ? Color.white : Theme.moss)
                    .frame(width: 22)

                Text(category.rawValue)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? Theme.pink : Color.white)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : Theme.ink.opacity(0.45), in: Capsule())
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
            return Theme.gold.opacity(0.35)
        }

        return isSelected ? Theme.pink : Color.clear
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
