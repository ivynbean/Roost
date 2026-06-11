import SwiftUI

struct NotesListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    @EnvironmentObject private var navigation: NavigationModel
    @EnvironmentObject private var calendarService: CalendarService
    @AppStorage("roost.showCalendarInToday") private var showCalendar = true
    @State private var notesExpanded = true
    @State private var savedExpanded = true
    @State private var collapsedDays: Set<Date> = []

    private var showsCalendarStrip: Bool {
        navigation.selection == .today && showCalendar
    }

    var body: some View {
        if navigation.selection == .today {
            TodayTimelineView(
                notes: todayNotes,
                bookmarks: todayBookmarks,
                notesExpanded: $notesExpanded,
                savedExpanded: $savedExpanded,
                onAddNote: addNote
            )
        } else {
            notesOnlyBody
        }
    }

    private var notesOnlyBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if showsCalendarStrip {
                    TodayCalendarStrip()
                        .padding(.bottom, 8)
                }

                if groupedNotes.isEmpty {
                    TimelineSectionHeader(
                        title: listTitle,
                        count: 0,
                        isExpanded: true
                    ) {}

                    InlineEmptyRow(
                        symbolName: emptySymbolName,
                        title: emptyTitle,
                        message: emptyMessage
                    ) {
                        addNote()
                    }
                    .padding(.top, 8)
                } else {
                    ForEach(groupedNotes, id: \.day) { group in
                        Section {
                            if !collapsedDays.contains(group.day) {
                                ForEach(group.notes) { note in
                                    NoteRow(note: note, isSelected: note.id == noteStore.selectedNoteID)
                                        .onDrag {
                                            NSItemProvider(object: note.id.uuidString as NSString)
                                        }
                                        .contextMenu {
                                            Button(note.isOnAgenda ? "Remove from Agenda" : "Put on the Agenda") {
                                                noteStore.toggleAgenda(note.id)
                                            }
                                            Button(note.isTask ? "Convert to Note" : "Make Task") {
                                                noteStore.update(note.id) {
                                                    $0.isTask.toggle()
                                                    if !$0.isTask { $0.isDone = false }
                                                }
                                            }
                                            if note.isTask {
                                                Button(note.isDone ? "Mark Not Done" : "Mark Done") {
                                                    noteStore.toggleDone(note.id)
                                                }
                                            }
                                            Menu("Move to Project") {
                                                ForEach(noteStore.projects) { project in
                                                    Button(project.name) {
                                                        noteStore.update(note.id) { $0.projectID = project.id }
                                                    }
                                                }
                                                Button("No Project") {
                                                    noteStore.update(note.id) { $0.projectID = nil }
                                                }
                                            }
                                            Divider()
                                            Button("Delete", role: .destructive) {
                                                noteStore.deleteNote(note.id)
                                            }
                                        }
                                }
                            }
                        } header: {
                            TimelineSectionHeader(
                                title: dayLabel(for: group.day),
                                count: group.notes.count,
                                isExpanded: !collapsedDays.contains(group.day)
                            ) {
                                toggleDay(group.day)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(PaintedBackdrop())
        .navigationTitle(listTitle)
    }

    private var todayNotes: [Note] {
        noteStore.visibleNotes(for: .today)
    }

    private var todayBookmarks: [Bookmark] {
        let calendar = Calendar.current
        let query = noteStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return bookmarkStore.bookmarks
            .filter { calendar.isDateInToday($0.createdAt) }
            .filter { bookmark in
                guard !query.isEmpty else { return true }
                return bookmark.displayTitle.localizedCaseInsensitiveContains(query)
                    || bookmark.displayLocation.localizedCaseInsensitiveContains(query)
                    || bookmark.summary.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func toggleDay(_ day: Date) {
        if collapsedDays.contains(day) {
            collapsedDays.remove(day)
        } else {
            collapsedDays.insert(day)
        }
    }

    private var listTitle: String {
        switch navigation.selection {
        case .today: "Today"
        case .agenda: "On the Agenda"
        case .tasks: "Tasks"
        case .allNotes: "All Notes"
        case .project(let id): noteStore.project(for: id)?.name ?? "Project"
        case .collection(let category): category.rawValue
        }
    }

    private var groupedNotes: [(day: Date, notes: [Note])] {
        let calendar = Calendar.current
        let visible = noteStore.visibleNotes(for: navigation.selection)
        let groups = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.timelineDate) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day]!.sorted { $0.updatedAt > $1.updatedAt })
        }
    }

    private func dayLabel(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: day)
    }

    private func addNote() {
        bookmarkStore.selectedBookmarkID = nil
        var projectID: UUID?
        if case .project(let id) = navigation.selection {
            projectID = id
        }
        let date: Date? = navigation.selection == .today ? Date() : nil
        let note = noteStore.addNote(
            projectID: projectID,
            date: date,
            isTask: navigation.selection == .tasks
        )
        if navigation.selection == .agenda {
            noteStore.toggleAgenda(note.id)
        }
    }

    private var emptyTitle: String {
        switch navigation.selection {
        case .agenda: "Nothing on the agenda"
        case .tasks: "No tasks yet"
        case .allNotes: "No notes yet"
        case .project(let id): "Nothing in \(noteStore.project(for: id)?.name ?? "this project")"
        default: "No notes yet"
        }
    }

    private var emptyMessage: String {
        switch navigation.selection {
        case .agenda: "Pin a note to keep it on your agenda."
        case .tasks: "Create a task or turn any note into one."
        case .project: "Drop a link, file, or note here to start collecting work."
        default: "Use the capture bar above or start a note."
        }
    }

    private var emptySymbolName: String {
        switch navigation.selection {
        case .agenda: "pin"
        case .tasks: "checkmark.circle"
        case .project: "folder"
        default: "square.and.pencil"
        }
    }
}

