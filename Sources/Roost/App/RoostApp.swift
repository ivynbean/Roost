import AppKit
import SwiftUI

@main
struct RoostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BookmarkStore()
    @StateObject private var noteStore = NoteStore()
    @StateObject private var navigation = NavigationModel()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var screenshotWatcher = ScreenshotWatcher()
    @AppStorage("roost.captureScreenshots") private var captureScreenshots = true

    var body: some Scene {
        WindowGroup("Roost", id: "bucket") {
            BucketWindowView()
                .environmentObject(store)
                .environmentObject(noteStore)
                .environmentObject(navigation)
                .environmentObject(calendarService)
                .frame(minWidth: 360, idealWidth: 420, minHeight: 230, idealHeight: 260)
                .background(WindowConfigurator(style: .bucket))
                .tint(Theme.pink)
                .onAppear {
                    if captureScreenshots {
                        screenshotWatcher.start(store: store)
                    }
                }
        }

        WindowGroup("Roost Library", id: "library") {
            ContentView()
                .environmentObject(store)
                .environmentObject(noteStore)
                .environmentObject(navigation)
                .environmentObject(calendarService)
                .frame(minWidth: 760, idealWidth: 1120, minHeight: 520, idealHeight: 720)
                .background(WindowConfigurator(style: .library))
                .tint(Theme.pink)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Note") {
                    var projectID: UUID?
                    if case .project(let id) = navigation.selection {
                        projectID = id
                    }
                    if !navigation.selection.isNotesDomain {
                        navigation.selection = .today
                    }
                    noteStore.addNote(projectID: projectID, date: navigation.selection == .today ? Date() : nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Save Clipboard") {
                    store.captureClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Auto Sort All") {
                    store.autoSortAll()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Open Selected") {
                    store.openSelected()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(calendarService)
                .environmentObject(screenshotWatcher)
        }

        MenuBarExtra {
            StatusMenuView(screenshotWatcher: screenshotWatcher)
                .environmentObject(store)
        } label: {
            if let icon = RoostImage.menuBarNSImage() {
                Image(nsImage: icon)
            } else {
                Image(systemName: "tray.and.arrow.down.fill")
            }
        }
    }
}

private struct StatusMenuView: View {
    @EnvironmentObject private var store: BookmarkStore
    @Environment(\.openWindow) private var openWindow
    @AppStorage("roost.captureScreenshots") private var captureScreenshots = true
    let screenshotWatcher: ScreenshotWatcher

    var body: some View {
        Button("Open Catch Box") {
            openWindow(id: "bucket")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Open Library") {
            openWindow(id: "library")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Save Clipboard") {
            store.captureClipboard()
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])

        Toggle("Capture Screenshots", isOn: Binding(
            get: { captureScreenshots },
            set: { enabled in
                captureScreenshots = enabled
                if enabled {
                    screenshotWatcher.start(store: store)
                } else {
                    screenshotWatcher.stop()
                }
            }
        ))

        Divider()

        Button("Quit Roost") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Roost palette is light paper tones; pin the light appearance so
        // system chrome (toolbar title, search field, menus) stays readable
        // when macOS is in dark mode.
        NSApp.appearance = NSAppearance(named: .aqua)
        RoostFontRegistrar.registerFonts()
        if let appIcon = RoostImage.nsImage() {
            NSApp.applicationIconImage = appIcon
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
