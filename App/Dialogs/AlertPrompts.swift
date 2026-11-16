import AppKit
import CommanderController
import CommanderCore

/// Conflict, error and permanent-delete questions as sheets on the main window.
@MainActor
final class AlertPrompts: OperationPrompts {
    weak var window: NSWindow?

    func resolve(_ conflict: Conflict) async -> ConflictResolution {
        if let window {
            return await ConflictPresenter.show(for: conflict, over: window)
        }

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
        let title = "These items can't be moved to the Trash."
        let names = urls.prefix(5).map(\.lastPathComponent).joined(separator: "\n")
        let more = urls.count > 5 ? "\n…and \(urls.count - 5) more" : ""
        let detail = "They will be deleted immediately. You can't undo this action.\n\n\(names)\(more)"
        return await showDeletePrompt(title: title, detail: detail)
    }

    func confirmDeleteImmediately(_ urls: [URL]) async -> Bool {
        let title = urls.count == 1
            ? "Delete “\(urls[0].lastPathComponent)” immediately?"
            : "Delete \(urls.count) items immediately?"
        var detail = "You can't undo this action."
        if urls.count > 1 {
            let names = urls.prefix(5).map(\.lastPathComponent).joined(separator: "\n")
            let more = urls.count > 5 ? "\n…and \(urls.count - 5) more" : ""
            detail += "\n\n\(names)\(more)"
        }
        return await showDeletePrompt(title: title, detail: detail)
    }

    private func showDeletePrompt(title: String, detail: String) async -> Bool {
        if let window {
            return await DeleteConfirmPresenter.show(over: window, title: title, detail: detail)
        }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
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

    private var alertActiveIndex: Int = 0

    private func present(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        guard let window else { return alert.runModal() }
        alertActiveIndex = 0
        styleAlertButtons(alert, activeIndex: 0)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.styleAlertButtons(alert, activeIndex: self.alertActiveIndex)
            if let first = alert.buttons.first {
                alert.window.makeFirstResponder(first)
            }
        }

        var monitor: Any?
        let cleanup: @MainActor () -> Void = {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            nonisolated(unsafe) let event = event
            let consumed = MainActor.assumeIsolated {
                self?.handleAlertKeyEvent(event, alert: alert) ?? false
            }
            return consumed ? nil : event
        }

        let response = await alert.beginSheetModal(for: window)
        cleanup()
        return response
    }

    @MainActor
    private func handleAlertKeyEvent(_ event: NSEvent, alert: NSAlert) -> Bool {
        guard event.window === alert.window || event.window === window || event.window?.attachedSheet === alert.window else { return false }
        let buttons = alert.buttons
        guard !buttons.isEmpty else { return false }

        // If user is editing a text field / combo box accessory, let text navigation handle arrow keys
        if alert.window.firstResponder is NSText {
            if event.keyCode == 36 || event.keyCode == 76 { // Return
                buttons.first?.performClick(nil)
                return true
            }
            return false
        }

        // Tab (48), Left Arrow (123), Right Arrow (124)
        if event.keyCode == 48 || event.keyCode == 123 || event.keyCode == 124 {
            let delta = (event.keyCode == 123) ? -1 : 1
            alertActiveIndex = (alertActiveIndex + delta + buttons.count) % buttons.count
            alert.window.makeFirstResponder(buttons[alertActiveIndex])
            styleAlertButtons(alert, activeIndex: alertActiveIndex)
            return true
        }

        // Enter / Return (36, 76) or Space (49)
        if event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 49 {
            if buttons.indices.contains(alertActiveIndex) {
                buttons[alertActiveIndex].performClick(nil)
                return true
            } else if let first = buttons.first {
                first.performClick(nil)
                return true
            }
        }

        // Esc (53)
        if event.keyCode == 53 {
            if let cancel = buttons.last {
                cancel.performClick(nil)
                return true
            }
        }

        return false
    }

    @MainActor
    private func styleAlertButtons(_ alert: NSAlert, activeIndex: Int) {
        let buttons = alert.buttons
        for (index, button) in buttons.enumerated() {
            button.wantsLayer = true
            button.isBordered = false
            button.focusRingType = .none
            button.layer?.cornerRadius = 6
            button.layer?.masksToBounds = true

            if button.constraints.filter({ $0.firstAttribute == .height }).isEmpty {
                button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            }
            if button.constraints.filter({ $0.firstAttribute == .width }).isEmpty {
                button.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
            }

            let isDestructive = button.hasDestructiveAction || button.title.localizedCaseInsensitiveContains("delete")
            let isActive = (index == activeIndex)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let cleanTitle = button.title.trimmingCharacters(in: .whitespaces)

            if isDestructive {
                if isActive {
                    button.layer?.backgroundColor = NSColor.systemRed.cgColor
                    button.layer?.borderWidth = 2.0
                    button.layer?.borderColor = NSColor.white.cgColor
                    button.attributedTitle = NSAttributedString(
                        string: cleanTitle,
                        attributes: [
                            .foregroundColor: NSColor.white,
                            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                            .paragraphStyle: paragraph
                        ]
                    )
                } else {
                    button.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.45).cgColor
                    button.layer?.borderWidth = 0.5
                    button.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.3).cgColor
                    button.attributedTitle = NSAttributedString(
                        string: cleanTitle,
                        attributes: [
                            .foregroundColor: NSColor.white.withAlphaComponent(0.9),
                            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                            .paragraphStyle: paragraph
                        ]
                    )
                }
            } else if index == 0 && buttons.count > 1 {
                if isActive {
                    button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                    button.layer?.borderWidth = 2.0
                    button.layer?.borderColor = NSColor.white.cgColor
                    button.attributedTitle = NSAttributedString(
                        string: cleanTitle,
                        attributes: [
                            .foregroundColor: NSColor.white,
                            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                            .paragraphStyle: paragraph
                        ]
                    )
                } else {
                    button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.45).cgColor
                    button.layer?.borderWidth = 0.5
                    button.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
                    button.attributedTitle = NSAttributedString(
                        string: cleanTitle,
                        attributes: [
                            .foregroundColor: NSColor.white.withAlphaComponent(0.9),
                            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                            .paragraphStyle: paragraph
                        ]
                    )
                }
            } else {
                if isActive {
                    button.layer?.backgroundColor = NSColor(white: 0.45, alpha: 0.85).cgColor
                    button.layer?.borderWidth = 2.0
                    button.layer?.borderColor = NSColor.white.cgColor
                    button.attributedTitle = NSAttributedString(
                        string: cleanTitle,
                        attributes: [
                            .foregroundColor: NSColor.white,
                            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                            .paragraphStyle: paragraph
                        ]
                    )
                } else {
                    button.layer?.backgroundColor = NSColor(white: 0.28, alpha: 0.65).cgColor
                    button.layer?.borderWidth = 0.5
                    button.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
                    button.attributedTitle = NSAttributedString(
                        string: cleanTitle,
                        attributes: [
                            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
                            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                            .paragraphStyle: paragraph
                        ]
                    )
                }
            }
        }
    }
}
