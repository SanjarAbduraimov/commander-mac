import AppKit
import SwiftUI
import CommanderController
import CommanderCore

@MainActor
final class MainWindowController: NSWindowController {
    let panes: PanesViewController
    let sidebar: SidebarViewController
    let model: WindowModel
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

        NSWindow.allowsAutomaticWindowTabbing = false
        let window = NSWindow(contentViewController: split)
        window.tabbingMode = .disallowed
        window.title = "Commander"
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.contentMinSize = NSSize(width: 800, height: 480)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        super.init(window: window)
        panes.footer.onOpenTransferManager = { [weak self] in
            self?.showTransferManager()
        }
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

    func showAppChooser(for urls: [URL]) {
        guard let window else { return }
        AppChooserPresenter.show(for: urls, model: model, over: window)
    }

    func showTransferManager() {
        guard let window else { return }
        TransferManagerPresenter.show(model: model, over: window)
    }

    func showQuickLook(for urls: [URL]) {
        QuickLookPresenter.shared.show(for: urls)
    }

    func pasteImageFromClipboard(side: PaneSide) {
        let pasteboard = NSPasteboard.general
        var image: NSImage? = NSImage(pasteboard: pasteboard)
        if image == nil {
            let types = [
                NSPasteboard.PasteboardType.png,
                NSPasteboard.PasteboardType.tiff,
                NSPasteboard.PasteboardType("public.png"),
                NSPasteboard.PasteboardType("public.jpeg"),
                NSPasteboard.PasteboardType("public.tiff"),
            ]
            for type in types {
                if let data = pasteboard.data(forType: type), let img = NSImage(data: data) {
                    image = img
                    break
                }
            }
        }
        guard let validImage = image else { return }
        let targetDirectory = pane(side).model.tab(side).path
        guard let window else { return }
        if model.settings.clipboard.confirmPasteImage {
            ImagePastePresenter.show(image: validImage, targetDirectory: targetDirectory, model: model, side: side, over: window)
        } else {
            let pattern = model.settings.clipboard.imageNamingPattern
            let format = model.settings.clipboard.defaultImageFormat
            let formatter = DateFormatter()
            formatter.dateFormat = pattern.isEmpty ? "yyyy-MM-dd_HHmmss" : pattern
            let fileName = "Image_\(formatter.string(from: Date())).\(format)"
            ImagePastePresenter.saveImage(validImage, named: fileName, format: format, to: targetDirectory, model: model, side: side)
        }
    }

    func shareToTelegram(urls: [URL]) {
        TelegramSharing.share(urls: urls, from: window?.contentView)
    }

    @objc func toggleSidebarAction() {
        guard let split = window?.contentViewController as? NSSplitViewController else { return }
        guard let sidebarItem = split.splitViewItems.first else { return }
        let currentWidth = sidebar.viewIfLoaded?.frame.width ?? 0
        if sidebarItem.isCollapsed || currentWidth < 50 {
            sidebarItem.isCollapsed = false
            let targetWidth = max(CGFloat(model.sidebarWidth), 180)
            split.splitView.setPosition(targetWidth, ofDividerAt: 0)
        } else {
            sidebarItem.isCollapsed = true
        }
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
