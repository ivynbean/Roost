import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    enum Style {
        case bucket
        case library
    }

    let style: Style

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.level = .floating
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        window.isMovableByWindowBackground = true

        switch style {
        case .bucket:
            window.title = "Roost"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
            window.hasShadow = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            if window.frameAutosaveName != "Roost.Bucket" {
                window.setContentSize(NSSize(width: 420, height: 260))
            }
            window.minSize = NSSize(width: 360, height: 230)
            window.maxSize = NSSize(width: 560, height: 360)
            window.setFrameAutosaveName("Roost.Bucket")
        case .library:
            window.title = "Roost Library"
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.minSize = NSSize(width: 760, height: 520)
            window.setFrameAutosaveName("Roost.Library")
        }
    }
}
