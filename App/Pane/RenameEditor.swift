import AppKit
import CommanderController
import CommanderCore

/// Edits a name in place in the table's name cell; Return or leaving the field commits, Esc cancels.
@MainActor
final class RenameEditor: NSObject, NSTextFieldDelegate {
    private let model: WindowModel
    private let side: PaneSide
    private weak var table: FileTableView?
    private var field: NSTextField?
    private var originalName: String?
    private var isCommitting = false

    init(model: WindowModel, side: PaneSide, table: FileTableView) {
        self.model = model
        self.side = side
        self.table = table
    }

    func begin(name: String) {
        guard let table, let row = model.tab(side).items.firstIndex(where: { $0.name == name }) else { return }
        table.scrollRowToVisible(row)
        let column = table.column(withIdentifier: NSUserInterfaceItemIdentifier(FileTableController.Column.name.rawValue))
        guard let cell = table.view(atColumn: column, row: row, makeIfNecessary: true) as? NSTableCellView,
              let field = cell.textField
        else { return }

        self.field = field
        originalName = name
        // The cell may show the name without its extension (Ext column); rename always edits the full name.
        field.stringValue = name
        field.isEditable = true
        field.isSelectable = true
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.delegate = self
        table.window?.makeFirstResponder(field)
        let kind = model.tab(side).items[row].kind
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: RenameSelection.editableLength(of: name, kind: kind))
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            commit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            field?.stringValue = originalName ?? ""
            finish()
            return true
        default:
            return false
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if field != nil, !isCommitting { commit() }
    }

    private func commit() {
        guard let field, let originalName, !isCommitting else { return }
        isCommitting = true
        let newName = field.stringValue
        Task {
            guard let error = await model.commitRename(side, from: originalName, to: newName) else {
                finish()
                return
            }
            let alert = NSAlert()
            alert.messageText = RenameText.message(error, newName: newName)
            guard let window = table?.window else { return finish() }
            await alert.beginSheetModal(for: window)
            isCommitting = false
            window.makeFirstResponder(field)
        }
    }

    private func finish() {
        guard let field else { return }
        let row = originalName.flatMap { name in model.tab(side).items.firstIndex { $0.name == name } }
        self.field = nil
        originalName = nil
        isCommitting = false
        field.delegate = nil
        field.isEditable = false
        field.isSelectable = false
        field.drawsBackground = false
        if let table {
            table.window?.makeFirstResponder(table)
            // The field held the full name while editing; the cell may show it without the extension.
            if let row { table.reloadData(forRowIndexes: [row], columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns)) }
        }
    }
}
