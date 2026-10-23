import Testing
@testable import CommanderCore

private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

private func bindings(_ behavior: BehaviorSettings = BehaviorSettings(), overrides: [Command: [KeyChord]] = [:]) -> KeyBindings {
    KeyBindings(defaults: KeyBindings.defaults(for: behavior), overrides: overrides)
}

struct KeyBindingsTests {
    @Test func everySpecDefaultResolves() {
        let expected: [(String, Command)] = [
            ("up", .moveUp), ("down", .moveDown), ("home", .moveToStart), ("end", .moveToEnd),
            ("pageUp", .pageUp), ("pageDown", .pageDown),
            ("shift+up", .markUp), ("shift+down", .markDown), ("space", .toggleMark), ("cmd+a", .markAll),
            ("return", .open), ("cmd+down", .open),
            ("backspace", .goUp), ("cmd+up", .goUp), ("cmd+[", .goBack), ("cmd+]", .goForward),
            ("tab", .switchPane), ("cmd+t", .newTab), ("cmd+w", .closeTab),
            ("ctrl+tab", .nextTab), ("ctrl+shift+tab", .previousTab),
            ("cmd+l", .focusPathField), ("cmd+r", .reload), ("cmd+shift+.", .toggleHiddenFiles),
            ("cmd+c", .copyToClipboard), ("cmd+x", .cutToClipboard), ("cmd+v", .paste), ("cmd+d", .duplicate),
            ("f5", .copyToOtherPane), ("f6", .moveToOtherPane), ("f7", .newFolder),
            ("f2", .rename), ("shift+f6", .rename),
            ("cmd+backspace", .moveToTrash), ("forwardDelete", .moveToTrash),
            ("cmd+k", .connectToServer), ("cmd+,", .openSettings),
        ]
        let keys = bindings()
        for (string, command) in expected {
            #expect(keys.command(for: chord(string), in: .table) == command, "\(string)")
        }
    }

    @Test func menuOnlyCommandsHaveNoDefaultChord() {
        let keys = bindings()
        for command in [Command.copyPath, .copyName, .showPackageContents, .revealInFinder, .openInTerminal] {
            #expect(keys.chords(for: command).isEmpty)
        }
    }

    @Test func backspaceFollowsBehavior() {
        var behavior = BehaviorSettings()
        behavior.backspaceAction = .historyBack
        let keys = bindings(behavior)
        #expect(keys.command(for: chord("backspace"), in: .table) == .goBack)
        #expect(keys.command(for: chord("cmd+up"), in: .table) == .goUp)
    }

    @Test func forwardDeleteCanBeDisabled() {
        var behavior = BehaviorSettings()
        behavior.forwardDeleteTrashes = false
        let keys = bindings(behavior)
        #expect(keys.command(for: chord("forwardDelete"), in: .table) == nil)
        #expect(keys.command(for: chord("cmd+backspace"), in: .table) == .moveToTrash)
    }

    @Test func defaultsHaveNoDuplicateChords() {
        let all = KeyBindings.defaults(for: BehaviorSettings()).values.flatMap { $0 }
        #expect(all.count == Set(all).count)
    }

    @Test func overrideReplacesCommandChords() {
        let keys = bindings(overrides: [.newTab: [chord("cmd+n")]])
        #expect(keys.command(for: chord("cmd+t"), in: .table) == nil)
        #expect(keys.command(for: chord("cmd+n"), in: .table) == .newTab)
        #expect(keys.chords(for: .newTab) == [chord("cmd+n")])
    }

    @Test func overrideStealsChordFromDefault() {
        let keys = bindings(overrides: [.reload: [chord("cmd+d")]])
        #expect(keys.command(for: chord("cmd+d"), in: .table) == .reload)
        #expect(!keys.chords(for: .duplicate).contains(chord("cmd+d")))
    }

    @Test func textFieldOnlyAllowsWhitelisted() {
        let keys = bindings()
        #expect(keys.command(for: chord("backspace"), in: .textField) == nil)
        #expect(keys.command(for: chord("cmd+a"), in: .textField) == nil)
        #expect(keys.command(for: chord("space"), in: .textField) == nil)
        #expect(keys.command(for: chord("cmd+backspace"), in: .textField) == nil)
        #expect(keys.command(for: chord("cmd+t"), in: .textField) == .newTab)
        #expect(keys.command(for: chord("cmd+,"), in: .textField) == .openSettings)
    }

    @Test func conflictsListsOtherOwners() {
        let keys = bindings()
        #expect(keys.conflicts(assigning: chord("cmd+d"), to: .reload) == [.duplicate])
        #expect(keys.conflicts(assigning: chord("cmd+d"), to: .duplicate).isEmpty)
        #expect(keys.conflicts(assigning: chord("cmd+j"), to: .reload).isEmpty)
    }

    @Test func phase1cDefaults() {
        let expected: [(String, Command)] = [
            ("escape", .unmarkAll), ("opt+f5", .copyTo), ("opt+f6", .moveTo),
            ("cmd+shift+backspace", .deleteImmediately), ("opt+shift+return", .calculateSize), ("cmd+\\", .toggleSinglePane),
            ("cmd+a", .markAll), ("cmd+backspace", .moveToTrash), ("f5", .copyToOtherPane),
        ]
        let keys = bindings()
        for (string, command) in expected {
            #expect(keys.command(for: chord(string), in: .table) == command, "\(string)")
        }
    }

    @Test func escapeIsNotATextFieldCommand() {
        let keys = bindings()
        #expect(keys.command(for: chord("escape"), in: .textField) == nil)
        #expect(keys.command(for: chord("cmd+\\"), in: .textField) == .toggleSinglePane)
    }
}
