import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var tagStore: TagStore
    @EnvironmentObject private var navigation: NavigationModel
    @State private var isAddingProject = false
    @State private var newProjectParentID: UUID?
    @State private var newProjectName = ""
    @State private var expandedProjectIDs: Set<UUID> = []
    @AppStorage("roost.sidebar.projectsExpanded") private var projectsExpanded = true
    @AppStorage("roost.sidebar.tagsExpanded") private var tagsExpanded = true
    @AppStorage("roost.sidebar.collectionsExpanded") private var collectionsExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            SidebarLogo()
                .padding(.top, 14)
                .padding(.bottom, 10)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        title: "Today",
                        symbolName: "calendar",
                        count: todayCount,
                        isSelected: navigation.selection == .today
                    ) {
                        navigation.selection = .today
                    }

                    SidebarRow(
                        title: "On the Agenda",
                        symbolName: "pin",
                        count: noteStore.noteCount(for: .agenda),
                        isSelected: navigation.selection == .agenda
                    ) {
                        navigation.selection = .agenda
                    }

                    SidebarRow(
                        title: "Tasks",
                        symbolName: "checkmark.circle",
                        count: noteStore.noteCount(for: .tasks),
                        isSelected: navigation.selection == .tasks
                    ) {
                        navigation.selection = .tasks
                    }

                    SidebarRow(
                        title: "All Notes",
                        symbolName: "note.text",
                        count: noteStore.noteCount(for: .allNotes),
                        isSelected: navigation.selection == .allNotes
                    ) {
                        navigation.selection = .allNotes
                    }

                    Divider()
                        .overlay(Theme.divider)
                        .padding(.vertical, 7)
                        .padding(.trailing, 8)

                    CollectionRow(
                        category: .screenshots,
                        count: count(for: .screenshots),
                        isSelected: navigation.selection == .collection(.screenshots),
                        store: store
                    ) {
                        navigation.selection = .collection(.screenshots)
                        store.selectedCategory = .screenshots
                    }

                    Divider()
                        .overlay(Theme.divider)
                        .padding(.vertical, 7)
                        .padding(.trailing, 8)

                    CollapsibleHeader(title: "Projects", isExpanded: $projectsExpanded) {
                        startAddingProject(parentID: nil)
                    }

                    if projectsExpanded {
                        ForEach(noteStore.childProjects(of: nil)) { project in
                            ProjectSidebarBranch(
                                project: project,
                                depth: 0,
                                expandedProjectIDs: $expandedProjectIDs,
                                onAddChild: startAddingProject
                            )
                        }
                    }

                    if !tagStore.tags.isEmpty {
                        CollapsibleHeader(title: "Tags", isExpanded: $tagsExpanded)
                            .padding(.top, 8)
                    }

                    if tagsExpanded {
                        ForEach(tagStore.tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { tag in
                            TagSidebarRow(
                                tag: tag,
                                count: tagCount(for: tag.id),
                                isSelected: navigation.selection == .tag(tag.id),
                                onRename: { newName in
                                    tagStore.rename(tag.id, to: newName)
                                }
                            ) {
                                navigation.selection = .tag(tag.id)
                            }
                        }
                    }

                    if !activeCollections.isEmpty {
                        CollapsibleHeader(title: "Saved", isExpanded: $collectionsExpanded)
                            .padding(.top, 8)
                    }

                    if collectionsExpanded {
                        ForEach(activeCollections) { category in
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
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.visible)
        }
        .background(Theme.sidebar)
        .navigationTitle("Roost")
        .alert("New Project", isPresented: $isAddingProject) {
            TextField("Project name", text: $newProjectName)
            Button("Create") {
                let tag = tagStore.projectTag(named: newProjectName.isEmpty ? "New Project" : newProjectName)
                let project = noteStore.addProject(name: newProjectName, parentID: newProjectParentID, tagID: tag?.id)
                if let parentID = newProjectParentID {
                    expandedProjectIDs.insert(parentID)
                }
                navigation.selection = .project(project.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(newProjectParentID == nil ? "Group your notes by what you're working on." : "Create a folder inside this project.")
        }
        .onAppear(perform: ensureProjectTags)
    }

    private func startAddingProject(parentID: UUID?) {
        newProjectName = ""
        newProjectParentID = parentID
        isAddingProject = true
    }

    private func ensureProjectTags() {
        for project in noteStore.projects where project.tagID == nil {
            guard let tag = tagStore.projectTag(named: project.name) else { continue }
            noteStore.setProjectTagID(project.id, tagID: tag.id)
            noteStore.addProjectTag(tag.id, toProject: project.id)
            store.addProjectTag(tag.id, toProject: project.id)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
    }

    private func count(for category: BookmarkCategory) -> Int {
        store.bookmarks(in: category).count
    }

    private func tagCount(for tagID: UUID) -> Int {
        noteStore.notes(withTag: tagID).count + store.bookmarks(withTag: tagID).count
    }

    private var todayCount: Int {
        let calendar = Calendar.current
        let savedToday = store.bookmarks.filter { calendar.isDateInToday($0.createdAt) }.count
        return noteStore.noteCount(for: .today) + savedToday
    }

    private var activeCollections: [BookmarkCategory] {
        BookmarkCategory.pileCases
            .filter { $0 != .screenshots }
            .filter { count(for: $0) > 0 }
    }
}

private struct CollapsibleHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    var addAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 12, height: 18)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
            }
            .buttonStyle(.plain)

            Spacer()

            if let addAction {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("New Project")
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }
}

