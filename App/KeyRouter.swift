import AppKit
import CommanderController
import CommanderCore

/// Every key in the main window goes through `KeyBindings` first, before menus and the responder chain,
/// so remapped shortcuts and the text-field rules hold no matter which view has focus.
@MainActor
final class KeyRouter {
    private let model: WindowModel
    private weak var window: NSWindow?
    private var monitor: Any?

    init(model: WindowModel) {
        self.model = model
    }

    /// A sheet (Copy To, Connect to Server, an alert) counts as typing: menu shortcuts like ⌘⌫ must not reach the
    /// marked files behind it while the user edits a field in the sheet.
    var currentContext: FocusContext {
        guard let window else { return .table }
        if SettingsWindowController.isOpen { return .textField }
        return window.attachedSheet != nil || window.firstResponder is NSText ? .textField : .table
    }

    func install(in window: NSWindow) {
        self.window = window
        // Local monitors run on the main thread; only the verdict crosses back, not the event.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            nonisolated(unsafe) let event = event
            let consumed = MainActor.assumeIsolated { self?.consumes(event) ?? false }
            return consumed ? nil : event
        }
    }

    private func consumes(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, window.attachedSheet == nil else { return false }
        if SettingsWindowController.isOpen {
            if event.keyCode == 53 { // Esc
                SettingsWindowController.dismissActive()
                return true
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command), event.charactersIgnoringModifiers == "," {
                SettingsWindowController.dismissActive()
                return true
            }
            return false
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: KeyChord.Modifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }

        guard let chord = KeyChordMapper.chord(
            keyCode: event.keyCode, baseCharacters: event.characters(byApplyingModifiers: []), modifiers: modifiers
        ) else { return false }

        let context = currentContext
        if context == .table, flags.contains(.command), !flags.contains(.control), event.charactersIgnoringModifiers == "b" {
            if let mainWindow = window.windowController as? MainWindowController {
                mainWindow.toggleSidebarAction()
                return true
            }
        }
        if model.handleKey(chord, context: context) { return true }
        if context == .table, modifiers.isDisjoint(with: [.command, .control, .option]),
           let characters = event.characters, characters.count == 1, let character = characters.first,
           character.isLetter || character.isNumber {
            model.typeAhead(character)
            return true
        }
        return false
    }
}
