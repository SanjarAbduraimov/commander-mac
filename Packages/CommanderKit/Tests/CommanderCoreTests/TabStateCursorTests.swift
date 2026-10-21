import Testing
@testable import CommanderCore

struct TabStateCursorTests {
    @Test func moveCursorClampsAtEdges() {
        var state = tab(items: "a", "b", "c")
        state.moveCursor(by: -1)
        #expect(state.cursor == "a")
        state.moveCursor(by: 10)
        #expect(state.cursor == "c")
        state.moveCursorToStart()
        #expect(state.cursor == "a")
        state.moveCursorToEnd()
        #expect(state.cursor == "c")
    }

    @Test func moveCursorKeepsMarks() {
        var state = tab(items: "a", "b", "c")
        state.marked = ["a"]
        state.moveCursor(by: 2)
        #expect(state.marked == ["a"])
    }

    @Test func setCursorIgnoresUnknownName() {
        var state = tab(items: "a", "b")
        state.setCursor(name: "b")
        #expect(state.cursor == "b")
        state.setCursor(name: "zzz")
        #expect(state.cursor == "b")
    }

    @Test func spaceTogglesAndAdvances() {
        var state = tab(items: "a", "b", "c")
        state.toggleMark(advance: true)
        #expect(state.marked == ["a"])
        #expect(state.cursor == "b")
        state.setCursor(name: "a")
        state.toggleMark(advance: true)
        #expect(state.marked.isEmpty)
    }

    @Test func spaceWithoutAdvanceStays() {
        var state = tab(items: "a", "b")
        state.toggleMark(advance: false)
        #expect(state.marked == ["a"])
        #expect(state.cursor == "a")
    }

    @Test func spaceOnLastRowStaysOnLastRow() {
        var state = tab(items: "a", "b")
        state.moveCursorToEnd()
        state.toggleMark(advance: true)
        #expect(state.marked == ["b"])
        #expect(state.cursor == "b")
    }

    @Test func shiftDownMarksPassedRows() {
        var state = tab(items: "a", "b", "c", "d")
        state.moveCursorMarking(by: 1)
        state.moveCursorMarking(by: 1)
        #expect(state.marked == ["a", "b", "c"])
        #expect(state.cursor == "c")
    }

    @Test func shiftUpMarksPassedRows() {
        var state = tab(items: "a", "b", "c")
        state.moveCursorToEnd()
        state.moveCursorMarking(by: -1)
        #expect(state.marked == ["c", "b"])
        #expect(state.cursor == "b")
    }

    @Test func markRangeFromCursor() {
        var state = tab(items: "a", "b", "c", "d", "e")
        state.setCursor(name: "b")
        state.markRange(toName: "d")
        #expect(state.marked == ["b", "c", "d"])
        #expect(state.cursor == "d")

        var reverse = tab(items: "a", "b", "c", "d", "e")
        reverse.setCursor(name: "d")
        reverse.markRange(toName: "b")
        #expect(reverse.marked == ["b", "c", "d"])
        #expect(reverse.cursor == "b")
    }

    @Test func commandClickTogglesSingleRow() {
        var state = tab(items: "a", "b", "c")
        state.toggleMark(name: "c")
        #expect(state.marked == ["c"])
        #expect(state.cursor == "a")
        state.toggleMark(name: "c")
        #expect(state.marked.isEmpty)
    }

    @Test func markAllAndClear() {
        var state = tab(items: "a", "b", "c")
        state.markAll()
        #expect(state.marked == ["a", "b", "c"])
        state.clearMarks()
        #expect(state.marked.isEmpty)
    }

    @Test func cursorOperationsOnEmptyListingDoNothing() {
        var state = tab(items: ".hidden")
        state.moveCursor(by: 1)
        state.moveCursorToStart()
        state.moveCursorToEnd()
        state.toggleMark(advance: true)
        state.moveCursorMarking(by: 1)
        state.markRange(toName: ".hidden")
        state.toggleMark(name: ".hidden")
        state.markAll()
        #expect(state.cursor == nil)
        #expect(state.marked.isEmpty)
    }
}
