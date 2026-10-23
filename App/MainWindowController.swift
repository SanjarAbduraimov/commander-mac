import AppKit
import SwiftUI
import CommanderController
import CommanderCore

@MainActor
final class MainWindowController: NSWindowController {
    let panes: PanesViewController
    let sidebar: SidebarViewController
    private let model: WindowModel
    private var resizeObserver: NSObjectProtocol?

    init(model: WindowModel, sidebarWidth: Double) {
        self.model = model
        panes = PanesViewController(model: model)
        sidebar = SidebarViewController(model: model)

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
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification, object: split.splitView, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let width = self.sidebar.viewIfLoaded?.frame.width, width > 0 else { return }
                self.model.setSidebarWidth(Double(width))
            }
        }
    }

    func showConnectToServer() {
        guard let content = window?.contentViewController else { return }
        var sheet: NSViewController?
        let view = ConnectToServerView(
            recentServers: model.recentServers,
            onConnect: { [model] address in
                if let sheet { content.dismiss(sheet) }
                Task { await model.connect(to: address) }
            },
            onCancel: { if let sheet { content.dismiss(sheet) } }
        )
        let hosting = NSHostingController(rootView: view)
        sheet = hosting
        content.presentAsSheet(hosting)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    var activeSide: PaneSide { panes.left.model.state.activeSide }

    func pane(_ side: PaneSide) -> PaneViewController {
        side == .left ? panes.left : panes.right
    }
}
