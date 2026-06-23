import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BookmarkStore
    @EnvironmentObject private var calendarService: CalendarService
    @EnvironmentObject private var screenshotWatcher: ScreenshotWatcher
    @AppStorage("roost.showCalendarInToday") private var showCalendar = true
    @AppStorage("roost.captureScreenshots") private var captureScreenshots = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Storage") {
                    Text("Application Support / Roost")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Collections") {
                    Text("Files and links keep the bucket you choose")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Screenshots") {
                Toggle("Save new screenshots to Roost", isOn: $captureScreenshots)
                    .onChange(of: captureScreenshots) { _, enabled in
                        if enabled {
                            screenshotWatcher.start(store: store)
                        } else {
                            screenshotWatcher.stop()
                        }
                    }

                Text("Every screenshot you take with ⇧⌘3/4/5 lands in the Screenshots collection automatically, wherever it's saved on disk. Screenshots taken before Roost was running are never imported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Calendar") {
                Toggle("Show calendar events in Today", isOn: $showCalendar)

                LabeledContent("Access") {
                    switch calendarService.accessState {
                    case .authorized:
                        Text("Connected (read-only)")
                            .foregroundStyle(.secondary)
                    case .denied:
                        Text("Denied — enable in System Settings → Privacy")
                            .foregroundStyle(.secondary)
                    case .notDetermined:
                        Button("Connect Calendar") {
                            calendarService.connect()
                        }
                    }
                }

                Text("Roost keeps everything on this Mac. The calendar connection only reads events to show them beside your notes — nothing is uploaded or written back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
    }
}