private struct TodayTimelineView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    @EnvironmentObject private var calendarService: CalendarService
    @AppStorage("roost.showCalendarInToday") private var showCalendar = true
    let notes: [Note]
    let bookmarks: [Bookmark]
    @Binding var notesExpanded: Bool
    @Binding var savedExpanded: Bool
    let onAddNote: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if showCalendar {
                    TodayCalendarStrip()
                        .padding(.bottom, 10)
                }

                TimelineSectionHeader(
                    title: "Notes",
                    count: notes.count,
                    isExpanded: notesExpanded
                ) {
                    notesExpanded.toggle()
                }

                if notesExpanded {
                    if notes.isEmpty {
                        InlineEmptyRow(
                            symbolName: "square.and.pencil",
                            title: "No notes yet",
                            message: "Use the capture bar above or start a note."
                        ) {
                            onAddNote()
                        }
                    } else {
                        ForEach(notes) { note in
                            NoteRow(note: note, isSelected: note.id == noteStore.selectedNoteID)
                                .onDrag {
                                    NSItemProvider(object: note.id.uuidString as NSString)
                                }
                        }
                    }
                }

                TimelineSectionHeader(
                    title: "Saved today",
                    count: bookmarks.count,
                    isExpanded: savedExpanded
                ) {
                    savedExpanded.toggle()
                }
                .padding(.top, 10)

                if savedExpanded {
                    if bookmarks.isEmpty {
                        InlineEmptyRow(
                            symbolName: "tray.and.arrow.down",
                            title: "Nothing saved yet",
                            message: "Links, files, and screenshots captured today show up here."
                        )
                    } else {
                        ForEach(bookmarks) { bookmark in
                            TodayBookmarkRow(
                                bookmark: bookmark,
                                isSelected: bookmark.id == bookmarkStore.selectedBookmarkID
                            )
                            .onDrag {
                                NSItemProvider(object: bookmark.id.uuidString as NSString)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(PaintedBackdrop())
        .navigationTitle("Today")
    }
}

private struct TimelineSectionHeader: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()

                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 1)
            }
            .padding(.horizontal, 4)
            .padding(.top, 12)
            .padding(.bottom, 3)
        }
        .buttonStyle(.plain)
    }
}

private struct TodayBookmarkRow: View {
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    let bookmark: Bookmark
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            noteStore.selectedNoteID = nil
            bookmarkStore.selectedBookmarkID = bookmark.id
            bookmarkStore.selectedCategory = bookmark.displayCategory
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(iconTint)

