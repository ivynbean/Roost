import AppKit
import SwiftUI

@main
struct RoostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BookmarkStore()

    var body: some Scene {
        WindowGroup("Roost", id: "bucket") {
            BucketWindowView()
                .environmentObject(store)
                .frame(minWidth: 360, idealWidth: 420, minHeight: 230, idealHeight: 260)
                .background(WindowConfigurator(style: .bucket))
                .tint(Theme.pink)
        }

        WindowGroup("Roost Library", id: "library") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 760, idealWidth: 1120, minHeight: 520, idealHeight: 720)
                .background(WindowConfigurator(style: .library))
                .tint(Theme.pink)
        }
        .commands {
            CommandGroup(after: .newItem) {
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
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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
