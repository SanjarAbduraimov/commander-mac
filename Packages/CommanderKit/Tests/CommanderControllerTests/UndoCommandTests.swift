import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct UndoCommandTests {
    @Test func undoAndRedoRename() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        #expect(h.model.isEnabled(.undo, context: .table) == false)
        #expect(h.model.isEnabled(.redo, context: .table) == false)

        let error = await h.model.commitRename(.left, from: "a.txt", to: "renamed.txt")
        #expect(error == nil)
        #expect(h.exists("left/renamed.txt"))
        #expect(!h.exists("left/a.txt"))

        #expect(h.model.isEnabled(.undo, context: .table) == true)
        #expect(h.model.isEnabled(.redo, context: .table) == false)

        // Undo -> restores a.txt
        h.model.perform(.undo)
        // Wait for async task inside performUndo to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(h.exists("left/a.txt"))
        #expect(!h.exists("left/renamed.txt"))
        #expect(h.model.isEnabled(.undo, context: .table) == false)
        #expect(h.model.isEnabled(.redo, context: .table) == true)

        // Redo -> renames back to renamed.txt
        h.model.perform(.redo)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(h.exists("left/renamed.txt"))
        #expect(!h.exists("left/a.txt"))
    }
}
