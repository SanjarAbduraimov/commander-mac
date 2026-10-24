import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct MarkPatternTests {
    private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

    @Test func markAndUnmarkByPattern() async {
        let harness = await startedHarness()
        let model = harness.model

        harness.effects.patternAnswer = "*.txt"
        model.perform(.markByPattern)
        await model.waitUntilIdle()
        #expect(model.tab(.left).marked.count == 29)
        #expect(harness.effects.patternRequests.last == PatternRequest(marking: true, recent: []))

        harness.effects.patternAnswer = "d*"
        model.perform(.unmarkByPattern)
        await model.waitUntilIdle()
        #expect(model.tab(.left).marked == ["b.txt", "c.txt"])
        #expect(model.sessionSnapshot().recentPatterns == ["d*", "*.txt"])
        #expect(harness.effects.patternRequests.last == PatternRequest(marking: false, recent: ["*.txt"]))
    }

    @Test func cancelledPatternChangesNothing() async {
        let harness = await startedHarness()
        harness.effects.patternAnswer = nil

        harness.model.perform(.markByPattern)
        await harness.model.waitUntilIdle()

        #expect(harness.model.tab(.left).marked.isEmpty)
        #expect(harness.model.sessionSnapshot().recentPatterns.isEmpty)
    }

    @Test func invertMarks() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.markAll(); $0.toggleMark(name: "b.txt") }

        model.perform(.invertMarks)

        #expect(model.tab(.left).marked == ["b.txt"])
    }

    @Test func markSameExtension() async {
        let lister = FakeLister(["/root": [item("a", .directory), item("b.txt"), item("c.TXT"), item("d.md"), item("e")]])
        let model = await startedHarness(lister).model
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }

        model.perform(.markSameExtension)
        #expect(model.tab(.left).marked == ["b.txt", "c.TXT"])

        model.mutateTab(.left) { $0.clearMarks(); $0.setCursor(name: "e") }
        model.perform(.markSameExtension)
        #expect(model.tab(.left).marked == ["e"])
    }

    @Test func phase1eDefaults() async {
        let keys = KeyBindings(defaults: KeyBindings.defaults(for: BehaviorSettings()), overrides: [:])
        let expected: [(String, Command)] = [
            ("ctrl+m", .multiRename), ("cmd+=", .markByPattern), ("cmd+-", .unmarkByPattern),
            ("cmd+shift+i", .invertMarks), ("opt+cmd+=", .markSameExtension),
        ]
        for (string, command) in expected {
            #expect(keys.command(for: chord(string), in: .table) == command, "\(string)")
        }
        #expect(Command.markByPattern.title == "Mark by Pattern…")
    }
}
