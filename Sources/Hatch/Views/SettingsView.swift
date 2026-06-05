import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        Form {
            LabeledContent("Storage") {
                Text("Application Support / Stash")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Sorter") {
                Text("Local scoring now, model-ready later")
                    .foregroundStyle(.secondary)
            }

            Button("Tidy Up Everything") {
                store.autoSortAll()
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
