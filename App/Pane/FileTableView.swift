import AppKit
import CommanderController
import CommanderCore

final class FileTableView: NSTableView {
    var side: PaneSide = .left
    weak var model: WindowModel?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { model?.activate(side) }
        return accepted
    }

    // Edit-menu clicks while the table has focus; keystrokes already went through KeyRouter.
    @objc func copy(_ sender: Any?) { model?.perform(.copyToClipboard) }
    @objc func cut(_ sender: Any?) { model?.perform(.cutToClipboard) }
    @objc func paste(_ sender: Any?) { model?.perform(.paste) }
    override func selectAll(_ sender: Any?) { model?.perform(.markAll) }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard let model else { return false }
        switch item.action {
        case #selector(copy(_:)): return model.isEnabled(.copyToClipboard, context: .table)
        case #selector(cut(_:)): return model.isEnabled(.cutToClipboard, context: .table)
        case #selector(paste(_:)): return model.isEnabled(.paste, context: .table)
        case #selector(selectAll(_:)): return true
        case Selector(("undo:")), Selector(("redo:")): return false
        default: return super.validateUserInterfaceItem(item)
        }
    }
}
