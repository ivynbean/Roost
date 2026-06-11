import XCTest
@testable import Roost

final class NoteStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoostNoteStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testNoteRoundTripsThroughRoostCoders() throws {
        let note = Note(
            title: "Standup prep",
            content: "Talk about the drop bucket polish.",
            projectID: UUID(),
            date: Date(timeIntervalSince1970: 1_780_000_000),
            isOnAgenda: true,
            linkedBookmarkIDs: [UUID()]
        )

        let data = try JSONEncoder.roost.encode(note)
        let decoded = try JSONDecoder.roost.decode(Note.self, from: data)

        XCTAssertEqual(decoded.id, note.id)
        XCTAssertEqual(decoded.title, note.title)
        XCTAssertEqual(decoded.content, note.content)
        XCTAssertEqual(decoded.projectID, note.projectID)
        XCTAssertTrue(decoded.isOnAgenda)
        XCTAssertEqual(decoded.linkedBookmarkIDs, note.linkedBookmarkIDs)
    }

    func testNoteDecodingToleratesMissingNewFields() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "title": "Bare note",
          "createdAt": "2026-06-05T00:00:00Z"
        }
        """.data(using: .utf8)!

        let note = try JSONDecoder.roost.decode(Note.self, from: json)

        XCTAssertEqual(note.title, "Bare note")
        XCTAssertEqual(note.content, "")
        XCTAssertFalse(note.isOnAgenda)
        XCTAssertFalse(note.isDone)
        XCTAssertEqual(note.linkedBookmarkIDs, [])
        XCTAssertEqual(note.updatedAt, note.createdAt)
    }

    func testDisplayTitleFallsBackToContentFirstLine() {
        XCTAssertEqual(Note(title: "Named", content: "Body").displayTitle, "Named")
        XCTAssertEqual(Note(content: "First line\nSecond line").displayTitle, "First line")
        XCTAssertEqual(Note().displayTitle, "Untitled note")
    }

    func testTodayAndAgendaFiltering() {
        let store = NoteStore(directory: tempDirectory)
        store.notes = []

        let todayNote = store.addNote(date: Date())
        let agendaNote = store.addNote()
        store.toggleAgenda(agendaNote.id)
        store.update(agendaNote.id) { $0.date = Date(timeIntervalSinceNow: -7 * 24 * 3600) }

        XCTAssertTrue(store.todayNotes.contains { $0.id == todayNote.id })
        XCTAssertFalse(store.todayNotes.contains { $0.id == agendaNote.id })
        XCTAssertEqual(store.agendaNotes.map(\.id), [agendaNote.id])
    }

    func testDeleteProjectUnassignsNotes() {
        let store = NoteStore(directory: tempDirectory)
        store.notes = []
        let project = store.addProject(name: "Side Quest")
        let note = store.addNote(projectID: project.id)

        store.deleteProject(project.id)

        XCTAssertFalse(store.projects.contains { $0.id == project.id })
        XCTAssertNil(store.notes.first { $0.id == note.id }?.projectID)
    }

    func testAttachAndDetachBookmark() {
        let store = NoteStore(directory: tempDirectory)
        store.notes = []
        let note = store.addNote()
        let bookmarkID = UUID()

        store.attach(bookmarkID: bookmarkID, to: note.id)
        store.attach(bookmarkID: bookmarkID, to: note.id)
        XCTAssertEqual(store.notes.first?.linkedBookmarkIDs, [bookmarkID])

        store.detach(bookmarkID: bookmarkID, from: note.id)
        XCTAssertEqual(store.notes.first?.linkedBookmarkIDs, [])
    }

    func testUpdateBumpsUpdatedAtOnlyOnChange() throws {
        let store = NoteStore(directory: tempDirectory)
        store.notes = []
        let note = store.addNote()
        let original = try XCTUnwrap(store.notes.first { $0.id == note.id })

        store.update(note.id) { $0.title = $0.title }
        XCTAssertEqual(store.notes.first { $0.id == note.id }?.updatedAt, original.updatedAt)

        store.update(note.id) { $0.title = "Changed" }
        let updated = try XCTUnwrap(store.notes.first { $0.id == note.id })
        XCTAssertGreaterThanOrEqual(updated.updatedAt, original.updatedAt)
        XCTAssertEqual(updated.title, "Changed")
    }
}