private struct SidebarLogo: View {
    var body: some View {
        HStack(spacing: 10) {
            if let logoImage = RoostImage.nsImage() {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 28, height: 28)
            }

            Text("Roost")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()
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
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? Theme.selected : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TagSidebarRow: View {
    let tag: Tag
    let count: Int
    let isSelected: Bool
    let onRename: (String) -> Void
    let action: () -> Void
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "tag")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                        .frame(width: 16)

                    if isRenaming {
                        TextField("", text: $draftName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($isNameFocused)
                            .onSubmit(commitRename)
                            .onExitCommand(perform: cancelRename)
                    } else {
                        Text("#\(tag.name)")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 8)

                    if count > 0 && !isHovered && !isRenaming {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 7)
                .frame(height: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Theme.selected : Color.clear)
                }
            }
            .buttonStyle(.plain)
            .disabled(isRenaming)

            if isHovered && !isRenaming {
                Button(action: beginRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textTertiary)
                .help("Rename Tag")
                .padding(.trailing, 8)
            }
        }
        .onHover { isHovered = $0 }
        .onAppear {
            if draftName.isEmpty {
                draftName = tag.name
            }
        }
        .onChange(of: tag.name) { _, newName in
            if !isRenaming {
                draftName = newName
            }
        }
        .onChange(of: isNameFocused) { _, focused in
            if isRenaming && !focused {
                commitRename()
            }
        }
    }

    private func beginRename() {
        draftName = tag.name
        isRenaming = true
        DispatchQueue.main.async {
            isNameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != tag.name {
            onRename(trimmed)
        } else {
            draftName = tag.name
        }
        isRenaming = false
    }

    private func cancelRename() {
        draftName = tag.name
        isRenaming = false
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
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                    .frame(width: 16)

                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
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
            return Theme.field
        }

        return isSelected ? Theme.selected : Color.clear
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

private struct ProjectSidebarBranch: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var tagStore: TagStore
    @EnvironmentObject private var navigation: NavigationModel
    let project: Project
    let depth: Int
    @Binding var expandedProjectIDs: Set<UUID>
    let onAddChild: (UUID?) -> Void

    private var children: [Project] {
        noteStore.childProjects(of: project.id)
    }

    private var isExpanded: Bool {
        expandedProjectIDs.contains(project.id)
    }

    private var projectCount: Int {
        noteStore.notes(inProject: project.id).count + store.bookmarks(inProject: project.id).count
    }

    var body: some View {
        ProjectSidebarRow(
            projectID: project.id,
            projectTagID: project.tagID,
            title: project.name,
            count: projectCount,
            depth: depth,
            hasChildren: !children.isEmpty,
            isExpanded: isExpanded,
            isSelected: navigation.selection == .project(project.id),
            tint: Theme.projectColor(project.colorIndex),
            onToggleExpansion: toggleExpansion,
            onAddChild: {
                expandedProjectIDs.insert(project.id)
                onAddChild(project.id)
            },
            onRename: { newName in
                if let tagID = project.tagID {
                    tagStore.rename(tagID, to: newName)
                } else if let tag = tagStore.projectTag(named: newName) {
                    noteStore.setProjectTagID(project.id, tagID: tag.id)
                    noteStore.addProjectTag(tag.id, toProject: project.id)
                    store.addProjectTag(tag.id, toProject: project.id)
                }
                noteStore.renameProject(project.id, to: newName)
            },
            onDelete: deleteProject
        ) {
            navigation.selection = .project(project.id)
        }

        if isExpanded {
            ForEach(children) { child in
                ProjectSidebarBranch(
                    project: child,
                    depth: depth + 1,
                    expandedProjectIDs: $expandedProjectIDs,
                    onAddChild: onAddChild
                )
            }
        }
    }

    private func toggleExpansion() {
        if isExpanded {
            expandedProjectIDs.remove(project.id)
        } else {
            expandedProjectIDs.insert(project.id)
        }
    }

    private func deleteProject() {
        let deletedIDs = noteStore.descendantProjectIDs(of: project.id)
        if case .project(let selectedID) = navigation.selection, deletedIDs.contains(selectedID) {
            navigation.selection = .allNotes
        }
        store.clearProjects(deletedIDs)
        noteStore.deleteProject(project.id)
        expandedProjectIDs.subtract(deletedIDs)
    }
}

