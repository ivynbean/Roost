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

    func noteCount(for selection: SidebarSelection) -> Int {
        switch selection {
        case .today: todayNotes.count
        case .agenda: agendaNotes.count
        case .allNotes: allNotes.count
        case .project(let id): notes(inProject: id).count
        case .collection: 0
        }
    }

    func visibleNotes(for selection: SidebarSelection) -> [Note] {
        switch selection {
        case .today: todayNotes
        case .agenda: agendaNotes
        case .allNotes: allNotes
        case .project(let id): notes(inProject: id)
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
    func addNote(projectID: UUID? = nil, date: Date? = nil) -> Note {
        let note = Note(projectID: projectID, date: date)
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
        update(id) { $0.isDone.toggle() }
    }

    func attach(bookmarkID: UUID, to noteID: Note.ID) {
        update(noteID) { note in
            guard !note.linkedBookmarkIDs.contains(bookmarkID) else { return }
            note.linkedBookmarkIDs.append(bookmarkID)
        }
    }

    func detach(bookmarkID: UUID, from noteID: Note.ID) {
        update(noteID) { note in
            note.linkedBookmarkIDs.removeAll { $0 == bookmarkID }
        }
    }

    // MARK: - Project CRUD

    @discardableResult
    func addProject(name: String) -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = Project(
            name: trimmed.isEmpty ? "New Project" : trimmed,
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

    func deleteProject(_ id: Project.ID) {
        projects.removeAll { $0.id == id }
        notes = notes.map { note in
            var note = note
            if note.projectID == id {
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
