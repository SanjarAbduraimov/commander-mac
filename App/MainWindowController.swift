import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Commander"
        window.contentMinSize = NSSize(width: 800, height: 480)
        window.contentViewController = NSViewController()
        window.contentViewController?.view = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 700))
        window.center()
        window.setFrameAutosaveName("MainWindow")
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}