private struct ProjectSidebarRow: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel
    let projectID: UUID
    let projectTagID: UUID?
    let title: String
    let count: Int
    let depth: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let isSelected: Bool
    let tint: Color
    let onToggleExpansion: () -> Void
    let onAddChild: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let action: () -> Void
    @State private var isHovered = false
    @State private var isTargeted = false
    @State private var isRenaming = false
    @State private var draftTitle = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if depth > 0 {
                Spacer()
                    .frame(width: CGFloat(depth) * 14)
            }

            Button(action: onToggleExpansion) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(hasChildren ? Theme.textTertiary : Color.clear)
                    .frame(width: 12, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(!hasChildren)

            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: hasChildren ? "folder" : "folder")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(tint)
                        .frame(width: 16)

                    if isRenaming {
                        TextField("", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($isNameFocused)
                            .onSubmit(commitRename)
                            .onExitCommand(perform: cancelRename)
                    } else {
                        Text(title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 8)

                    if count > 0 && !isHovered && !isRenaming {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 7)
                .frame(height: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Theme.selected : Color.clear)
                }
            }
            .buttonStyle(.plain)
            .disabled(isRenaming)

            if isHovered && !isRenaming {
                HStack(spacing: 6) {
                    Button(action: onAddChild) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textTertiary)
                    .help("New Subfolder")

                    Button(action: beginRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textTertiary)
                    .help("Rename Project")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textTertiary)
                    .help("Delete Project")
                }
                .padding(.trailing, 8)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isTargeted ? Theme.field : (isSelected ? Theme.selected : Color.clear))
        }
        .onHover { isHovered = $0 }
        .onAppear {
            if draftTitle.isEmpty {
                draftTitle = title
            }
        }
        .onChange(of: isNameFocused) { _, focused in
            if isRenaming && !focused {
                commitRename()
            }
        }
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            fileDroppedContent(from: providers)
        }
    }

    private func beginRename() {
        draftTitle = title
        isRenaming = true
        DispatchQueue.main.async {
            isNameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != title {
            onRename(trimmed)
        } else {
            draftTitle = title
        }
        isRenaming = false
    }

    private func cancelRename() {
        draftTitle = title
        isRenaming = false
    }

    private func fileDroppedContent(from providers: [NSItemProvider]) -> Bool {
        if moveExistingBookmarkIntoProject(from: providers) {
            return true
        }

        return BookmarkDropHandler.handle(providers, store: store) { bookmark in
            store.assign(bookmark, toProject: projectID, projectTagID: projectTagID)
            navigation.selection = .project(projectID)
            noteStore.selectedNoteID = nil
            store.selectedBookmarkID = bookmark.id
        }
    }

    private func moveExistingBookmarkIntoProject(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let rawID = item as? String,
                  let id = UUID(uuidString: rawID) else { return }

            DispatchQueue.main.async {
                if noteStore.notes.contains(where: { $0.id == id }) {
                    noteStore.update(id) { $0.projectID = projectID }
                    if let projectTagID {
                        noteStore.addTag(projectTagID, to: id)
                    }
                    navigation.selection = .project(projectID)
                    noteStore.selectedNoteID = id
                    store.selectedBookmarkID = nil
                    return
                }

                guard let bookmark = store.bookmarks.first(where: { $0.id == id }) else { return }
                store.assign(bookmark, toProject: projectID, projectTagID: projectTagID)
                navigation.selection = .project(projectID)
                noteStore.selectedNoteID = nil
                store.selectedBookmarkID = bookmark.id
            }
        }

        return true
    }
}
