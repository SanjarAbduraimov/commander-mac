public enum FocusContext: Sendable {
    case table, textField
}

public struct KeyBindings: Sendable {
    private let chordsByCommand: [Command: [KeyChord]]
    private let commandByChord: [KeyChord: Command]

    public static func defaults(for behavior: BehaviorSettings) -> [Command: [KeyChord]] {
        var table: [Command: [String]] = [
            .moveUp: ["up"], .moveDown: ["down"], .moveToStart: ["home"], .moveToEnd: ["end"],
            .pageUp: ["pageUp"], .pageDown: ["pageDown"],
            .markUp: ["shift+up"], .markDown: ["shift+down"], .toggleMark: ["space"], .markAll: ["cmd+a"],
            .open: ["return", "cmd+down"],
            .goUp: ["cmd+up"], .goBack: ["cmd+["], .goForward: ["cmd+]"],
            .switchPane: ["tab"], .newTab: ["cmd+t"], .closeTab: ["cmd+w"],
            .nextTab: ["ctrl+tab"], .previousTab: ["ctrl+shift+tab"],
            .focusPathField: ["cmd+l"], .reload: ["cmd+r"], .toggleHiddenFiles: ["cmd+shift+."],
            .copyToClipboard: ["cmd+c"], .cutToClipboard: ["cmd+x"], .paste: ["cmd+v"], .duplicate: ["cmd+d"],
            .copyToOtherPane: ["f5"], .moveToOtherPane: ["f6"], .newFolder: ["f7"],
            .rename: ["f2", "shift+f6"], .moveToTrash: ["cmd+backspace"],
            .connectToServer: ["cmd+k"], .openSettings: ["cmd+,"],
            .unmarkAll: ["escape"], .copyTo: ["opt+f5"], .moveTo: ["opt+f6"],
            .deleteImmediately: ["cmd+shift+backspace"], .calculateSize: ["opt+shift+return"], .toggleSinglePane: ["cmd+\\"],
        ]
        table[behavior.backspaceAction == .parent ? .goUp : .goBack, default: []].append("backspace")
        if behavior.forwardDeleteTrashes { table[.moveToTrash, default: []].append("forwardDelete") }
        return table.mapValues { $0.map { KeyChord(string: $0)! } }
    }

    public init(defaults: [Command: [KeyChord]], overrides: [Command: [KeyChord]]) {
        let overriddenChords = Set(overrides.values.flatMap { $0 })
        var chordsByCommand = defaults.mapValues { $0.filter { !overriddenChords.contains($0) } }
        for (command, chords) in overrides { chordsByCommand[command] = chords }

        var commandByChord: [KeyChord: Command] = [:]
        for (command, chords) in chordsByCommand {
            for chord in chords { commandByChord[chord] = command }
        }
        self.chordsByCommand = chordsByCommand
        self.commandByChord = commandByChord
    }

    public func command(for chord: KeyChord, in context: FocusContext) -> Command? {
        guard let command = commandByChord[chord] else { return nil }
        if context == .textField, !command.isAllowedInTextField { return nil }
        return command
    }

    public func chords(for command: Command) -> [KeyChord] {
        chordsByCommand[command] ?? []
    }

    public func conflicts(assigning chord: KeyChord, to command: Command) -> [Command] {
        guard let owner = commandByChord[chord], owner != command else { return [] }
        return [owner]
    }
}
