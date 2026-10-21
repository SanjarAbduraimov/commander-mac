public struct KeyChord: Hashable, Sendable, Codable, CustomStringConvertible {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    private static let modifierNames: [(String, Modifiers)] = [
        ("ctrl", .control), ("opt", .option), ("shift", .shift), ("cmd", .command),
    ]

    private static let namedKeys: Set<String> = Set([
        "up", "down", "left", "right", "home", "end", "pageUp", "pageDown",
        "space", "return", "tab", "backspace", "forwardDelete", "escape",
    ] + (1...12).map { "f\($0)" })

    public let key: String
    public let modifiers: Modifiers

    public init(_ key: String, _ modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    public init?(string: String) {
        var parts = string.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let rawKey = parts.popLast(), let key = Self.normalizedKey(rawKey) else { return nil }
        var modifiers: Modifiers = []
        for part in parts {
            guard let modifier = Self.modifierNames.first(where: { $0.0 == part.lowercased() })?.1 else { return nil }
            modifiers.insert(modifier)
        }
        self.init(key, modifiers)
    }

    public var description: String {
        let names = Self.modifierNames.filter { modifiers.contains($0.1) }.map(\.0)
        return (names + [key]).joined(separator: "+")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let chord = KeyChord(string: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid key chord \"\(string)\"")
        }
        self = chord
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    private static func normalizedKey(_ raw: String) -> String? {
        if raw.count == 1 { return raw.lowercased() }
        return namedKeys.first { $0.lowercased() == raw.lowercased() }
    }
}
