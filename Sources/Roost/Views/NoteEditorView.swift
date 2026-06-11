import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    let note: Note

    @State private var title: String
    @State private var content: String
    @State private var isLinkDropTargeted = false

    init(note: Note) {
        self.note = note
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerControls

                TextField("Title", text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .onChange(of: title) { _, newValue in
                        noteStore.update(note.id) { $0.title = newValue }
                    }

                metadataRow

                TextEditor(text: $content)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .padding(10)
                    .paperPanel(cornerRadius: 10, tint: Theme.rose)
                    .onChange(of: content) { _, newValue in
                        noteStore.update(note.id) { $0.content = newValue }
                    }

                linkedBookmarksSection
            }
            .padding(26)
            .frame(maxWidth: 760, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(PaintedBackdrop())
    }

    private var headerControls: some View {
        HStack(spacing: 10) {
            Button {
                noteStore.toggleDone(note.id)
            } label: {
                Label(note.isDone ? "Done" : "Mark Done", systemImage: note.isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.bordered)
            .tint(note.isDone ? Theme.moss : nil)

            Button {
                noteStore.toggleAgenda(note.id)
            } label: {
                Label(note.isOnAgenda ? "On the Agenda" : "Put on Agenda", systemImage: note.isOnAgenda ? "star.fill" : "star")
            }
            .buttonStyle(.bordered)
            .tint(note.isOnAgenda ? Theme.gold : nil)

            Spacer()

            Button(role: .destructive) {
                noteStore.deleteNote(note.id)
            } label: {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Delete note")
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 14) {
            Picker("Project", selection: Binding(
                get: { note.projectID },
                set: { newValue in noteStore.update(note.id) { $0.projectID = newValue } }
            )) {
                Text("No Project").tag(UUID?.none)
                ForEach(noteStore.projects) { project in
                    Label(project.name, systemImage: project.symbolName)
                        .tag(Optional(project.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            Toggle("Scheduled", isOn: Binding(
                get: { note.date != nil },
                set: { isOn in
                    noteStore.update(note.id) { $0.date = isOn ? Calendar.current.startOfDay(for: Date()) : nil }
                }
            ))
            .toggleStyle(.checkbox)

            if note.date != nil {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { note.date ?? Date() },
                        set: { newValue in noteStore.update(note.id) { $0.date = newValue } }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }

            Spacer()

            Text("Edited \(relativeLabel(note.updatedAt))")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var linkedBookmarksSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Linked Items")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            ForEach(linkedBookmarks) { bookmark in
                HStack(spacing: 10) {
                    Image(systemName: bookmark.category.symbolName)
                        .foregroundStyle(Theme.moss)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(bookmark.title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(bookmark.location)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        bookmarkStore.open(bookmark)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderless)
                    .help("Open")

                    Button {
                        noteStore.detach(bookmarkID: bookmark.id, from: note.id)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from note")
                }
                .padding(.vertical, 6)
            }

            HStack(spacing: 10) {
                Image(systemName: isLinkDropTargeted ? "sparkles" : "link.badge.plus")
                    .foregroundStyle(isLinkDropTargeted ? Theme.gold : Theme.textSecondary)
                Text(isLinkDropTargeted ? "Drop to attach" : "Drop a link or file here to attach it to this note")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isLinkDropTargeted ? Theme.gold : Theme.ink.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            }
            .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isLinkDropTargeted) { providers in
                BookmarkDropHandler.handle(providers, store: bookmarkStore) { bookmark in
                    noteStore.attach(bookmarkID: bookmark.id, to: note.id)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 10, tint: Theme.lavender)
    }

    private var linkedBookmarks: [Bookmark] {
        note.linkedBookmarkIDs.compactMap { id in
            bookmarkStore.bookmarks.first { $0.id == id }
        }
    }

    private func relativeLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NotePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Theme.rose)

            Text("Pick a note or start a new one")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Notes live on your timeline, sorted by day and project — perfect for juggling more than one thing at once.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaintedBackdrop())
    }
}
