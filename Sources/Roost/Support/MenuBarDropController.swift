import AppKit
import Foundation

@MainActor
final class MenuBarDropController: NSObject {
    enum CatchBoxSize: String {
        case compact
        case roomy
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusView = MenuBarDropView(frame: NSRect(x: 0, y: 0, width: 28, height: 24))
    private weak var store: BookmarkStore?
    private weak var screenshotWatcher: ScreenshotWatcher?
    private var openBucket: (() -> Void)?
    private var openLibrary: (() -> Void)?

    func configure(
        store: BookmarkStore,
        screenshotWatcher: ScreenshotWatcher,
        openBucket: @escaping () -> Void,
        openLibrary: @escaping () -> Void
    ) {
        self.store = store
        self.screenshotWatcher = screenshotWatcher
        self.openBucket = openBucket
        self.openLibrary = openLibrary

        if statusItem.view !== statusView {
            statusItem.view = statusView
            statusView.controller = self
            statusView.toolTip = "Roost"
        }

        statusView.icon = RoostImage.menuBarNSImage()
    }

    func handleLeftClick() {
        presentMenu()
    }

    func handleRightClick() {
        presentMenu()
    }

    private func presentMenu() {
        let menu = NSMenu()

        let openCatchBox = NSMenuItem(title: "Open Catch Box", action: #selector(openCatchBoxAction), keyEquivalent: "")
        openCatchBox.target = self
        menu.addItem(openCatchBox)

        let openLibrary = NSMenuItem(title: "Open Library", action: #selector(openLibraryAction), keyEquivalent: "")
        openLibrary.target = self
        menu.addItem(openLibrary)

        menu.addItem(.separator())

        let saveClipboard = NSMenuItem(title: "Save Clipboard", action: #selector(saveClipboardAction), keyEquivalent: "")
        saveClipboard.target = self
        menu.addItem(saveClipboard)

        let captureScreenshots = NSMenuItem(title: "Capture Screenshots", action: #selector(toggleCaptureScreenshots), keyEquivalent: "")
        captureScreenshots.target = self
        captureScreenshots.state = screenshotsEnabled ? .on : .off
        menu.addItem(captureScreenshots)

        let sizeMenuItem = NSMenuItem(title: "Catch Box Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = catchBoxSizeMenu()
        menu.addItem(sizeMenuItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Roost", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        let popupPoint = NSPoint(x: 0, y: statusView.bounds.maxY + 4)
        menu.popUp(positioning: nil, at: popupPoint, in: statusView)
    }

    func handleDrop(pasteboard: NSPasteboard) -> Bool {
        guard let store else { return false }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            for url in urls {
                _ = store.add(url: url)
            }
            return true
        }

        for type in [NSPasteboard.PasteboardType.fileURL, .URL, .string] {
            if let raw = pasteboard.string(forType: type)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                _ = store.add(rawValue: raw)
                return true
            }
        }

        return false
    }

    private var screenshotsEnabled: Bool {
        UserDefaults.standard.object(forKey: "roost.captureScreenshots") as? Bool ?? false
    }

    private var catchBoxSize: CatchBoxSize {
        CatchBoxSize(rawValue: UserDefaults.standard.string(forKey: "roost.catchBoxSize") ?? "") ?? .compact
    }

    private func catchBoxSizeMenu() -> NSMenu {
        let menu = NSMenu()
        let compact = NSMenuItem(title: "Compact", action: #selector(setCatchBoxCompact), keyEquivalent: "")
        compact.target = self
        compact.state = catchBoxSize == .compact ? .on : .off
        menu.addItem(compact)

        let roomy = NSMenuItem(title: "Roomy", action: #selector(setCatchBoxRoomy), keyEquivalent: "")
        roomy.target = self
        roomy.state = catchBoxSize == .roomy ? .on : .off
        menu.addItem(roomy)
        return menu
    }

    @objc private func openCatchBoxAction() {
        openBucket?()
    }

    @objc private func openLibraryAction() {
        openLibrary?()
    }

    @objc private func saveClipboardAction() {
        store?.captureClipboard()
    }

    @objc private func toggleCaptureScreenshots() {
        let enabled = !screenshotsEnabled
        UserDefaults.standard.set(enabled, forKey: "roost.captureScreenshots")

        guard let store, let screenshotWatcher else { return }
        if enabled {
            screenshotWatcher.start(store: store)
        } else {
            screenshotWatcher.stop()
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    @objc private func setCatchBoxCompact() {
        UserDefaults.standard.set(CatchBoxSize.compact.rawValue, forKey: "roost.catchBoxSize")
    }

    @objc private func setCatchBoxRoomy() {
        UserDefaults.standard.set(CatchBoxSize.roomy.rawValue, forKey: "roost.catchBoxSize")
    }
}

private final class MenuBarDropView: NSView {
    weak var controller: MenuBarDropController?
    var icon: NSImage? {
        didSet { needsDisplay = true }
    }

    private var isDropTargeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 28, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isDropTargeted {
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6).fill()
        }

        if let icon {
            let targetRect = bounds.insetBy(dx: 5, dy: 3)
            icon.draw(in: targetRect)
        }
    }

    override func mouseDown(with event: NSEvent) {
        controller?.handleLeftClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        controller?.handleRightClick()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDropTargeted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let didHandle = controller?.handleDrop(pasteboard: sender.draggingPasteboard) ?? false
        isDropTargeted = false
        return didHandle
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isDropTargeted = false
    }
}
