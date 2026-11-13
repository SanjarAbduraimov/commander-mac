import AppKit
import CommanderController
import CommanderCore

/// Conflict, error and permanent-delete questions as sheets on the main window.
@MainActor
final class AlertPrompts: OperationPrompts {
    weak var window: NSWindow?

    func resolve(_ conflict: Conflict) async -> ConflictResolution {
        let alert = NSAlert()
        alert.messageText = "An item named “\(conflict.existing.lastPathComponent)” already exists in this location."
        alert.informativeText = "Do you want to replace it?"
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Skip")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Apply to All"
        let response = await present(alert)
        let applyToAll = alert.suppressionButton?.state == .on
        let decision: ConflictDecision = switch response {
        case .alertFirstButtonReturn: .replace
        case .alertSecondButtonReturn: .keepBoth
        default: .skip
        }
        return ConflictResolution(decision: decision, applyToAll: applyToAll)
    }

    func decide(_ failure: OperationFailure) async -> ErrorDecision {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = FailureText.message(failure)
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Skip")
        alert.addButton(withTitle: "Cancel All")
        return switch await present(alert) {
        case .alertFirstButtonReturn: .retry
        case .alertSecondButtonReturn: .skip
        default: .cancelAll
        }
    }

    func confirmPermanentDelete(_ urls: [URL]) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "These items can't be moved to the Trash."
        let names = urls.prefix(5).map(\.lastPathComponent).joined(separator: "\n")
        let more = urls.count > 5 ? "\n…and \(urls.count - 5) more" : ""
        alert.informativeText = "They will be deleted immediately. You can't undo this action.\n\n\(names)\(more)"
        let delete = alert.addButton(withTitle: "Delete")
        delete.hasDestructiveAction = true
        delete.keyEquivalent = "\r"
        let cancel = alert.addButton(withTitle: "Cancel")
        cancel.keyEquivalent = "\u{1b}"
        return await present(alert) == .alertFirstButtonReturn
    }

    func confirmDeleteImmediately(_ urls: [URL]) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = urls.count == 1
            ? "Delete “\(urls[0].lastPathComponent)” immediately?"
            : "Delete \(urls.count) items immediately?"
        var detail = "You can't undo this action."
        if urls.count > 1 {
            let names = urls.prefix(5).map(\.lastPathComponent).joined(separator: "\n")
            let more = urls.count > 5 ? "\n…and \(urls.count - 5) more" : ""
            detail += "\n\n\(names)\(more)"
        }
        alert.informativeText = detail
        let delete = alert.addButton(withTitle: "Delete")
        delete.hasDestructiveAction = true
        delete.keyEquivalent = "\r"
        let cancel = alert.addButton(withTitle: "Cancel")
        cancel.keyEquivalent = "\u{1b}"
        return await present(alert) == .alertFirstButtonReturn
    }

    func askPattern(_ request: PatternRequest) async -> String? {
        let alert = NSAlert()
        alert.messageText = request.marking ? "Mark files matching:" : "Unmark files matching:"
        alert.informativeText = "Use * and ?, separate patterns with ; — for example *.jpg;*.png"
        let field = NSComboBox(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        field.addItems(withObjectValues: request.recent)
        field.stringValue = request.recent.first ?? "*.*"
        field.completes = true
        field.setAccessibilityIdentifier("pattern.field")
        alert.accessoryView = field
        alert.addButton(withTitle: request.marking ? "Mark" : "Unmark")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard await present(alert) == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    func showAlert(_ message: AlertMessage) {
        let alert = NSAlert()
        alert.messageText = message.title
        alert.informativeText = message.detail ?? ""
        Task { _ = await present(alert) }
    }

    private func present(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        guard let window else { return alert.runModal() }
        return await alert.beginSheetModal(for: window)
    }
}
