import Foundation
import Testing
@testable import CommanderCore

struct UndoStackTests {
    @Test func pushAndUndoPop() {
        var stack = UndoStack(maxCapacity: 10)
        #expect(stack.canUndo == false)
        #expect(stack.canRedo == false)

        let action = UndoAction.rename(
            from: URL(fileURLWithPath: "/path/old.txt"),
            to: URL(fileURLWithPath: "/path/new.txt")
        )
        stack.push(action: action, description: "Rename old.txt to new.txt")

        #expect(stack.canUndo == true)
        #expect(stack.canRedo == false)
        #expect(stack.undoTitle == "Undo Rename old.txt to new.txt")

        guard let undone = stack.popUndo() else {
            Issue.record("Expected entry to undo")
            return
        }

        #expect(undone.description == "Rename old.txt to new.txt")
        #expect(stack.canUndo == false)
        #expect(stack.canRedo == true)
        #expect(stack.redoTitle == "Redo Rename old.txt to new.txt")

        guard let redone = stack.popRedo() else {
            Issue.record("Expected entry to redo")
            return
        }

        #expect(redone.id == undone.id)
        #expect(stack.canUndo == true)
        #expect(stack.canRedo == false)
    }

    @Test func newActionClearsRedoHistory() {
        var stack = UndoStack(maxCapacity: 5)
        stack.push(action: .copy(createdItems: [URL(fileURLWithPath: "/dst/a.txt")]), description: "Copy a.txt")
        _ = stack.popUndo()
        #expect(stack.canRedo == true)

        stack.push(action: .copy(createdItems: [URL(fileURLWithPath: "/dst/b.txt")]), description: "Copy b.txt")
        #expect(stack.canRedo == false)
    }

    @Test func capacityLimitDropsOldestEntries() {
        var stack = UndoStack(maxCapacity: 3)
        for i in 1...5 {
            stack.push(
                action: .rename(from: URL(fileURLWithPath: "/old\(i)"), to: URL(fileURLWithPath: "/new\(i)")),
                description: "Action \(i)"
            )
        }

        #expect(stack.undoEntriesCount == 3)
        #expect(stack.undoTitle == "Undo Action 5")
        _ = stack.popUndo()
        #expect(stack.undoTitle == "Undo Action 4")
        _ = stack.popUndo()
        #expect(stack.undoTitle == "Undo Action 3")
        _ = stack.popUndo()
        #expect(stack.canUndo == false)
    }
}
