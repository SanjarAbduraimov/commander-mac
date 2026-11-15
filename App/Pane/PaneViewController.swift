import AppKit
import CommanderController
import CommanderCore
import os

@MainActor
final class PaneViewController: NSViewController, NSTextFieldDelegate, NSDraggingSource {
    private static let signposter = OSSignposter(subsystem: "local.sanjar.commander", category: .pointsOfInterest)

    let model: WindowModel
    let side: PaneSide
    let table = FileTableView()
    let pathField = NSTextField()

    private let tableController: FileTableController
    private lazy var renameEditor = RenameEditor(model: model, side: side, table: table)
    private lazy var breadcrumbs = BreadcrumbBar(model: model, side: side)
    private let parentStrip = ParentDropStrip(frame: .zero)
    private var parentStripHide: Task<Void, Never>?
    private let tabBar = TabBarView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let activeLine = NSBox()
    private let scrollView = NSScrollView()
    private let banner = AccessBannerView()

    /// What the table currently shows, to reload only the rows a change touched.
    private var shownNames: [String] = []
    private var shownCursor: String?
    private var shownPath: URL?
    private var shownMarked: Set<String> = []
    private var shownActive = false
    private var shownAppearance: AppearanceSettings?
    private var shownFolderSizes: [String: Int64] = [:]
    private var shownCut: Set<String> = []

