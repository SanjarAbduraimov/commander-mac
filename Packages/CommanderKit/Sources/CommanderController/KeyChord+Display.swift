import CommanderCore

extension KeyChord {
    private static let modifierSymbols: [(KeyChord.Modifiers, String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]

    private static let keySymbols: [String: String] = [
        "up": "↑", "down": "↓", "left": "←", "right": "→", "home": "↖", "end": "↘",
        "pageUp": "⇞", "pageDown": "⇟", "space": "Space", "return": "↩", "tab": "Tab",
        "backspace": "⌫", "forwardDelete": "⌦", "escape": "Esc",
    ]

    public var displayString: String {
        let prefix = Self.modifierSymbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
        return prefix + (Self.keySymbols[key] ?? key.uppercased())
    }
}
