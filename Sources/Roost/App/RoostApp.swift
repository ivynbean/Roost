import AppKit
import SwiftUI

@main
struct RoostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BookmarkStore()
    @StateObject private var noteStore = NoteStore()
    @StateObject private var tagStore = TagStore()
    @StateObject private var navigation = NavigationModel()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var screenshotWatcher = ScreenshotWatcher()
    @AppStorage("roost.captureScreenshots") private var captureScreenshots = true

    var body: some Scene {
        WindowGroup("Roost Library", id: "library") {
            ContentView()
                .environmentObject(store)
                .environmentObject(noteStore)
                .environmentObject(tagStore)
                .environmentObject(navigation)
                .environmentObject(calendarService)
                .overlay {
                    StatusItemBootstrap(
                        appDelegate: appDelegate,
                        screenshotWatcher: screenshotWatcher
                    )
                    .environmentObject(store)
                }
                .frame(minWidth: 700, idealWidth: 1120, minHeight: 520, idealHeight: 720)
                .background(WindowConfigurator(style: .library))
                .tint(Theme.pink)
                .onAppear {
                    if captureScreenshots {
                        screenshotWatcher.start(store: store)
                    }
                }
        }

        WindowGroup("Roost", id: "bucket") {
            BucketWindowView()
                .environmentObject(store)
                .environmentObject(noteStore)
                .environmentObject(tagStore)
                .environmentObject(navigation)
                .environmentObject(calendarService)
                .frame(minWidth: 360, idealWidth: 420, minHeight: 230, idealHeight: 260)
                .background(WindowConfigurator(style: .bucket))
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
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarDropController()
    var openLibraryWindow: (() -> Void)?

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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        openLibraryWindow?()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

private struct StatusItemBootstrap: View {
    @EnvironmentObject private var store: BookmarkStore
    @Environment(\.openWindow) private var openWindow
    let appDelegate: AppDelegate
    let screenshotWatcher: ScreenshotWatcher

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                appDelegate.openLibraryWindow = {
                    openWindow(id: "library")
                }

                appDelegate.menuBarController.configure(
                    store: store,
                    screenshotWatcher: screenshotWatcher,
                    openBucket: {
                        openWindow(id: "bucket")
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    openLibrary: {
                        openWindow(id: "library")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                )
            }
    }
}
