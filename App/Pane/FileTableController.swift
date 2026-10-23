import AppKit
import CommanderController
import CommanderCore

@MainActor
final class FileTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    enum Column: String, CaseIterable {
        case mark, name, size, modified
    }

    private static let dateStyle = Date.FormatStyle(date: .numeric, time: .shortened)
    private static let markImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Marked")

    private let model: WindowModel
    private let side: PaneSide

    init(model: WindowModel, side: PaneSide) {
        self.model = model
        self.side = side
    }

    private var tab: TabState { model.tab(side) }

    var font: NSFont {
        let appearance = model.settings.appearance
        return appearance.fontName.flatMap { NSFont(name: $0, size: appearance.fontSize) } ?? .systemFont(ofSize: appearance.fontSize)
    }

    static func makeColumns(in table: NSTableView) {
        let specs: [(Column, String, CGFloat, CGFloat)] = [
            (.mark, "", 18, 18), (.name, "Name", 120, 120), (.size, "Size", 72, 56), (.modified, "Modified", 135, 100),
        ]
        for (column, title, width, minWidth) in specs {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = title
            tableColumn.width = width
            tableColumn.minWidth = minWidth
            if column == .mark { tableColumn.maxWidth = 18; tableColumn.resizingMask = [] }
            if column == .size { tableColumn.headerCell.alignment = .right }
            table.addTableColumn(tableColumn)
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
            cell.imageView?.image = tab.marked.contains(item.name) ? Self.markImage : nil
            cell.imageView?.contentTintColor = Palette.markSymbol
        case .name:
            cell.textField?.stringValue = item.name
            cell.textField?.font = font
            cell.imageView?.image = IconCache.shared.icon(for: item)
            // Finder dims hidden items.
            let alpha: CGFloat = item.isHidden ? 0.5 : 1
            cell.textField?.alphaValue = alpha
            cell.imageView?.alphaValue = alpha
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
        let sortColumn: SortColumn? = switch Column(rawValue: tableColumn.identifier.rawValue) {
        case .name: .name
        case .size: .size
        case .modified: .modified
        case .mark, nil: nil
        }
        if let sortColumn { model.sortColumnClicked(side, sortColumn) }
    }

    // MARK: Drop

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        let urls = Self.fileURLs(info)
        var folder = folderName(row: row, dropOperation: dropOperation)
        if folder == nil { tableView.setDropRow(-1, dropOperation: .on) }
        if folder != nil, model.dropOperation(urls, on: side, intoFolder: folder, forceCopy: forceCopy(info)) == .none {
            folder = nil
            tableView.setDropRow(-1, dropOperation: .on)
        }
        switch model.dropOperation(urls, on: side, intoFolder: folder, forceCopy: forceCopy(info)) {
        case .copy: return .copy
        case .move: return .move
        case .none: return []
        }
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        model.drop(Self.fileURLs(info), on: side, intoFolder: folderName(row: row, dropOperation: dropOperation), forceCopy: forceCopy(info))
    }

    private func folderName(row: Int, dropOperation: NSTableView.DropOperation) -> String? {
        guard dropOperation == .on, tab.items.indices.contains(row), tab.items[row].isNavigable else { return nil }
        return tab.items[row].name
    }

    /// ⌥ forces a copy, and so does a source that does not allow moving its files.
    private func forceCopy(_ info: NSDraggingInfo) -> Bool {
        NSEvent.modifierFlags.contains(.option) || !info.draggingSourceOperationMask.contains(.move)
    }

    private static func fileURLs(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    func configure(_ rowView: NSTableRowView, row: Int) {
        guard let rowView = rowView as? FileRowView, tab.items.indices.contains(row) else { return }
        let name = tab.items[row].name
        rowView.isMarked = tab.marked.contains(name)
        rowView.isCursor = model.state.activeSide == side && tab.cursor == name
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
