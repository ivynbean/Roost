import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BookmarkStore

    var body: some View {
        Form {
            LabeledContent("Storage") {
                Text("Application Support / BucketDesk")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Sorter") {
                Text("Local rules now, model-ready later")
                    .foregroundStyle(.secondary)
            }

            Button("Auto Sort All Bookmarks") {
                store.autoSortAll()
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
