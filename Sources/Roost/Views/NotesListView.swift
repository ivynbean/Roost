import SwiftUI

struct NotesListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel
    @EnvironmentObject private var calendarService: CalendarService
    @AppStorage("roost.showCalendarInToday") private var showCalendar = true

    private var showsCalendarStrip: Bool {
        navigation.selection == .today && showCalendar
    }

    var body: some View {
        Group {
            if groupedNotes.isEmpty {
                VStack(spacing: 0) {
                    if showsCalendarStrip {
                        TodayCalendarStrip()
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 16)

                    EmptyNotesView(selection: navigation.selection) {
                        addNote()
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if showsCalendarStrip {
                            TodayCalendarStrip()
                                .padding(.bottom, 8)
                        }

                        ForEach(groupedNotes, id: \.day) { group in
                            Section {
                                ForEach(group.notes) { note in
                                    NoteRow(note: note, isSelected: note.id == noteStore.selectedNoteID)
                                        .contextMenu {
                                            Button(note.isOnAgenda ? "Remove from Agenda" : "Put on the Agenda") {
                                                noteStore.toggleAgenda(note.id)
                                            }
                                            Button(note.isDone ? "Mark Not Done" : "Mark Done") {
                                                noteStore.toggleDone(note.id)
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
                            } header: {
                                HStack(spacing: 8) {
                                    Text(dayLabel(for: group.day))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Rectangle()
                                        .fill(Theme.wood.opacity(0.25))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 12)
                                .padding(.bottom, 2)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(PaintedBackdrop())
        .navigationTitle(listTitle)
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .help("New Note")
            }
        }
    }

    private var listTitle: String {
        switch navigation.selection {
        case .today: "Today"
        case .agenda: "On the Agenda"
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
        var projectID: UUID?
        if case .project(let id) = navigation.selection {
            projectID = id
        }
        let date: Date? = navigation.selection == .today ? Date() : nil
        let note = noteStore.addNote(projectID: projectID, date: date)
        if navigation.selection == .agenda {
            noteStore.toggleAgenda(note.id)
        }
    }
}

private struct NoteRow: View {
    @EnvironmentObject private var noteStore: NoteStore
    let note: Note
    let isSelected: Bool

    var body: some View {
        Button {
            noteStore.selectedNoteID = note.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    noteStore.toggleDone(note.id)
                } label: {
                    Image(systemName: note.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(note.isDone ? Theme.moss : (isSelected ? Color.white.opacity(0.85) : Theme.textTertiary))
                }
                .buttonStyle(.plain)
                .help(note.isDone ? "Mark not done" : "Mark done")
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.displayTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                        .strikethrough(note.isDone, color: Theme.ink.opacity(0.5))
                        .lineLimit(1)

                    if !note.content.isEmpty {
                        Text(note.content.firstLine(maxLength: 90))
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Theme.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        if let project = noteStore.project(for: note.projectID) {
                            Label(project.name, systemImage: project.symbolName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? Theme.pink : Color.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    isSelected ? Color.white : Theme.projectColor(project.colorIndex),
                                    in: Capsule()
                                )
                        }

                        if note.date != nil {
                            Label(shortDate(note.timelineDate), systemImage: "calendar")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Theme.textSecondary)
                        }

                        if !note.linkedBookmarkIDs.isEmpty {
                            Label("\(note.linkedBookmarkIDs.count)", systemImage: "link")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Theme.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 10)

                Button {
                    noteStore.toggleAgenda(note.id)
                } label: {
                    Image(systemName: note.isOnAgenda ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(note.isOnAgenda ? Theme.gold : (isSelected ? Color.white.opacity(0.8) : Theme.textTertiary))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(note.isOnAgenda ? "Remove from agenda" : "Put on the agenda")
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.pink : Theme.card)
                    .shadow(color: Theme.ink.opacity(isSelected ? 0.18 : 0.07), radius: 5, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Theme.pink : Theme.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
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
        .paperPanel(cornerRadius: 10, tint: Theme.moss)
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
            Text("Jot down what's on your mind — every note lives on the day you wrote it.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("New Note", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: 380)
        .paperPanel(cornerRadius: 12, tint: Theme.grass)
    }

    private var emptyTitle: String {
        switch selection {
        case .today: "Nothing on today yet"
        case .agenda: "Nothing on the agenda"
        default: "No notes here yet"
        }
    }
}
