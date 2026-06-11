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
        window.isMovableByWindowBackground = true

        switch style {
        case .bucket:
            window.level = .floating
            window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            window.title = "Roost"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
            window.hasShadow = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            let size = bucketSize
            if window.frameAutosaveName != "Roost.Bucket" {
                window.setContentSize(size.defaultSize)
            }
            window.minSize = size.minSize
            window.maxSize = size.maxSize
            window.setFrameAutosaveName("Roost.Bucket")
        case .library:
            window.level = .normal
            window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
            window.title = "Roost Library"
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.minSize = NSSize(width: 760, height: 520)
            window.setFrameAutosaveName("Roost.Library")
        }
    }

    private var bucketSize: BucketWindowSize {
        BucketWindowSize(rawValue: UserDefaults.standard.string(forKey: "roost.catchBoxSize") ?? "") ?? .compact
    }
}

private enum BucketWindowSize: String {
    case compact
    case roomy

    var minSize: NSSize {
        switch self {
        case .compact: NSSize(width: 360, height: 230)
        case .roomy: NSSize(width: 440, height: 280)
        }
    }

    var maxSize: NSSize {
        switch self {
        case .compact: NSSize(width: 560, height: 360)
        case .roomy: NSSize(width: 700, height: 460)
        }
    }

    var defaultSize: NSSize {
        switch self {
        case .compact: NSSize(width: 420, height: 260)
        case .roomy: NSSize(width: 560, height: 340)
        }
    }
}