                        Text(bookmark.displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        if bookmark.isImportant {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                    }

                    Text(bookmark.secondaryLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(shortTime(bookmark.createdAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)

                        if bookmark.displayCategory != .readLater {
                            Text("•")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accentColor)

                            Text(bookmark.displayCategory.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 10)

                if showsActions {
                    HStack(spacing: 10) {
                        TimelineGlyphAction(symbolName: "arrow.up.forward", help: "Open") {
                            bookmarkStore.open(bookmark)
                        }
                        TimelineGlyphAction(symbolName: "doc.on.doc", help: "Copy link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(bookmark.location, forType: .string)
                        }
                        TimelineGlyphAction(
                            symbolName: bookmark.isImportant ? "pin.fill" : "pin",
                            isActive: bookmark.isImportant,
                            help: bookmark.isImportant ? "Unpin" : "Pin"
                        ) {
                            bookmarkStore.toggleImportant(bookmark)
                        }
                        TimelineGlyphAction(symbolName: "trash", tint: Theme.destructive, help: "Delete") {
                            bookmarkStore.delete(bookmark)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.card.opacity(isSelected ? 0.96 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") {
                bookmarkStore.open(bookmark)
            }
            Menu("Move to Collection") {
                ForEach(BookmarkCategory.pileCases) { category in
                    Button(category.rawValue) {
                        bookmarkStore.move(bookmark, to: category)
                    }
                }
            }
            Button("Delete", role: .destructive) {
                bookmarkStore.delete(bookmark)
            }
        }
    }

    private var showsActions: Bool {
        isHovered
    }

    private var iconName: String {
        switch bookmark.kind {
        case .web: "globe"
        case .file: "doc"
        case .text: "text.quote"
        }
    }

    private var iconTint: Color {
        switch bookmark.kind {
        case .web: Theme.lavender
        case .file: Theme.wood
        case .text: Theme.rose
        }
    }

    private var accentColor: Color {
        switch bookmark.displayCategory {
        case .work: Theme.rose
        case .code: Theme.lavender
        case .design: Theme.gold
        case .docs, .screenshots: Theme.wood
        default: iconTint
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private struct TimelineGlyphAction: View {
    let symbolName: String
    var isActive = false
    var tint: Color? = nil
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint ?? (isActive ? Theme.gold : Theme.textTertiary))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct InlineEmptyRow: View {
    let symbolName: String
    let title: String
    let message: String
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 34, height: 34)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if let action {
                Button(action: action) {
                    Label("New Note", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(Theme.rose, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.card.opacity(0.52), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct NoteRow: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    let note: Note
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            bookmarkStore.selectedBookmarkID = nil
            noteStore.selectedNoteID = note.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: noteIconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(noteIconColor)

                        Text(note.displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .strikethrough(note.isTask && note.isDone, color: Theme.ink.opacity(0.5))
                            .lineLimit(1)

                        if note.isOnAgenda {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                    }

                    if !note.content.isEmpty {
                        Text(note.content.firstLine(maxLength: 90))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Text(shortTime(note.timelineDate))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)

                        if let project = noteStore.project(for: note.projectID) {
                            Text("•")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.projectColor(project.colorIndex))

                            Text(project.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 10)

                if showsActions {
                    HStack(spacing: 10) {
                        TimelineGlyphAction(
                            symbolName: note.isOnAgenda ? "pin.fill" : "pin",
                            isActive: note.isOnAgenda,
                            help: note.isOnAgenda ? "Unpin from agenda" : "Pin to agenda"
                        ) {
                            noteStore.toggleAgenda(note.id)
                        }

                        TimelineGlyphAction(
                            symbolName: note.isTask ? (note.isDone ? "arrow.uturn.backward" : "checkmark") : "checklist",
                            isActive: note.isTask && note.isDone,
                            help: note.isTask ? (note.isDone ? "Mark not done" : "Mark done") : "Make task"
                        ) {
                            if note.isTask {
                                noteStore.toggleDone(note.id)
                            } else {
                                noteStore.update(note.id) { $0.isTask = true }
                            }
                        }
                        TimelineGlyphAction(symbolName: "trash", tint: Theme.destructive, help: "Delete") {
                            noteStore.deleteNote(note.id)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.card.opacity(isSelected ? 0.96 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var showsActions: Bool {
        isHovered
    }

    private var noteIconName: String {
        if note.isTask {
            return note.isDone ? "checkmark.circle.fill" : "checkmark.circle"
        }
        return note.content.isEmpty ? "doc.text" : "doc.plaintext"
    }

    private var noteIconColor: Color {
        note.isTask && note.isDone ? Theme.moss : accentColor
    }

    private var accentColor: Color {
        if let project = noteStore.project(for: note.projectID) {
            return Theme.projectColor(project.colorIndex)
        }
        return Theme.lavender
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private struct TodayCalendarStrip: View {
    @EnvironmentObject private var calendarService: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch calendarService.accessState {
            case .authorized:
                if calendarService.todayEvents.isEmpty {
                    Label("No calendar events today", systemImage: "calendar")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Label("Today's Calendar", systemImage: "calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.moss)
                    ForEach(calendarService.todayEvents) { event in
                        HStack(spacing: 10) {
                            Text(event.isAllDay ? "All day" : timeLabel(event.startDate))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Theme.wood)
                                .frame(width: 64, alignment: .leading)
                            Text(event.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(event.calendarTitle)
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            case .notDetermined:
                HStack(spacing: 10) {
                    Label("See your day alongside your notes", systemImage: "calendar.badge.plus")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("Connect Calendar") {
                        calendarService.connect()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            case .denied:
                Label("Calendar access is off. Enable it in System Settings → Privacy.", systemImage: "calendar.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 4, tint: Theme.moss)
        .onAppear {
            calendarService.refreshAuthorization()
            calendarService.loadTodayEvents()
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private struct EmptyNotesView: View {
    let selection: SidebarSelection
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Theme.gold)

            Text(emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Jot down what's on your mind. Every note lives on the day you wrote it.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("New Note", systemImage: "plus")
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white)
            .background(Theme.rose, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(28)
        .frame(maxWidth: 380)
        .paperPanel(cornerRadius: 4, tint: Theme.grass)
    }

    private var emptyTitle: String {
        switch selection {
        case .today: "Nothing on today yet"
        case .agenda: "Nothing on the agenda"
        default: "No notes here yet"
        }
    }
}
