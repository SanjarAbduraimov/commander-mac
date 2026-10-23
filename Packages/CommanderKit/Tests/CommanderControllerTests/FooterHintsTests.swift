import CommanderCore
import Testing
@testable import CommanderController

struct FooterHintsTests {
    private func hints(_ behavior: BehaviorSettings = BehaviorSettings(), overrides: [Command: [KeyChord]] = [:]) -> [FooterHint] {
        FooterHints.items(bindings: KeyBindings(defaults: KeyBindings.defaults(for: behavior), overrides: overrides), behavior: behavior)
    }

    @Test func defaultHints() {
        let expected = [
            ("Space", "Mark & next"), ("Tab", "Switch pane"), ("⌫", "Parent folder"), ("F5", "Copy"),
            ("F6", "Move"), ("F7", "New folder"), ("F2", "Rename"), ("⌘⌫", "Trash"),
        ].map { FooterHint(keys: $0.0, title: $0.1) }
        #expect(hints() == expected)
    }

    @Test func hintsFollowBehaviorAndOverrides() {
        var behavior = BehaviorSettings()
        behavior.backspaceAction = .historyBack
        behavior.spaceAdvances = false

        let result = hints(behavior, overrides: [.copyToOtherPane: []])

        #expect(result.contains(FooterHint(keys: "⌫", title: "Back")))
        #expect(result.contains(FooterHint(keys: "Space", title: "Mark")))
        #expect(!result.contains { $0.title == "Copy" })
    }

    @Test func selectionSummary() {
        var tab = TabState(path: root)
        tab.apply(listing: [item("a"), item("b"), item("c"), item("d")])
        #expect(PaneText.selectionSummary(tab, side: .left) == nil)

        tab.markAll()
        tab.toggleMark(name: "d")
        #expect(PaneText.selectionSummary(tab, side: .left) == "3 marked in left pane")
        #expect(PaneText.selectionSummary(tab, side: .right) == "3 marked in right pane")
    }
}
