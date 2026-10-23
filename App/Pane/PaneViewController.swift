import AppKit
import CommanderController
import CommanderCore
import os

@MainActor
final class PaneViewController: NSViewController {
    private static let signposter = OSSignposter(subsystem: "local.sanjar.commander", category: .pointsOfInterest)

    let model: WindowModel
    let side: PaneSide
    let table = FileTableView()
    let pathField = NSTextField()

    private let tableController: FileTableController
    private let tabBar = TabBarView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let activeLine = NSBox()
    private let scrollView = NSScrollView()

    /// What the table currently shows, to reload only the rows a change touched.
    private var shownNames: [String] = []
    private var shownCursor: String?
    private var shownMarked: Set<String> = []
    private var shownActive = false
    private var shownAppearance: AppearanceSettings?

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

        pathField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathField.isBordered = false
        pathField.drawsBackground = false
        pathField.lineBreakMode = .byTruncatingHead
        pathField.setAccessibilityIdentifier("path.\(side.rawValue)")

        table.side = side
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

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setAccessibilityIdentifier("status.\(side.rawValue)")

        let pathRow = padded(pathField, height: 24)
        let statusRow = padded(statusLabel, height: 27)
        let stack = NSStackView(views: [activeLine, tabBar, pathRow, scrollView, statusRow])
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
        statusLabel.stringValue = PaneText.status(tab)

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
        }
        shownNames = names
        shownCursor = tab.cursor
        shownMarked = tab.marked
        shownActive = active
        shownAppearance = appearance
        if let index = tab.cursorIndex { table.scrollRowToVisible(index) }
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
