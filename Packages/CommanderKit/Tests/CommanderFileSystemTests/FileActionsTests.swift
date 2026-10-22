import Foundation
import Testing
@testable import CommanderFileSystem

struct FileActionsTests {
    @Test func createFolderPicksUniqueName() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }

        let first = try FileActions.createFolder(in: tmp.url)
        let second = try FileActions.createFolder(in: tmp.url)

        #expect(first.lastPathComponent == "untitled folder")
        #expect(second.lastPathComponent == "untitled folder 2")
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: second.path, isDirectory: &isDirectory) && isDirectory.boolValue)
    }

    @Test func renameMovesToNewName() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let file = try tmp.file("a.txt")

        let renamed = try FileActions.rename(file, to: "  b.txt ")

        #expect(renamed.lastPathComponent == "b.txt")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tmp.url.path) == ["b.txt"])
    }

    @Test func renameValidations() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let file = try tmp.file("a.txt")
        try tmp.file("taken.txt")

        #expect(throws: RenameError.empty) { try FileActions.rename(file, to: "   ") }
        #expect(throws: RenameError.invalidCharacter) { try FileActions.rename(file, to: "a/b") }
        #expect(throws: RenameError.invalidCharacter) { try FileActions.rename(file, to: "a:b") }
        #expect(throws: RenameError.alreadyExists) { try FileActions.rename(file, to: "taken.txt") }
        #expect(try FileActions.rename(file, to: "a.txt") == file)
    }

    @Test func renameCaseOnlyChangeAllowed() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let file = try tmp.file("a.txt")

        let renamed = try FileActions.rename(file, to: "A.txt")

        #expect(renamed.lastPathComponent == "A.txt")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tmp.url.path) == ["A.txt"])
    }
}
