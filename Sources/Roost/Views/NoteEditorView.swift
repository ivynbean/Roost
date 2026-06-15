import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    @EnvironmentObject private var tagStore: TagStore
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
            VStack(alignment: .leading, spacing: 14) {
                headerControls

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Note title", text: $title, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .onChange(of: title) { _, newValue in
                            noteStore.update(note.id) { $0.title = newValue }
                            syncInlineTags(title: newValue, content: content)
                        }

                    metadataRow

                    ZStack(alignment: .topLeading) {
                        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Write the details here…")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $content)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 260)
                            .onChange(of: content) { _, newValue in
                                noteStore.update(note.id) { $0.content = newValue }
                                syncInlineTags(title: title, content: newValue)
                            }
                    }
                    .padding(10)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    }
                }
                .padding(16)
                .paperPanel(cornerRadius: 4, tint: Theme.rose, fillOpacity: 0.64)

                TagEditorView(
                    tagIDs: note.tagIDs,
                    onAdd: { tagID in noteStore.addTag(tagID, to: note.id) },
                    onRemove: { tagID in noteStore.removeTag(tagID, from: note.id) }
                )
                .environmentObject(tagStore)

                linkedBookmarksSection
            }
            .padding(26)
            .frame(maxWidth: 720, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(PaintedBackdrop())
    }

    private var headerControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                leadingHeaderActions
                Spacer(minLength: 10)
                deleteButton
            }

            VStack(alignment: .leading, spacing: 10) {
                leadingHeaderActions
                HStack {
                    Spacer()
                    deleteButton
                }
            }
        }
    }

    private var metadataRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                projectMenu
                scheduleControls
                Spacer(minLength: 12)
                editedLabel
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    projectMenu
                    Spacer(minLength: 8)
                    editedLabel
                }
                scheduleControls
            }
        }
    }

    private var leadingHeaderActions: some View {
        HStack(spacing: 10) {
            noteTypeButton
            pinButton
            if note.isTask {
                doneButton
            }
        }
    }

    private var noteTypeButton: some View {
        Button {
            noteStore.update(note.id) {
                $0.isTask.toggle()
                if !$0.isTask { $0.isDone = false }
            }
        } label: {
            Label(note.isTask ? "Task" : "Note", systemImage: note.isTask ? "checklist" : "doc.text")
                .padding(.horizontal, 10)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(note.isTask ? Theme.rose : Theme.textSecondary)
        .background(note.isTask ? Theme.rose.opacity(0.12) : Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(note.isTask ? Theme.rose.opacity(0.35) : Theme.cardStroke, lineWidth: 1)
        }
    }

    private var pinButton: some View {
        Button {
            noteStore.toggleAgenda(note.id)
        } label: {
            Label(note.isOnAgenda ? "Pinned" : "Pin", systemImage: note.isOnAgenda ? "pin.fill" : "pin")
                .padding(.horizontal, 10)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(note.isOnAgenda ? Theme.gold : Theme.textSecondary)
        .background(note.isOnAgenda ? Theme.gold.opacity(0.13) : Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(note.isOnAgenda ? Theme.gold.opacity(0.42) : Theme.cardStroke, lineWidth: 1)
        }
    }

    private var doneButton: some View {
        Button {
            noteStore.toggleDone(note.id)
        } label: {
            Label(note.isDone ? "Done" : "Mark done", systemImage: "checkmark")
                .padding(.horizontal, 10)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(note.isDone ? Theme.moss : Theme.textSecondary)
        .background(note.isDone ? Theme.moss.opacity(0.12) : Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(note.isDone ? Theme.moss.opacity(0.35) : Theme.cardStroke, lineWidth: 1)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            noteStore.deleteNote(note.id)
        } label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(.iconOnly)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.rose)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .help("Delete note")
    }

    private var projectMenu: some View {
        Menu {
            Button("No Project") {
                noteStore.update(note.id) { $0.projectID = nil }
            }
            ForEach(noteStore.projects) { project in
                Button {
                    noteStore.update(note.id) { $0.projectID = project.id }
                    if let tagID = project.tagID {
                        noteStore.addTag(tagID, to: note.id)
                    }
                } label: {
                    Label(project.name, systemImage: project.symbolName)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let project = noteStore.project(for: note.projectID) {
                    Circle()
                        .fill(Theme.projectColor(project.colorIndex))
                        .frame(width: 8, height: 8)
                    Text(project.name)
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 11, weight: .medium))
                    Text("No Project")
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .menuStyle(.borderlessButton)
    }

    private var scheduleControls: some View {
        HStack(spacing: 10) {
            Button {
                noteStore.update(note.id) {
                    $0.date = $0.date == nil ? Calendar.current.startOfDay(for: Date()) : nil
                }
            } label: {
                Label(note.date == nil ? "Schedule" : "Scheduled", systemImage: note.date == nil ? "calendar.badge.plus" : "calendar")
                    .padding(.horizontal, 10)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(note.date == nil ? Theme.textSecondary : Theme.lavender)
            .background(note.date == nil ? Theme.field : Theme.lavender.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(note.date == nil ? Theme.cardStroke : Theme.lavender.opacity(0.32), lineWidth: 1)
            }

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
                .fixedSize()
            }
        }
    }

    private var editedLabel: some View {
        Text("Edited \(relativeLabel(note.updatedAt))")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
    }

    private var linkedBookmarksSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Linked Items")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(linkedBookmarks) { bookmark in
                HStack(spacing: 10) {
                    Image(systemName: bookmark.category.symbolName)
                        .foregroundStyle(Theme.moss)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(bookmark.displayTitle)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(bookmark.displayLocation)
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
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        isLinkDropTargeted ? Theme.gold : Theme.cardStroke,
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
        .paperPanel(cornerRadius: 4, tint: Theme.lavender)
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

    private func syncInlineTags(title: String, content: String) {
        for tagID in tagStore.tagIDs(in: "\(title)\n\(content)") {
            noteStore.addTag(tagID, to: note.id)
        }
    }
}

struct NotePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Theme.rose)

            Text("Pick a note or start a new one")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Notes live on your timeline, sorted by day and project.")
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
