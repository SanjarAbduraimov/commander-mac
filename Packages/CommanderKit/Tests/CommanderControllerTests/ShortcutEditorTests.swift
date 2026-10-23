import CommanderCore
import Testing
@testable import CommanderController

struct ShortcutEditorTests {
    private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

    @Test func rowsFilterByTitleAndChord() {
        let editor = ShortcutEditor(behavior: BehaviorSettings(), overrides: [:])

        #expect(editor.rows(matching: "trash").map(\.command) == [.moveToTrash])
        #expect(editor.rows(matching: "⌘D").map(\.command) == [.duplicate])
        #expect(editor.rows(matching: "").map(\.command) == Command.allCases)
        #expect(editor.rows(matching: "TRASH").first?.chords == [chord("cmd+backspace"), chord("forwardDelete")])
    }

    @Test func assignReportsAndStealsConflict() {
        var editor = ShortcutEditor(behavior: BehaviorSettings(), overrides: [:])

        #expect(editor.conflicts(assigning: chord("cmd+d"), to: .reload) == [.duplicate])
        editor.assign(chord("cmd+d"), to: .reload)

        #expect(editor.bindings.command(for: chord("cmd+d"), in: .table) == .reload)
        #expect(!editor.bindings.chords(for: .duplicate).contains(chord("cmd+d")))
        #expect(editor.rows(matching: "Reload").first?.isCustom == true)
        #expect(editor.rows(matching: "Duplicate").first?.isCustom == false)
    }

    @Test func assignRemovesChordFromOtherOverrides() {
        var editor = ShortcutEditor(behavior: BehaviorSettings(), overrides: [.newTab: [chord("cmd+n")]])

        editor.assign(chord("cmd+n"), to: .reload)

        #expect(editor.overrides[.newTab] == [])
        #expect(editor.overrides[.reload] == [chord("cmd+n")])
    }

    @Test func restoreDefaultAndAll() {
        var editor = ShortcutEditor(behavior: BehaviorSettings(), overrides: [:])
        editor.assign(chord("cmd+n"), to: .reload)
        editor.clear(.duplicate)
        #expect(editor.bindings.chords(for: .duplicate).isEmpty)

        editor.restoreDefault(.duplicate)
        #expect(editor.bindings.chords(for: .duplicate) == [chord("cmd+d")])
        #expect(editor.overrides[.reload] != nil)

        editor.restoreAllDefaults()
        #expect(editor.overrides.isEmpty)
    }

    @Test func behaviorChangesBackspaceDefault() {
        var editor = ShortcutEditor(behavior: BehaviorSettings(), overrides: [:])
        var behavior = BehaviorSettings()
        behavior.backspaceAction = .historyBack

        editor.setBehavior(behavior)

        #expect(editor.rows(matching: "Back").first { $0.command == .goBack }?.chords.contains(chord("backspace")) == true)
        #expect(editor.bindings.chords(for: .goUp) == [chord("cmd+up")])
    }
}