    init(model: WindowModel, side: PaneSide) {
        self.model = model
        self.side = side
        tableController = FileTableController(model: model, side: side)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        let root = NSView()
        root.setAccessibilityElement(true)
        root.setAccessibilityRole(.group)
        root.setAccessibilityIdentifier("pane.\(side.rawValue)")

        activeLine.boxType = .custom
        activeLine.borderWidth = 0
        activeLine.fillColor = Palette.accent

        tabBar.onSelect = { [model, side] in model.selectTab(side, at: $0) }
        tabBar.onClose = { [model, side] in model.closeTab(side, at: $0) }
        tabBar.onAdd = { [model, side] in
            model.activate(side)
            model.perform(.newTab)
        }
        tabBar.model = model
        tabBar.dropDestination = { [model, side] in model.tabPath(side, at: $0) }
        tabBar.onSpringLoad = { [model, side] in model.springLoadTab(side, at: $0) }

        breadcrumbs.onEdit = { [weak self] in self?.focusPathField() }
        parentStrip.model = model
        parentStrip.destination = { [model, side] in
            let path = model.tab(side).path
            return path.path == "/" ? nil : path.deletingLastPathComponent()
        }
        parentStrip.onSpringLoad = { [model, side] in model.springLoadParent(side) }
        parentStrip.onDragHover = { [weak self] in self?.dragHover($0) }

        pathField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathField.isBordered = false
        pathField.drawsBackground = false
        pathField.lineBreakMode = .byTruncatingHead
        pathField.setAccessibilityIdentifier("pathEdit.\(side.rawValue)")
        pathField.delegate = self
        pathField.isHidden = true

        table.side = side
        table.model = model
        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = false
        table.selectionHighlightStyle = .none
        table.allowsTypeSelect = false
        table.allowsColumnReordering = true
        table.intercellSpacing = NSSize(width: 0, height: 0)
        // Only Name has an autoresizing mask, so it alone grows and shrinks with the pane.
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.setAccessibilityIdentifier("table.\(side.rawValue)")
        tableController.applyColumns(to: table)
        table.headerView?.menu = tableController.headerMenu()
        table.dataSource = tableController
        table.delegate = tableController
        table.registerForDraggedTypes([.fileURL])
        table.onBeginDrag = { [weak self] row, event in self?.beginDrag(row: row, event: event) }
        table.onDragExit = { [weak self] in self?.tableController.endDrag() }
        table.draggingDestinationFeedbackStyle = .none
        tableController.onDropHighlight = { [weak self] in self?.showDropHighlight($0) }

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        // Many columns can be wider than the pane; Name stops shrinking at its minimum and the rest scrolls.
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setAccessibilityIdentifier("status.\(side.rawValue)")

        let newItemButton = NewItemButton(frame: .zero)
        newItemButton.translatesAutoresizingMaskIntoConstraints = false
        newItemButton.onNewFolder = { [model, side] in
            model.activate(side)
            model.perform(.newFolder)
        }
        newItemButton.onNewFile = { [model, side] in
            model.activate(side)
            model.perform(.newFile)
        }
        newItemButton.onNewTextDocument = { [model, side] in
            model.activate(side)
            model.createFile(on: side, named: "Document.txt")
        }
        newItemButton.onNewMarkdownDocument = { [model, side] in
            model.activate(side)
            model.createFile(on: side, named: "Readme.md")
        }
        newItemButton.onPasteImage = { [model, side] in
            model.activate(side)
            model.perform(.pasteImage)
        }

        let pathRow = padded(pathField, height: 36)
        breadcrumbs.translatesAutoresizingMaskIntoConstraints = false
        pathRow.addSubview(breadcrumbs)
        pathRow.addSubview(newItemButton)
        NSLayoutConstraint.activate([
            breadcrumbs.leadingAnchor.constraint(equalTo: pathRow.leadingAnchor, constant: 8),
            breadcrumbs.trailingAnchor.constraint(lessThanOrEqualTo: newItemButton.leadingAnchor, constant: -8),
            breadcrumbs.centerYAnchor.constraint(equalTo: pathRow.centerYAnchor),
            breadcrumbs.heightAnchor.constraint(equalToConstant: 28),

            newItemButton.trailingAnchor.constraint(equalTo: pathRow.trailingAnchor, constant: -8),
            newItemButton.centerYAnchor.constraint(equalTo: pathRow.centerYAnchor),
            newItemButton.heightAnchor.constraint(equalToConstant: 28),
        ])
        let statusRow = padded(statusLabel, height: 27)
        let stack = NSStackView(views: [activeLine, tabBar, pathRow, banner, scrollView, statusRow])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            activeLine.heightAnchor.constraint(equalToConstant: 2),
        ])

        // Over the column header, so showing it mid-drag doesn't shift the rows under the cursor.
        parentStrip.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(parentStrip)
        NSLayoutConstraint.activate([
            parentStrip.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            parentStrip.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            parentStrip.topAnchor.constraint(equalTo: scrollView.topAnchor),
            parentStrip.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Clicking anywhere in the pane makes it active; the recognizer must not swallow the click.
        let click = NSClickGestureRecognizer(target: self, action: #selector(paneClicked))
        click.delaysPrimaryMouseButtonEvents = false
        root.addGestureRecognizer(click)
        view = root
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let rows = Int(scrollView.contentView.bounds.height / max(table.rowHeight, 1))
        model.setPageSize(side, rows: max(rows, 1))
    }

    func render() {
        let tab = model.tab(side)
        let pane = side == .left ? model.state.left : model.state.right
        tabBar.update(titles: pane.tabs.map { Self.title(for: $0.path) }, active: pane.activeTabIndex)
        if pathField.currentEditor() == nil { pathField.stringValue = tab.path.path }
        breadcrumbs.show(tab.path)
        let folderSizes = model.folderSizes(side)
        statusLabel.stringValue = PaneText.status(tab, folderSizes: folderSizes)
        banner.show(model.banner(side))

        let active = model.state.activeSide == side
        // Transparent rather than hidden: the stack view would drop a hidden line and shift the pane by 2 pt.
        activeLine.fillColor = active ? Palette.accent : .clear
        view.setAccessibilityValue(active ? "active" : "inactive")

        let names = tab.items.map(\.name)
        let appearance = model.settings.appearance
        let cut = model.cutNames(in: tab.path)
        tableController.applyColumns(to: table)
        if names != shownNames || active != shownActive || appearance != shownAppearance {
            let interval = Self.signposter.beginInterval("Render")
            table.rowHeight = CGFloat(appearance.rowHeight)
            table.reloadData()
            Self.signposter.endInterval("Render", interval)
        } else {
            reloadChangedRows(tab, names: names, cut: cut)
            let sizeColumn = table.column(withIdentifier: NSUserInterfaceItemIdentifier(FileTableController.Column.size.rawValue))
            if folderSizes != shownFolderSizes, sizeColumn >= 0 {
                table.reloadData(forRowIndexes: IndexSet(integersIn: 0..<names.count), columnIndexes: IndexSet(integer: sizeColumn))
            }
        }
        shownFolderSizes = folderSizes
        shownCut = cut
        showSortIndicator(tab.sort)
        // Background refreshes (watcher, folder sizes) must not yank a wheel-scrolled view back to the cursor.
        let followCursor = tab.cursor != shownCursor || tab.path != shownPath
        shownNames = names
        shownCursor = tab.cursor
        shownMarked = tab.marked
        shownActive = active
        shownAppearance = appearance
        shownPath = tab.path
        if followCursor, let index = tab.cursorIndex { table.scrollRowToVisible(index) }
    }

    private func showSortIndicator(_ sort: FileSort) {
        for column in table.tableColumns {
            let isSorted = column.identifier.rawValue == sort.column.rawValue
            let image = isSorted ? NSImage(named: sort.ascending ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator") : nil
            table.setIndicatorImage(image, in: column)
            if isSorted { table.highlightedTableColumn = column }
        }
    }

    private func reloadChangedRows(_ tab: TabState, names: [String], cut: Set<String>) {
        var changed = shownMarked.symmetricDifference(tab.marked).union(shownCut.symmetricDifference(cut))
        if shownCursor != tab.cursor {
            changed.formUnion([shownCursor, tab.cursor].compactMap { $0 })
        }
        guard !changed.isEmpty else { return }
        let rows = IndexSet(names.indices.filter { changed.contains(names[$0]) })
        table.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
        for row in rows {
            if let rowView = table.rowView(atRow: row, makeIfNecessary: false) { tableController.configure(rowView, row: row) }
        }
    }

    func focusPathField() {
        breadcrumbs.isHidden = true
        pathField.isHidden = false
        view.window?.makeFirstResponder(pathField)
        pathField.selectText(nil)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === pathField else { return }
        // `selectText` ends and restarts editing; only a real end (no editor left) brings the breadcrumbs back.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pathField.currentEditor() == nil else { return }
            self.pathField.isHidden = true
            self.breadcrumbs.isHidden = false
        }
    }

    private func showDropHighlight(_ highlight: FileTableController.DropHighlight) {
        scrollView.wantsLayer = true
        scrollView.layer?.borderColor = Palette.accent.cgColor
        scrollView.layer?.borderWidth = highlight == .table ? 2 : 0
        for row in 0..<table.numberOfRows {
            if let rowView = table.rowView(atRow: row, makeIfNecessary: false) { tableController.configure(rowView, row: row) }
        }
        dragHover(highlight != .none)
    }

    /// The strip shows while a drag is over the table or the strip; hiding waits a moment so moving from one
    /// to the other doesn't make it vanish under the cursor.
    private func dragHover(_ inside: Bool) {
        parentStripHide?.cancel()
        if inside {
            parentStrip.isHidden = model.tab(side).path.path == "/"
        } else {
            parentStripHide = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                self?.parentStrip.isHidden = true
            }
        }
    }

    func focusTable() {
        view.window?.makeFirstResponder(table)
    }

    func beginRename(_ name: String) {
        renameEditor.begin(name: name)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === pathField else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            if model.goToPath(side, pathField.stringValue) { focusTable() }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            pathField.stringValue = model.tab(side).path.path
            focusTable()
            return true
        default:
            return false
        }
    }

    /// Dragging a marked row drags every marked item; any other row is dragged alone.
    private func beginDrag(row: Int, event: NSEvent) {
        let tab = model.tab(side)
        guard tab.items.indices.contains(row) else { return }
        let dragged = tab.items[row]
        let items = tab.marked.contains(dragged.name) ? tab.items.filter { tab.marked.contains($0.name) } : [dragged]
        let rowRect = table.rect(ofRow: row)
        let image = Self.dragImage(icon: IconCache.shared.icon(for: dragged), name: dragged.name, count: items.count)
        let frame = NSRect(x: rowRect.minX + 4, y: rowRect.midY - image.size.height / 2, width: image.size.width, height: image.size.height)
        // One composed image on the grabbed row; the other items stay invisible so they don't pile up as overlapping copies.
        let draggingItems = items.map { item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            draggingItem.draggingFrame = frame
            if item.name == dragged.name {
                draggingItem.imageComponentsProvider = {
                    let component = NSDraggingImageComponent(key: .icon)
                    component.contents = image
                    component.frame = NSRect(origin: .zero, size: image.size)
                    return [component]
                }
            } else {
                draggingItem.imageComponentsProvider = { [] }
            }
            return draggingItem
        }
        let session = table.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.draggingFormation = .none
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : [.copy, .move]
    }

    /// Icon (stacked when several items), the grabbed item's name on a rounded plate, and a Finder-style count badge.
    private static func dragImage(icon: NSImage, name: String, count: Int) -> NSImage {
        let iconSide: CGFloat = 32
        let stackOffset: CGFloat = count > 1 ? 4 : 0
        let badgeHeight: CGFloat = 18
        let inset = badgeHeight / 2

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        let label = NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ])
        let labelWidth = min(ceil(label.size().width), 220)
        let labelHeight = ceil(label.size().height)
        let plate = NSSize(width: labelWidth + 12, height: labelHeight + 4)

        let badge = NSAttributedString(string: "\(count)", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
        ])
        let badgeWidth = max(badgeHeight, ceil(badge.size().width) + 10)

        let iconBlock = iconSide + stackOffset
        let size = NSSize(width: iconBlock + 6 + plate.width + inset, height: max(iconBlock, plate.height) + inset)
        return NSImage(size: size, flipped: false) { _ in
            let iconOrigin = NSPoint(x: 0, y: (size.height - inset - iconBlock) / 2)
            if count > 1 {
                icon.draw(in: NSRect(x: iconOrigin.x + stackOffset, y: iconOrigin.y + stackOffset, width: iconSide, height: iconSide), from: .zero, operation: .sourceOver, fraction: 0.5)
            }
            icon.draw(in: NSRect(x: iconOrigin.x, y: iconOrigin.y, width: iconSide, height: iconSide))

            let plateRect = NSRect(x: iconBlock + 6, y: (size.height - inset - plate.height) / 2, width: plate.width, height: plate.height)
            NSColor.controlAccentColor.withAlphaComponent(0.9).setFill()
            NSBezierPath(roundedRect: plateRect, xRadius: plate.height / 2, yRadius: plate.height / 2).fill()
            label.draw(with: NSRect(x: plateRect.minX + 6, y: plateRect.minY + 2, width: labelWidth, height: labelHeight), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])

            if count > 1 {
                let badgeRect = NSRect(x: iconBlock - badgeWidth / 2, y: size.height - badgeHeight, width: badgeWidth, height: badgeHeight)
                NSColor.systemRed.setFill()
                NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()
                let textSize = badge.size()
                badge.draw(at: NSPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2))
            }
            return true
        }
    }

    @objc private func paneClicked() {
        model.activate(side)
    }

    private static func title(for path: URL) -> String {
        path.path == "/" ? "/" : FileManager.default.displayName(atPath: path.path)
    }

    private func padded(_ field: NSView, height: CGFloat) -> NSView {
        let container = NSView()
        field.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(field)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: height),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            field.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }
}
