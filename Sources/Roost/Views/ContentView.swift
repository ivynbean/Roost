import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel
    @State private var isDropTargeted = false
    @State private var quickCaptureText = ""

    var body: some View {
        HSplitView {
            SidebarView()
                .frame(minWidth: 176, idealWidth: 192, maxWidth: 220)

            VStack(spacing: 0) {
                QuickCaptureBar(text: $quickCaptureText)

                Divider()
                    .overlay(Theme.divider)

                RoostSearchField(
                    text: navigation.selection.isNotesDomain ? $noteStore.searchText : $store.searchText
                )

                Divider()
                    .overlay(Theme.divider)

                Group {
                    if navigation.selection.isNotesDomain {
                        NotesListView()
                    } else {
                        BookmarkListView()
                    }
                }
            }

            if shouldShowDetail {
                DetailView()
                    .frame(minWidth: 360, idealWidth: 440, maxWidth: 560)
                    .background(Theme.paper)
            }
        }
        .background(Theme.paper)
        .navigationTitle("Roost")
        .onDrop(of: BookmarkDropHandler.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            BookmarkDropHandler.handle(providers, store: store)
        }
    }

    private var shouldShowDetail: Bool {
        noteStore.selectedNoteID != nil || store.selectedBookmarkID != nil
    }
}

private struct RoostSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textTertiary)

            TextField("Search…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textTertiary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.paper)
    }
}

private struct QuickCaptureBar: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var navigation: NavigationModel
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 3)

                TextField("Write a note, paste a link, or drop a file…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($isFocused)
                    .onSubmit(capture)
                    .lineLimit(1...4)

                Button(action: capture) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Save")
            }

            Text("Plain text becomes a note. URLs and file paths become saved items.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 23)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card.opacity(0.48), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.paper)
    }

    private func capture() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if shouldCaptureAsBookmark(trimmed) || !navigation.selection.isNotesDomain {
            var projectID: UUID?
            var projectTagID: UUID?
            if case .project(let id) = navigation.selection {
                projectID = id
                projectTagID = noteStore.project(for: id)?.tagID
            }

            if let bookmark = store.add(rawValue: trimmed, projectID: projectID, projectTagID: projectTagID) {
                noteStore.selectedNoteID = nil
                store.selectedBookmarkID = bookmark.id
            }
            if !navigation.selection.isNotesDomain {
                navigation.selection = .collection(store.selectedCategory)
            }
        } else {
            store.selectedBookmarkID = nil
            var projectID: UUID?
            if case .project(let id) = navigation.selection {
                projectID = id
            }
            var tagIDs: [UUID] = []
            if case .tag(let id) = navigation.selection {
                tagIDs = [id]
            }
            let note = noteStore.addNote(
                projectID: projectID,
                date: navigation.selection == .today ? Date() : nil,
                isTask: navigation.selection == .tasks
            )
            noteStore.update(note.id) { draft in
                draft.title = trimmed.firstLine(maxLength: 80)
                draft.content = trimmed
                draft.tagIDs = tagIDs
            }
        }

        text = ""
        isFocused = true
    }

    private func shouldCaptureAsBookmark(_ value: String) -> Bool {
        if value.hasPrefix("http://") || value.hasPrefix("https://") || value.hasPrefix("file://") {
            return true
        }
        return FileManager.default.fileExists(atPath: NSString(string: value).expandingTildeInPath)
    }
}
