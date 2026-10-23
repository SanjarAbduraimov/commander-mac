import AppKit
import CommanderController
import CommanderCore

@MainActor
final class MainWindowController: NSWindowController {
    let panes: PanesViewController

    init(model: WindowModel, sidebarWidth: Double) {
        panes = PanesViewController(model: model)

        let sidebar = NSViewController()
        sidebar.view = NSView()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 150
        sidebarItem.maximumThickness = 400

        let split = NSSplitViewController()
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(NSSplitViewItem(viewController: panes))

        let window = NSWindow(contentViewController: split)
        window.title = "Commander"
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.contentMinSize = NSSize(width: 800, height: 480)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        super.init(window: window)
        split.splitView.setPosition(CGFloat(sidebarWidth), ofDividerAt: 0)
        // Otherwise AppKit focuses the first editable view — the path field — and keys would edit the path.
        window.initialFirstResponder = pane(model.state.activeSide).table
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func pane(_ side: PaneSide) -> PaneViewController {
        side == .left ? panes.left : panes.right
    }
}
