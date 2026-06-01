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
            window.title = "Hatch"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.setContentSize(NSSize(width: 380, height: 320))
            window.minSize = NSSize(width: 340, height: 280)
            window.maxSize = NSSize(width: 520, height: 420)
            window.setFrameAutosaveName("Hatch.Bucket")
        case .library:
            window.title = "Hatch Library"
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.setFrameAutosaveName("Hatch.Library")
        }
    }
}
