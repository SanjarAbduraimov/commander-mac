import CommanderCore

public struct ShortcutRow: Equatable, Sendable {
    public let command: Command
    public let title: String
    public let chords: [KeyChord]
    public let isCustom: Bool
}

public struct ShortcutEditor: Sendable {
    public private(set) var overrides: [Command: [KeyChord]]
    private var behavior: BehaviorSettings

    public init(behavior: BehaviorSettings, overrides: [Command: [KeyChord]]) {
        self.behavior = behavior
        self.overrides = overrides
    }

    public var bindings: KeyBindings {
        KeyBindings(defaults: KeyBindings.defaults(for: behavior), overrides: overrides)
    }

    public func rows(matching query: String) -> [ShortcutRow] {
        let bindings = bindings
        let query = query.trimmingCharacters(in: .whitespaces)
        return Command.allCases.compactMap { command in
            let row = ShortcutRow(command: command, title: command.title, chords: bindings.chords(for: command), isCustom: overrides[command] != nil)
            guard query.isEmpty
                || row.title.localizedCaseInsensitiveContains(query)
                || row.chords.contains(where: { $0.displayString.localizedCaseInsensitiveContains(query) })
            else { return nil }
            return row
        }
    }

    public func conflicts(assigning chord: KeyChord, to command: Command) -> [Command] {
        bindings.conflicts(assigning: chord, to: command)
    }

    /// The chord moves to `command`; any other override that held it gives it up.
    public mutating func assign(_ chord: KeyChord, to command: Command) {
        for (other, chords) in overrides where other != command {
            overrides[other] = chords.filter { $0 != chord }
        }
        overrides[command] = [chord]
    }

    public mutating func clear(_ command: Command) {
        overrides[command] = []
    }

    public mutating func restoreDefault(_ command: Command) {
        overrides[command] = nil
    }

    public mutating func restoreAllDefaults() {
        overrides = [:]
    }

    public mutating func setBehavior(_ behavior: BehaviorSettings) {
        self.behavior = behavior
    }
}
