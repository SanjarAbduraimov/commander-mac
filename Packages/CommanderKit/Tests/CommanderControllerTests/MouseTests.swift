import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct MouseTests {
    @Test func clickSetsCursorKeepsMarks() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.toggleMark(name: "a") }

        model.click(.left, row: "c.txt", modifiers: [])

        #expect(model.tab(.left).cursor == "c.txt")
        #expect(model.tab(.left).marked == ["a"])
    }

    @Test func clickActivatesPane() async {
        let model = await startedHarness().model

        model.click(.right, row: "b.txt", modifiers: [])

        #expect(model.state.activeSide == .right)
        #expect(model.tab(.right).cursor == "b.txt")
    }

    @Test func commandClickTogglesAndMovesCursor() async {
        let model = await startedHarness().model

        model.click(.left, row: "c.txt", modifiers: .command)
        #expect(model.tab(.left).marked == ["c.txt"])
        #expect(model.tab(.left).cursor == "c.txt")

        model.click(.left, row: "c.txt", modifiers: .command)
        #expect(model.tab(.left).marked.isEmpty)
    }

    @Test func shiftClickMarksRangeFromCursor() async {
        let model = await startedHarness().model
        model.click(.left, row: "b.txt", modifiers: [])

        model.click(.left, row: "d02.txt", modifiers: .shift)

        #expect(model.tab(.left).marked == ["b.txt", "c.txt", "d01.txt", "d02.txt"])
        #expect(model.tab(.left).cursor == "d02.txt")
    }

    @Test func doubleClickOpens() async {
        let harness = await startedHarness()

        harness.model.doubleClick(.right, row: "b.txt")
        harness.model.doubleClick(.left, row: "a")
        await harness.model.waitUntilIdle()

        #expect(harness.effects.opened == [root.appendingPathComponent("b.txt")])
        #expect(harness.model.tab(.left).path.standardizedFileURL.path == "/root/a")
        #expect(harness.model.state.activeSide == .left)
    }

    @Test func clickOnEmptyAreaOnlyActivates() async {
        let model = await startedHarness().model
        model.mutateTab(.right) { $0.setCursor(name: "c.txt") }

        model.click(.right, row: nil, modifiers: [])

        #expect(model.state.activeSide == .right)
        #expect(model.tab(.right).cursor == "c.txt")
    }

    @Test func sortHeaderTogglesDirection() async {
        let model = await startedHarness().model

        model.sortColumnClicked(.left, .name)
        #expect(model.tab(.left).sort == FileSort(column: .name, ascending: false))

        model.sortColumnClicked(.left, .size)
        #expect(model.tab(.left).sort == FileSort(column: .size, ascending: true))
    }

    @Test func slowClickRules() {
        func begins(clickCount: Int = 1, cursorBefore: String? = "a", paneWasActive: Bool = true, onNameText: Bool = true, modifiers: KeyChord.Modifiers = []) -> Bool {
            SlowClick.shouldBeginRename(row: "a", clickCount: clickCount, cursorBefore: cursorBefore, paneWasActive: paneWasActive, onNameText: onNameText, modifiers: modifiers)
        }

        #expect(begins())
        #expect(!begins(clickCount: 2))
        #expect(!begins(cursorBefore: "b"))
        #expect(!begins(paneWasActive: false))
        #expect(!begins(onNameText: false))
        #expect(!begins(modifiers: .command))
    }
}
