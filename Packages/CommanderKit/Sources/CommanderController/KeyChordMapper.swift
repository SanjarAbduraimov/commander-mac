import CommanderCore

public enum KeyChordMapper {
    private static let namedKeyCodes: [UInt16: String] = [
        126: "up", 125: "down", 123: "left", 124: "right",
        115: "home", 119: "end", 116: "pageUp", 121: "pageDown",
        36: "return", 76: "return", 48: "tab", 49: "space",
        51: "backspace", 117: "forwardDelete", 53: "escape",
        122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
        98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
    ]

    /// `baseCharacters` comes from `event.characters(byApplyingModifiers: [])` (shift not applied either),
    /// so shift+. stays "." and matches the stored "cmd+shift+." chord.
    public static func chord(keyCode: UInt16, baseCharacters: String?, modifiers: KeyChord.Modifiers) -> KeyChord? {
        if let named = namedKeyCodes[keyCode] { return KeyChord(named, modifiers) }
        guard let characters = baseCharacters, characters.count == 1 else { return nil }
        return KeyChord(characters.lowercased(), modifiers)
    }
}
