import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct CutTests {
    private func item(_ model: WindowModel, _ side: PaneSide, _ name: String) -> FileItem {
        model.tab(side).items.first { $0.name == name }!
    }

    @Test func cutMarksItems() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }

        model.perform(.cutToClipboard)

        #expect(model.isCut(item(model, .left, "b.txt")))
        #expect(!model.isCut(item(model, .left, "c.txt")))
    }

    @Test func copyClearsCut() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }
        model.perform(.cutToClipboard)

        model.perform(.copyToClipboard)

        #expect(!model.isCut(item(model, .left, "b.txt")))
    }

    @Test func copyPathClearsCut() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }
        model.perform(.cutToClipboard)

        model.perform(.copyPath)

        #expect(!model.isCut(item(model, .left, "b.txt")))
    }

    @Test func pasteOfCutClearsCut() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.perform(.cutToClipboard)
        let cut = h.model.tab(.left).items[0]
        #expect(h.model.isCut(cut))

        h.model.activate(.right)
        h.model.perform(.paste)
        await h.model.waitUntilIdle()

        #expect(!h.model.isCut(cut))
        #expect(h.exists("right/a.txt"))
    }

    @Test func foreignClipboardClearsCut() async {
        let harness = await startedHarness()
        let model = harness.model
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }
        model.perform(.cutToClipboard)

        harness.pasteboard.clearCut()
        model.appDidBecomeActive()

        #expect(!model.isCut(item(model, .left, "b.txt")))
    }

    @Test func cutShowsInBothPanes() async {
        let harness = await startedHarness()
        let model = harness.model
        await model.waitUntilIdle()
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }

        model.perform(.cutToClipboard)

        #expect(model.isCut(item(model, .right, "b.txt")))
        #expect(harness.effects.changes.contains(.pane(.right)))
    }

    @Test func cutNamesAreGroupedByFolder() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.toggleMark(name: "b.txt"); $0.toggleMark(name: "c.txt") }

        model.perform(.cutToClipboard)

        #expect(model.cutNames(in: root) == ["b.txt", "c.txt"])
        #expect(model.cutNames(in: root.appendingPathComponent("a")).isEmpty)
    }
}
