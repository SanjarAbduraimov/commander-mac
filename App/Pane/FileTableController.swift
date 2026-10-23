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
        case .size:
            cell.textField?.stringValue = item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"
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

    func configure(_ rowView: NSTableRowView, row: Int) {
        guard let rowView = rowView as? FileRowView, tab.items.indices.contains(row) else { return }
        let name = tab.items[row].name
        rowView.isMarked = tab.marked.contains(name)
        rowView.isCursor = model.state.activeSide == side && tab.cursor == name
    }

    private func cellView(in tableView: NSTableView, column: Column) -> NSTableCellView {
        let identifier = NSUserInterfaceItemIdentifier("cell." + column.rawValue)
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
