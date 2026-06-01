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
            window.title = "BucketDesk"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.setContentSize(NSSize(width: 360, height: 290))
            window.minSize = NSSize(width: 320, height: 250)
            window.maxSize = NSSize(width: 480, height: 380)
            window.setFrameAutosaveName("BucketDesk.Bucket")
        case .library:
            window.title = "Bookmark Library"
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.setFrameAutosaveName("BucketDesk.Library")
        }
    }
}
