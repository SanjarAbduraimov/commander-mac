import AppKit
import CommanderController
import CommanderCore

@MainActor
final class MainMenu: NSObject, NSMenuItemValidation {
    private let model: WindowModel
    private let keyRouter: KeyRouter
    private var commandItems: [NSMenuItem] = []

    init(model: WindowModel, keyRouter: KeyRouter) {
        self.model = model
        self.keyRouter = keyRouter
    }

    func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu("Commander", [
            NSMenuItem(title: "About Commander", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""),
            .separator(),
            command(.openSettings),
            .separator(),
            NSMenuItem(title: "Hide Commander", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"),
            NSMenuItem(title: "Quit Commander", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]))
        main.addItem(submenu("File", [
            command(.open), command(.openWithApp), command(.quickLook), .separator(),
            command(.newTab), command(.closeTab), .separator(),
            command(.newFolder), command(.newFile), command(.rename), command(.multiRename), command(.duplicate), .separator(),
            command(.copyToOtherPane), command(.moveToOtherPane), command(.copyTo), command(.moveTo), .separator(),
            command(.moveToTrash), command(.deleteImmediately), .separator(),
            command(.connectToServer),
        ]))
        main.addItem(submenu("Edit", [
            command(.undo),
            command(.redo),
            .separator(),
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            command(.pasteImage),
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
            .separator(),
            command(.undoMultiRename), .separator(),
            command(.markByPattern), command(.unmarkByPattern), command(.invertMarks), command(.markSameExtension),
            command(.unmarkAll), .separator(),
            command(.copyPath), command(.copyName),
        ]))
        main.addItem(submenu("View", [
            command(.toggleSinglePane), .separator(),
            command(.toggleHiddenFiles), command(.calculateSize), command(.reload),
        ]))
        main.addItem(submenu("Go", [command(.goBack), command(.goForward), command(.goUp), .separator(), command(.focusPathField), command(.openInTerminal)]))
        let transferManagerItem = NSMenuItem(title: "Background Transfer Manager…", action: #selector(openTransferManager), keyEquivalent: "b")
        transferManagerItem.keyEquivalentModifierMask = [.option, .command]
        transferManagerItem.target = self

        main.addItem(submenu("Window", [
            command(.nextTab), command(.previousTab), command(.switchPane), .separator(),
            transferManagerItem, .separator(),
            NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"),
        ]))
        refreshKeyEquivalents()
        return main
    }

    func refreshKeyEquivalents() {
        for item in commandItems {
            guard let command = commandFor(item) else { continue }
            let equivalent = model.bindings.chords(for: command).lazy.compactMap(Self.keyEquivalent).first
            item.keyEquivalent = equivalent?.key ?? ""
            item.keyEquivalentModifierMask = equivalent?.modifiers ?? []
        }
    }

    @objc func performCommand(_ sender: NSMenuItem) {
        guard let command = commandFor(sender) else { return }
        model.perform(command)
    }

    @objc func openTransferManager() {
        if let window = NSApp.keyWindow {
            TransferManagerPresenter.show(model: model, over: window)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(performCommand(_:)), let command = commandFor(menuItem) else { return true }
        return model.isEnabled(command, context: keyRouter.currentContext)
    }

    private func command(_ command: Command) -> NSMenuItem {
        let item = NSMenuItem(title: command.title, action: #selector(performCommand(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = command.rawValue
        commandItems.append(item)
        return item
    }

    private func commandFor(_ item: NSMenuItem) -> Command? {
        (item.representedObject as? String).flatMap(Command.init(rawValue:))
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    /// Plain keys (Space, Tab, ⌫, Return, arrows) get no menu equivalent: a menu would grab them before a
    /// text field could type them. F-keys and chords with a modifier are safe to show and to bind.
    static func keyEquivalent(_ chord: KeyChord) -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        var modifiers: NSEvent.ModifierFlags = []
        if chord.modifiers.contains(.control) { modifiers.insert(.control) }
        if chord.modifiers.contains(.option) { modifiers.insert(.option) }
        if chord.modifiers.contains(.shift) { modifiers.insert(.shift) }
        if chord.modifiers.contains(.command) { modifiers.insert(.command) }

        let isFunctionKey = chord.key.count > 1 && chord.key.hasPrefix("f") && Int(chord.key.dropFirst()) != nil
        guard !modifiers.isEmpty || isFunctionKey else { return nil }

        let special: [String: Int] = [
            "up": NSUpArrowFunctionKey, "down": NSDownArrowFunctionKey, "left": NSLeftArrowFunctionKey,
            "right": NSRightArrowFunctionKey, "home": NSHomeFunctionKey, "end": NSEndFunctionKey,
            "pageUp": NSPageUpFunctionKey, "pageDown": NSPageDownFunctionKey, "forwardDelete": NSDeleteFunctionKey,
        ]
        let key: String
        if let code = special[chord.key] {
            key = String(Character(UnicodeScalar(code)!))
        } else if isFunctionKey, let number = Int(chord.key.dropFirst()) {
            key = String(Character(UnicodeScalar(NSF1FunctionKey + number - 1)!))
        } else {
            switch chord.key {
            case "backspace": key = "\u{8}"
            case "return": key = "\r"
            case "tab": key = "\t"
            case "space": key = " "
            case "escape": key = "\u{1b}"
            default: key = chord.key
            }
        }
        return (key, modifiers)
    }
}
