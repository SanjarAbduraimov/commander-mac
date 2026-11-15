import AppKit
import CommanderController
import CommanderCore

@MainActor
final class FileTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    enum Column: String, CaseIterable {
        case mark, name, ext, size, modified, created, kind

        var configurable: ColumnID? { ColumnID(rawValue: rawValue) }
    }

    private static let dateStyle = Date.FormatStyle(date: .numeric, time: .shortened)
    private static let markImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Marked")
    private static let cutImage = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Cut")

    enum DropHighlight: Equatable {
        case none, table, row(String)
    }

    var onDropHighlight: ((DropHighlight) -> Void)?
    private(set) var dropHighlight = DropHighlight.none {
        didSet { if dropHighlight != oldValue { onDropHighlight?(dropHighlight) } }
    }

    private let model: WindowModel
    private let side: PaneSide
    private let springLoader = SpringLoader()
    private var shownColumns: [ColumnSetting] = []
    /// Set while columns are rebuilt from settings, so AppKit's resize/move callbacks don't write back.
    private var isApplyingColumns = false
    private var pendingColumnStore: Task<Void, Never>?

    init(model: WindowModel, side: PaneSide) {
        self.model = model
        self.side = side
    }

    private var tab: TabState { model.tab(side) }

    var font: NSFont {
        let appearance = model.settings.appearance
        return appearance.fontName.flatMap { NSFont(name: $0, size: appearance.fontSize) } ?? .systemFont(ofSize: appearance.fontSize)
    }

    private var showsExtColumn: Bool { model.settings.appearance.columns.contains { $0.id == .ext } }

    /// Mark and Name stay first; the rest follow the settings (shared by both panes). Rebuilt only when the
    /// set or order changed, otherwise widths are updated in place.
    func applyColumns(to table: NSTableView) {
        let columns = model.settings.appearance.columns
        guard columns != shownColumns else { return }
        isApplyingColumns = true
        defer { isApplyingColumns = false }
        let wanted = [Column.mark.rawValue, Column.name.rawValue] + columns.map(\.id.rawValue)
        if table.tableColumns.map(\.identifier.rawValue) != wanted {
            for column in table.tableColumns { table.removeTableColumn(column) }
            table.addTableColumn(Self.tableColumn(.mark, width: 18))
            table.addTableColumn(Self.tableColumn(.name, width: 200))
            for setting in columns { table.addTableColumn(Self.tableColumn(Column(rawValue: setting.id.rawValue)!, width: setting.width)) }
            table.sizeToFit()
        } else {
            for setting in columns {
                table.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(setting.id.rawValue))?.width = CGFloat(setting.width)
            }
        }
        shownColumns = columns
    }

    private static func tableColumn(_ column: Column, width: Double) -> NSTableColumn {
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
        tableColumn.title = column.configurable?.title ?? (column == .name ? "Name" : "")
        tableColumn.width = CGFloat(width)
        switch column {
        case .mark:
            tableColumn.minWidth = 18
            tableColumn.maxWidth = 18
            tableColumn.resizingMask = []
        case .name:
            tableColumn.minWidth = 120
            tableColumn.resizingMask = [.autoresizingMask, .userResizingMask]
        default:
            tableColumn.minWidth = 40
            tableColumn.resizingMask = .userResizingMask
        }
        if column == .size { tableColumn.headerCell.alignment = .right }
        return tableColumn
    }

    // MARK: Header menu, column moves and resizes

    func headerMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        for id in ColumnID.allCases {
            let item = NSMenuItem(title: id.title, action: #selector(toggleColumn(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id.rawValue
            menu.addItem(item)
        }
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let shown = Set(model.settings.appearance.columns.map(\.id))
        for item in menu.items {
            let id = (item.representedObject as? String).flatMap(ColumnID.init(rawValue:))
            item.state = id.map(shown.contains) == true ? .on : .off
        }
    }

    @objc private func toggleColumn(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? String).flatMap(ColumnID.init(rawValue:)) else { return }
        model.toggleColumn(id)
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        columnIndex >= 2 && (newColumnIndex >= 2 || newColumnIndex == -1)
    }

    func tableViewColumnDidMove(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        storeColumns(of: table)
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        storeColumns(of: table)
    }

    private func storeColumns(of table: NSTableView) {
        guard !isApplyingColumns else { return }
        let columns = table.tableColumns.compactMap { column -> ColumnSetting? in
            guard let id = ColumnID(rawValue: column.identifier.rawValue) else { return nil }
            return ColumnSetting(id: id, width: Double(column.width.rounded()))
        }
        shownColumns = columns
        // A resize drag reports every mouse move; settings (both panes, menus, disk) update once it settles.
        pendingColumnStore?.cancel()
        pendingColumnStore = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            self.model.setColumns(columns)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        tab.items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, let column = Column(rawValue: tableColumn.identifier.rawValue), tab.items.indices.contains(row) else { return nil }
        let item = tab.items[row]
        let cell = cellView(in: tableView, column: column)
        switch column {
        case .mark:
            let isCut = model.isCut(item)
            cell.imageView?.image = isCut ? Self.cutImage : tab.marked.contains(item.name) ? Self.markImage : nil
            cell.imageView?.contentTintColor = isCut ? Palette.accent : Palette.markSymbol
        case .name:
            let isCut = model.isCut(item)
            cell.textField?.stringValue = showsExtColumn ? item.baseName : item.name
            cell.textField?.font = isCut ? NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) : font
            cell.textField?.textColor = isCut ? Palette.accent : .labelColor
            cell.imageView?.image = IconCache.shared.icon(for: item, size: CGFloat(model.settings.appearance.iconSize))
            // Finder dims hidden items; a cut item is told apart by italics and colour, so both can show at once.
            let alpha: CGFloat = item.isHidden ? 0.5 : 1
            cell.textField?.alphaValue = alpha
            cell.imageView?.alphaValue = alpha
        case .ext:
            cell.textField?.stringValue = item.ext
            cell.textField?.font = font
        case .created:
            cell.textField?.stringValue = item.created?.formatted(Self.dateStyle) ?? "--"
            cell.textField?.font = font
        case .kind:
            cell.textField?.stringValue = item.kindName
            cell.textField?.font = font
        case .size:
            let size = item.size ?? model.folderSize(side, item)
            cell.textField?.stringValue = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"
            cell.textField?.font = font
        case .modified:
            cell.textField?.stringValue = item.modified.formatted(Self.dateStyle)
            cell.textField?.font = font
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        FileRowView()
    }

    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        configure(rowView, row: row)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        let column = Column(rawValue: tableColumn.identifier.rawValue)
        let sortColumn: SortColumn? = column == .name ? .name : column?.configurable?.sortColumn
        if let sortColumn { model.sortColumnClicked(side, sortColumn) }
    }

    // MARK: Drop

    /// A folder row that can take the drop is highlighted and spring-loads; anywhere else the whole table is the target.
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        let urls = DragFiles.urls(info)
        let forceCopy = DragFiles.forceCopy(info)
        var folder = folderName(row: row, dropOperation: dropOperation)
        if folder != nil, model.dropOperation(urls, on: side, intoFolder: folder, forceCopy: forceCopy) == .none { folder = nil }
        if let folder {
            dropHighlight = .row(folder)
            springLoader.hover(folder) { [model, side] in model.springLoad(side, into: folder) }
        } else {
            tableView.setDropRow(-1, dropOperation: .on)
            dropHighlight = .table
            springLoader.cancel()
        }
        return DragFiles.dragOperation(model.dropOperation(urls, on: side, intoFolder: folder, forceCopy: forceCopy))
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let folder: String? = if case let .row(name) = dropHighlight { name } else { nil }
        endDrag()
        return model.drop(DragFiles.urls(info), on: side, intoFolder: folder, forceCopy: DragFiles.forceCopy(info))
    }

    func endDrag() {
        dropHighlight = .none
        springLoader.cancel()
    }

    private func folderName(row: Int, dropOperation: NSTableView.DropOperation) -> String? {
        guard dropOperation == .on, tab.items.indices.contains(row), tab.items[row].isNavigable else { return nil }
        return tab.items[row].name
    }

    func configure(_ rowView: NSTableRowView, row: Int) {
        guard let rowView = rowView as? FileRowView, tab.items.indices.contains(row) else { return }
        let name = tab.items[row].name
        rowView.isMarked = tab.marked.contains(name)
        rowView.isCursor = model.state.activeSide == side && tab.cursor == name
        rowView.isDropTarget = dropHighlight == .row(name)
    }

    private func cellView(in tableView: NSTableView, column: Column) -> NSTableCellView {
        // The icon size is baked into a cell's constraints, so cells are only reused within one icon size.
        let identifier = NSUserInterfaceItemIdentifier("cell.\(column.rawValue).\(Int(model.settings.appearance.iconSize))")
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView { return reused }

        let cell = NSTableCellView()
        cell.identifier = identifier
        let iconSize = CGFloat(model.settings.appearance.iconSize)
        if column == .mark || column == .name {
            let image = NSImageView()
            image.imageScaling = .scaleProportionallyUpOrDown
            image.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(image)
            cell.imageView = image
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: column == .mark ? 2 : 0),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: column == .mark ? 12 : iconSize),
                image.heightAnchor.constraint(equalToConstant: column == .mark ? 12 : iconSize),
            ])
        }
        guard column != .mark else { return cell }

        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.lineBreakMode = .byTruncatingMiddle
        text.alignment = column == .size ? .right : .natural
        text.textColor = column == .name ? .labelColor : .secondaryLabelColor
        cell.addSubview(text)
        cell.textField = text
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: cell.imageView?.trailingAnchor ?? cell.leadingAnchor, constant: column == .name ? 6 : 2),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
