import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct RenameTests {
    @Test func commitRenameMovesCursorToNewName() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        let error = await h.model.commitRename(.left, from: "a.txt", to: "z.txt")

        #expect(error == nil)
        #expect(h.exists("left/z.txt") && !h.exists("left/a.txt"))
        #expect(h.names(.left) == ["b.txt", "z.txt"])
        #expect(h.model.tab(.left).cursor == "z.txt")
    }

    @Test func commitRenameReturnsValidationError() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        #expect(await h.model.commitRename(.left, from: "a.txt", to: "a/b") == .invalidCharacter)
        #expect(await h.model.commitRename(.left, from: "a.txt", to: "b.txt") == .alreadyExists)
        #expect(h.exists("left/a.txt"))
    }

    @Test func unchangedNameIsNoOp() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        #expect(await h.model.commitRename(.left, from: "a.txt", to: "a.txt") == nil)
        #expect(h.names(.left) == ["a.txt", "b.txt"])
    }

    @Test func editableLength() {
        #expect(RenameSelection.editableLength(of: "a.txt", kind: .file) == 1)
        #expect(RenameSelection.editableLength(of: "archive.tar.gz", kind: .file) == 11)
        #expect(RenameSelection.editableLength(of: ".bashrc", kind: .file) == 7)
        #expect(RenameSelection.editableLength(of: "dir", kind: .directory) == 3)
        #expect(RenameSelection.editableLength(of: "my.dir", kind: .directory) == 6)
        #expect(RenameSelection.editableLength(of: "link.d", kind: .symlink(toDirectory: true)) == 6)
        #expect(RenameSelection.editableLength(of: "X.app", kind: .package) == 1)
        #expect(RenameSelection.editableLength(of: "📁x.txt", kind: .file) == 3)
        #expect(RenameSelection.editableLength(of: "README", kind: .file) == 6)
    }

    @Test func renameMessages() {
        #expect(RenameText.message(.empty, newName: "") == "The name can't be empty.")
        #expect(RenameText.message(.invalidCharacter, newName: "a/b") == "Names can't contain “/” or “:”.")
        #expect(RenameText.message(.alreadyExists, newName: "b.txt") == "The name “b.txt” is already taken. Please choose a different name.")
        #expect(RenameText.message(.failed("Disk error"), newName: "x") == "Disk error")
    }
}
