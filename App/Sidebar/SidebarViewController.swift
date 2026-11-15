import AppKit
import CommanderController
import CommanderCore
import CommanderFileSystem

@MainActor
final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
    /// NSOutlineView keys rows by object identity, so items are reference types rebuilt on every reload.
    private final class Node: NSObject {
        enum Kind {
            case group(String)
            case favorite(URL, index: Int)
            case volume(VolumeInfo)
        }

        let kind: Kind
        var children: [Node] = []

        init(_ kind: Kind) {
            self.kind = kind
        }

        var url: URL? {
            switch kind {
            case .group: nil
            case let .favorite(url, _): url
            case let .volume(volume): volume.url
            }
        }
    }

    private let model: WindowModel
    private let outline = NSOutlineView()
    private var groups: [Node] = []

    init(model: WindowModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .followsWindowActiveState

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("place"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.style = .sourceList
        outline.floatsGroupRows = false
        outline.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outline.autoresizesOutlineColumn = true
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.action = #selector(rowClicked)
        outline.registerForDraggedTypes([.fileURL])
        outline.setAccessibilityIdentifier("sidebar")
        let menu = NSMenu()
        menu.delegate = self
        outline.menu = menu

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true

        visualEffect.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])

        view = visualEffect
        reload()
    }

    func reload() {
        let favorites = Node(.group("Favorites"))
        favorites.children = model.sidebar.favorites.enumerated().map { Node(.favorite($1, index: $0)) }
        let locations = Node(.group("Locations"))
        locations.children = model.sidebar.volumes.map { Node(.volume($0)) }
        groups = [favorites, locations]
        outline.reloadData()
        groups.forEach { outline.expandItem($0) }
    }

    // MARK: Data source and delegate

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? Node)?.children.count ?? groups.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? Node)?.children[index] ?? groups[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? Node)?.children.isEmpty ?? true)
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if case .group = (item as? Node)?.kind { return true }
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if case .volume = (item as? Node)?.kind { return 36 }
        return 24
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? Node else { return nil }
        switch node.kind {
        case let .group(title):
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            return label
        case let .favorite(url, _):
            return placeCell(icon: NSWorkspace.shared.icon(forFile: url.path), name: FileManager.default.displayName(atPath: url.path), detail: nil, volume: nil)
        case let .volume(volume):
            return placeCell(icon: NSWorkspace.shared.icon(forFile: volume.url.path), name: volume.name,
                             detail: SidebarModel.capacityText(volume), volume: volume.isEjectable || volume.isNetwork ? volume : nil)
        }
    }

    @objc private func rowClicked() {
        guard let node = outline.item(atRow: outline.clickedRow) as? Node, let url = node.url else { return }
        model.openPlace(url)
    }

    // MARK: Favorites: remove and drop

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let node = outline.item(atRow: outline.clickedRow) as? Node, case let .favorite(_, index) = node.kind else { return }
        let remove = NSMenuItem(title: "Remove from Sidebar", action: #selector(removeFavorite(_:)), keyEquivalent: "")
        remove.target = self
        remove.tag = index
        menu.addItem(remove)
    }

    @objc private func removeFavorite(_ sender: NSMenuItem) {
        model.sidebar.removeFavorite(at: sender.tag)
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let target = dropIndex(item: item, childIndex: index), Self.droppedFolder(info) != nil else { return [] }
        outlineView.setDropItem(groups[0], dropChildIndex: target)
        return .link
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let folder = Self.droppedFolder(info), let target = dropIndex(item: item, childIndex: index) else { return false }
        return model.sidebar.addFavorite(folder, at: target)
    }

    /// Only the Favorites group takes drops; dropping on a favorite inserts before it.
    private func dropIndex(item: Any?, childIndex: Int) -> Int? {
        guard let node = item as? Node else { return nil }
        switch node.kind {
        case .group where node === groups.first: return childIndex < 0 ? node.children.count : childIndex
        case let .favorite(_, index): return index
        default: return nil
        }
    }

    private static func droppedFolder(_ info: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let url = (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first else { return nil }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue ? url : nil
    }

    // MARK: Cells

    private func placeCell(icon: NSImage, name: String, detail: String?, volume: VolumeInfo?) -> NSView {
        let image = NSImageView(image: icon)
        image.widthAnchor.constraint(equalToConstant: 16).isActive = true
        image.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let title = NSTextField(labelWithString: name)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let text = NSStackView(views: [title])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0
        if let detail {
            let subtitle = NSTextField(labelWithString: detail)
            subtitle.font = .systemFont(ofSize: 10)
            subtitle.textColor = .secondaryLabelColor
            text.addArrangedSubview(subtitle)
        }
        let row = NSStackView(views: [image, text])
        row.orientation = .horizontal
        row.spacing = 6
        if let volume {
            row.addArrangedSubview(NSView())
            let eject = EjectButton(volume: volume) { [model] volume in Task { await model.eject(volume) } }
            row.addArrangedSubview(eject)
        }
        return row
    }
}

@MainActor
private final class EjectButton: NSButton {
    private let volume: VolumeInfo
    private let onEject: (VolumeInfo) -> Void

    init(volume: VolumeInfo, onEject: @escaping (VolumeInfo) -> Void) {
        self.volume = volume
        self.onEject = onEject
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: "eject.fill", accessibilityDescription: "Eject \(volume.name)")
        isBordered = false
        target = self
        action = #selector(pressed)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func pressed() {
        onEject(volume)
    }
}
