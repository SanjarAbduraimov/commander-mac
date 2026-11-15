import AppKit
import SwiftUI
import CommanderController
import CommanderCore

/// Modern macOS 15 delicate sidebar divider.
/// Replaces the harsh black divider with a subtle, translucent hairline separator.
final class ModernSidebarSplitView: NSSplitView {
    override var dividerThickness: CGFloat { 1 }

    override func drawDivider(in rect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.separatorColor.withAlphaComponent(0.35).setFill()
            rect.fill()
        }
    }
}

final class MainSplitViewController: NSSplitViewController {
    override func loadView() {
        let custom = ModernSidebarSplitView()
        custom.isVertical = true
        custom.dividerStyle = .thin
        self.splitView = custom
        self.view = custom
    }
}

@MainActor
final class MainWindowController: NSWindowController {
    let panes: PanesViewController
    let sidebar: SidebarViewController
    let split: NSSplitViewController
    let headerBar: TopHeaderBarView
    let model: WindowModel
    private var resizeObserver: NSObjectProtocol?
    private var clickObserver: Any?

    init(model: WindowModel, sidebarWidth: Double) {
        self.model = model
        panes = PanesViewController(model: model)
        sidebar = SidebarViewController(model: model)
        headerBar = TopHeaderBarView()

        let sidebarItem = NSSplitViewItem(viewController: sidebar)
        sidebarItem.minimumThickness = 110
        sidebarItem.maximumThickness = 650
        sidebarItem.canCollapse = true
        sidebarItem.holdingPriority = .defaultHigh

        let panesItem = NSSplitViewItem(viewController: panes)
        panesItem.holdingPriority = .defaultLow

        split = MainSplitViewController()
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(panesItem)

        let rootController = NSViewController()
        let rootView = NSView()
        rootController.view = rootView
        rootController.addChild(split)

        headerBar.translatesAutoresizingMaskIntoConstraints = false
        split.view.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(headerBar)
        rootView.addSubview(split.view)

        NSLayoutConstraint.activate([
            headerBar.heightAnchor.constraint(equalToConstant: 40),
            headerBar.topAnchor.constraint(equalTo: rootView.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            split.view.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            split.view.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            split.view.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            split.view.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])

        NSWindow.allowsAutomaticWindowTabbing = false
        let window = NSWindow(contentViewController: rootController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.tabbingMode = .disallowed
        window.title = "Commander"
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.contentMinSize = NSSize(width: 800, height: 480)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary, .participatesInCycle]
        window.center()
        window.setFrameAutosaveName("MainWindow")

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let frame = window.frame
            if !visible.intersects(frame) || frame.width < 400 || frame.height < 300 {
                window.setFrame(NSRect(
                    x: max(visible.minX + 50, visible.midX - 550),
                    y: max(visible.minY + 50, visible.midY - 350),
                    width: min(1100, visible.width - 100),
                    height: min(700, visible.height - 100)
                ), display: true)
            }
        }

        super.init(window: window)

        headerBar.onToggleSidebar = { [weak self] in
            self?.toggleSidebarAction()
        }
        headerBar.onBack = { [model] in
            model.perform(.goBack)
        }
        headerBar.onForward = { [model] in
            model.perform(.goForward)
        }
        headerBar.onToggleQuickView = { [model] in
            model.perform(.toggleQuickView)
        }
        headerBar.onOpenSettings = { [model] in
            model.perform(.openSettings)
        }

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
                guard let self else { return }
                let sidebarItem = self.split.splitViewItems.first
                guard !(sidebarItem?.isCollapsed ?? false) else { return }
                guard let width = self.sidebar.viewIfLoaded?.frame.width, width >= 80 else { return }
                self.model.setSidebarWidth(Double(width))
                self.updateHeaderBarState()
            }
        }
        clickObserver = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let window = self.window, event.window === window else { return }
                for side in [PaneSide.left, .right] {
                    let p = self.pane(side)
                    if !p.pathField.isHidden {
                        let clickPoint = event.locationInWindow
                        let containerRect = p.pathField.superview?.convert(p.pathField.superview?.bounds ?? .zero, to: nil) ?? .zero
                        if !containerRect.contains(clickPoint) {
                            window.makeFirstResponder(p.table)
                        }
                    }
                }
            }
            return event
        }
        updateHeaderBarState()
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
        guard let sidebarItem = split.splitViewItems.first else { return }
        if sidebarItem.isCollapsed {
            sidebarItem.isCollapsed = false
            let targetWidth = max(CGFloat(model.sidebarWidth), 180)
            DispatchQueue.main.async { [weak self] in
                self?.split.splitView.setPosition(targetWidth, ofDividerAt: 0)
            }
        } else {
            sidebarItem.isCollapsed = true
        }
        updateHeaderBarState()
    }

    func updateHeaderBarState() {
        let activeTab = model.tab(model.state.activeSide)
        headerBar.canGoBack = activeTab.canGoBack
        headerBar.canGoForward = activeTab.canGoForward

        let sidebarItem = split.splitViewItems.first
        let isCollapsed = (sidebarItem?.isCollapsed ?? false) || (sidebar.viewIfLoaded?.frame.width ?? 0) < 50
        headerBar.isSidebarCollapsed = isCollapsed

        headerBar.isQuickViewActive = model.quickViewSide != nil
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
