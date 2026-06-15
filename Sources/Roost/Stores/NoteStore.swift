import Foundation
import OSLog

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = [] {
        didSet { scheduleSave() }
    }
    @Published var projects: [Project] = [] {
        didSet { scheduleSave() }
    }
    @Published var selectedNoteID: Note.ID?
    @Published var searchText = ""

    private let logger = Logger(subsystem: "com.ivynbean.Roost", category: "notes")
    private let notesURL: URL
    private let projectsURL: URL
    private var saveTask: Task<Void, Never>?

    init(directory: URL? = nil) {
        let support: URL
        if let directory {
            support = directory
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            support = applicationSupport.appendingPathComponent("Roost", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        notesURL = support.appendingPathComponent("notes.json")
        projectsURL = support.appendingPathComponent("projects.json")
        load()
    }

    var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    // MARK: - Filtering

    var agendaNotes: [Note] {
        applySearch(notes.filter(\.isOnAgenda))
    }

    var taskNotes: [Note] {
        applySearch(notes.filter(\.isTask))
    }

    var todayNotes: [Note] {
        let calendar = Calendar.current
        return applySearch(notes.filter { calendar.isDateInToday($0.timelineDate) })
    }

    var allNotes: [Note] {
        applySearch(notes)
    }

    func notes(inProject projectID: UUID) -> [Note] {
        applySearch(notes.filter { $0.projectID == projectID })
    }

    func notes(withTag tagID: UUID) -> [Note] {
        applySearch(notes.filter { $0.tagIDs.contains(tagID) })
    }

    func childProjects(of parentID: UUID?) -> [Project] {
        projects
            .filter { $0.parentID == parentID }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func descendantProjectIDs(of parentID: UUID) -> Set<UUID> {
        var ids: Set<UUID> = [parentID]
        var pending = [parentID]

        while let id = pending.popLast() {
            let children = projects.filter { $0.parentID == id }.map(\.id)
            ids.formUnion(children)
            pending.append(contentsOf: children)
        }

        return ids
    }

    func noteCount(for selection: SidebarSelection) -> Int {
        switch selection {
        case .today: todayNotes.count
        case .agenda: agendaNotes.count
        case .tasks: taskNotes.count
        case .allNotes: allNotes.count
        case .project(let id): notes(inProject: id).count
        case .tag(let id): notes(withTag: id).count
        case .collection: 0
        }
    }

    func visibleNotes(for selection: SidebarSelection) -> [Note] {
        switch selection {
        case .today: todayNotes
        case .agenda: agendaNotes
        case .tasks: taskNotes
        case .allNotes: allNotes
        case .project(let id): notes(inProject: id)
        case .tag(let id): notes(withTag: id)
        case .collection: []
        }
    }

    private func applySearch(_ notes: [Note]) -> [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Note CRUD

    @discardableResult
    func addNote(projectID: UUID? = nil, tagIDs: [UUID] = [], date: Date? = nil, isTask: Bool = false) -> Note {
        var note = Note(projectID: projectID, date: date, isTask: isTask, tagIDs: tagIDs)
        if let projectID,
           let projectTagID = project(for: projectID)?.tagID,
           !note.tagIDs.contains(projectTagID) {
            note.tagIDs.append(projectTagID)
        }
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        logger.info("Added note id=\(note.id.uuidString, privacy: .public)")
        return note
    }

    func update(_ id: Note.ID, mutate: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[index]
        mutate(&note)
        guard note != notes[index] else { return }
        note.updatedAt = Date()
        notes[index] = note
    }

    func deleteNote(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
        if selectedNoteID == id {
            selectedNoteID = nil
        }
        logger.info("Deleted note id=\(id.uuidString, privacy: .public)")
    }

    func toggleAgenda(_ id: Note.ID) {
        update(id) { $0.isOnAgenda.toggle() }
    }

    func toggleDone(_ id: Note.ID) {
        update(id) { note in
            guard note.isTask else { return }
            note.isDone.toggle()
        }
    }

    func attach(bookmarkID: UUID, to noteID: Note.ID) {
        update(noteID) { note in
            guard !note.linkedBookmarkIDs.contains(bookmarkID) else { return }
            note.linkedBookmarkIDs.append(bookmarkID)
        }
    }

    @discardableResult
    func addLinkedBookmarkNote(for bookmark: Bookmark, to projectID: UUID) -> Note {
        let note = addNote(projectID: projectID)
        update(note.id) { draft in
            draft.title = bookmark.displayTitle
            if bookmark.kind == .text {
                draft.content = bookmark.summary.isEmpty ? bookmark.location : bookmark.summary
            }
            if bookmark.kind != .text {
                draft.linkedBookmarkIDs = [bookmark.id]
            }
        }
        return note
    }

    func detach(bookmarkID: UUID, from noteID: Note.ID) {
        update(noteID) { note in
            note.linkedBookmarkIDs.removeAll { $0 == bookmarkID }
        }
    }

    func addTag(_ tagID: UUID, to noteID: Note.ID) {
        update(noteID) { note in
            guard !note.tagIDs.contains(tagID) else { return }
            note.tagIDs.append(tagID)
        }
    }

    func removeTag(_ tagID: UUID, from noteID: Note.ID) {
        update(noteID) { note in
            note.tagIDs.removeAll { $0 == tagID }
        }
    }

    // MARK: - Project CRUD

    @discardableResult
    func addProject(name: String, parentID: UUID? = nil, tagID: UUID? = nil) -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = Project(
            name: trimmed.isEmpty ? "New Project" : trimmed,
            parentID: parentID,
            tagID: tagID,
            colorIndex: projects.count
        )
        projects.append(project)
        logger.info("Added project id=\(project.id.uuidString, privacy: .public)")
        return project
    }

    func renameProject(_ id: Project.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = trimmed
    }

    func setProjectTagID(_ id: Project.ID, tagID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }),
              projects[index].tagID != tagID else { return }
        projects[index].tagID = tagID
    }

    func addProjectTag(_ tagID: UUID, toProject projectID: UUID) {
        notes = notes.map { note in
            var note = note
            if note.projectID == projectID, !note.tagIDs.contains(tagID) {
                note.tagIDs.append(tagID)
            }
            return note
        }
    }

    func deleteProject(_ id: Project.ID) {
        let deletedIDs = descendantProjectIDs(of: id)
        projects.removeAll { deletedIDs.contains($0.id) }
        notes = notes.map { note in
            var note = note
            if let projectID = note.projectID, deletedIDs.contains(projectID) {
                note.projectID = nil
            }
            return note
        }
        logger.info("Deleted project id=\(id.uuidString, privacy: .public)")
    }

    func project(for id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: projectsURL),
           let decoded = try? JSONDecoder.roost.decode([Project].self, from: data) {
            projects = decoded
        } else {
            projects = [
                Project(name: "Personal", symbolName: "person", colorIndex: 0),
                Project(name: "Work", symbolName: "briefcase", colorIndex: 1)
            ]
        }

        if let data = try? Data(contentsOf: notesURL) {
            do {
                notes = try JSONDecoder.roost.decode([Note].self, from: data)
            } catch {
                logger.error("Failed to load notes: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let notes = notes
        let projects = projects
        let notesURL = notesURL
        let projectsURL = projectsURL
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try JSONEncoder.roost.encode(notes).write(to: notesURL, options: .atomic)
                try JSONEncoder.roost.encode(projects).write(to: projectsURL, options: .atomic)
            } catch {
                Logger(subsystem: "com.ivynbean.Roost", category: "persistence")
                    .error("Failed to save notes: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
