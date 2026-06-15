import Foundation

enum SidebarSelection: Hashable {
    case today
    case agenda
    case tasks
    case allNotes
    case project(UUID)
    case tag(UUID)
    case collection(BookmarkCategory)

    var isNotesDomain: Bool {
        if case .collection = self { return false }
        return true
    }
}

final class NavigationModel: ObservableObject {
    @Published var selection: SidebarSelection = .today
}
