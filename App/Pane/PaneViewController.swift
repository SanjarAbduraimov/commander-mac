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
    private var shownMarked: Set<String> = []
    private var shownActive = false
    private var shownAppearance: AppearanceSettings?
    private var shownFolderSizes: [String: Int64] = [:]

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
        table.allowsColumnReordering = false
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.setAccessibilityIdentifier("table.\(side.rawValue)")
        FileTableController.makeColumns(in: table)
        table.dataSource = tableController
        table.delegate = tableController
        table.registerForDraggedTypes([.fileURL])
        table.onBeginDrag = { [weak self] row, event in self?.beginDrag(row: row, event: event) }
        table.onDragExit = { [weak self] in self?.tableController.endDrag() }
        table.draggingDestinationFeedbackStyle = .none
        tableController.onDropHighlight = { [weak self] in self?.showDropHighlight($0) }

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setAccessibilityIdentifier("status.\(side.rawValue)")

        let pathRow = padded(pathField, height: 24)
        breadcrumbs.translatesAutoresizingMaskIntoConstraints = false
        pathRow.addSubview(breadcrumbs)
        NSLayoutConstraint.activate([
            breadcrumbs.leadingAnchor.constraint(equalTo: pathRow.leadingAnchor, constant: 6),
            breadcrumbs.trailingAnchor.constraint(equalTo: pathRow.trailingAnchor, constant: -6),
            breadcrumbs.topAnchor.constraint(equalTo: pathRow.topAnchor),
            breadcrumbs.bottomAnchor.constraint(equalTo: pathRow.bottomAnchor),
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
        if names != shownNames || active != shownActive || appearance != shownAppearance {
            let interval = Self.signposter.beginInterval("Render")
            table.rowHeight = CGFloat(appearance.rowHeight)
            table.reloadData()
            Self.signposter.endInterval("Render", interval)
        } else {
            reloadChangedRows(tab, names: names)
            if folderSizes != shownFolderSizes {
                let sizeColumn = table.column(withIdentifier: NSUserInterfaceItemIdentifier(FileTableController.Column.size.rawValue))
                table.reloadData(forRowIndexes: IndexSet(integersIn: 0..<names.count), columnIndexes: IndexSet(integer: sizeColumn))
            }
        }
        shownFolderSizes = folderSizes
        showSortIndicator(tab.sort)
        shownNames = names
        shownCursor = tab.cursor
        shownMarked = tab.marked
        shownActive = active
        shownAppearance = appearance
        if let index = tab.cursorIndex { table.scrollRowToVisible(index) }
    }

    private func showSortIndicator(_ sort: FileSort) {
        for column in table.tableColumns {
            let isSorted = column.identifier.rawValue == sort.column.rawValue
            let image = isSorted ? NSImage(named: sort.ascending ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator") : nil
            table.setIndicatorImage(image, in: column)
            if isSorted { table.highlightedTableColumn = column }
        }
    }

    private func reloadChangedRows(_ tab: TabState, names: [String]) {
        var changed = shownMarked.symmetricDifference(tab.marked)
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
        let draggingItems = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let frame = NSRect(x: rowRect.minX + 24, y: rowRect.minY + CGFloat(index) * 4, width: 240, height: rowRect.height)
            draggingItem.imageComponentsProvider = {
                let icon = NSDraggingImageComponent(key: .icon)
                icon.contents = IconCache.shared.icon(for: item)
                icon.frame = NSRect(x: 0, y: 0, width: rowRect.height, height: rowRect.height)
                let label = NSDraggingImageComponent(key: .label)
                label.contents = Self.labelImage(item.name)
                label.frame = NSRect(x: rowRect.height + 4, y: 0, width: 200, height: rowRect.height)
                return [icon, label]
            }
            draggingItem.draggingFrame = frame
            return draggingItem
        }
        table.beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : [.copy, .move]
    }

    private static func labelImage(_ text: String) -> NSImage {
        let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        let size = NSSize(width: min(string.size().width + 4, 200), height: string.size().height)
        return NSImage(size: size, flipped: false) { _ in
            string.draw(at: .zero)
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
