import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct Phase1CCommandTests {
    private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

    @Test func escapeUnmarksAll() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.toggleMark(name: "b.txt"); $0.toggleMark(name: "c.txt") }

        #expect(model.handleKey(chord("escape"), context: .table))
        #expect(model.tab(.left).marked.isEmpty)
    }

    @Test func escapeWithNothingMarkedIsNotHandled() async {
        let model = await startedHarness().model
        #expect(!model.handleKey(chord("escape"), context: .table))
    }

    @Test func escapeInTextFieldDoesNotUnmark() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.toggleMark(name: "b.txt") }

        #expect(!model.handleKey(chord("escape"), context: .textField))
        #expect(model.tab(.left).marked == ["b.txt"])
    }

    @Test func deleteImmediatelyAsksThenDeletes() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.harness.effects.deleteAnswer = true

        h.model.perform(.deleteImmediately)
        await h.model.waitUntilIdle()

        #expect(!h.exists("left/a.txt"))
        #expect(h.exists("left/b.txt"))
        #expect(h.harness.trasher.trashed.isEmpty)
        #expect(h.harness.effects.deleteRequests.map { $0.map(\.lastPathComponent) } == [["a.txt"]])
    }

    @Test func declinedDeleteImmediatelyKeepsFiles() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.harness.effects.deleteAnswer = false
        h.model.mutateTab(.left) { $0.toggleMark(name: "a.txt") }

        h.model.perform(.deleteImmediately)
        await h.model.waitUntilIdle()

        #expect(h.exists("left/a.txt"))
        #expect(h.model.tab(.left).marked == ["a.txt"])
        #expect(h.harness.effects.deleteRequests.count == 1)
    }

    @Test func contextMenuListsDeleteImmediately() async {
        let model = await startedHarness().model
        let menu = model.contextMenu(.left, row: "b.txt")
        var entries: [MenuEntry] = []
        for item in menu { if case let .entry(entry) = item { entries.append(entry) } }

        let trash = entries.firstIndex { $0.command == .moveToTrash }
        #expect(trash.map { entries[$0 + 1].command } == .deleteImmediately)
        #expect(entries.first { $0.command == .deleteImmediately }?.shortcut == "⇧⌘⌫")
    }
}
