import AppKit
import SwiftUI

@main
struct BucketDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BookmarkStore()

    var body: some Scene {
        WindowGroup("BucketDesk", id: "bucket") {
            BucketWindowView()
                .environmentObject(store)
                .frame(width: 360, height: 290)
                .background(WindowConfigurator(style: .bucket))
        }

        WindowGroup("Bookmark Library", id: "library") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 600)
                .background(WindowConfigurator(style: .library))
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Grab Clipboard") {
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
