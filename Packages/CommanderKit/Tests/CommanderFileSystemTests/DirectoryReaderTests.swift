import CommanderCore
import Foundation
import Testing
@testable import CommanderFileSystem

private func byName(_ items: [FileItem]) -> [String: FileItem] {
    Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
}

struct DirectoryReaderTests {
    let reader = DirectoryReader()

    @Test func listsFilesFoldersWithMetadata() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file("a.txt", bytes: 5)
        try tmp.dir("sub")

        let items = byName(try reader.list(tmp.url))
        #expect(items.count == 2)
        #expect(items["a.txt"]?.kind == .file)
        #expect(items["a.txt"]?.size == 5)
        #expect(items["sub"]?.kind == .directory)
        #expect(items["sub"]?.size == nil)
        #expect(items["a.txt"]?.url.lastPathComponent == "a.txt")
    }

    @Test func hiddenFlagFromDotName() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file(".env")
        try tmp.file("visible")

        let items = byName(try reader.list(tmp.url))
        #expect(items[".env"]?.isHidden == true)
        #expect(items["visible"]?.isHidden == false)
    }

    @Test func symlinkKinds() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let dir = try tmp.dir("target-dir")
        let file = try tmp.file("target-file")
        let fm = FileManager.default
        try fm.createSymbolicLink(at: tmp.url.appendingPathComponent("to-dir"), withDestinationURL: dir)
        try fm.createSymbolicLink(at: tmp.url.appendingPathComponent("to-file"), withDestinationURL: file)
        try fm.createSymbolicLink(atPath: tmp.url.appendingPathComponent("broken").path, withDestinationPath: "/nonexistent/nowhere")

        let items = byName(try reader.list(tmp.url))
        #expect(items["to-dir"]?.kind == .symlink(toDirectory: true))
        #expect(items["to-file"]?.kind == .symlink(toDirectory: false))
        #expect(items["broken"]?.kind == .symlink(toDirectory: false))
    }

    @Test func appBundleIsPackage() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.dir("X.app/Contents")

        let items = byName(try reader.list(tmp.url))
        #expect(items["X.app"]?.kind == .package)
    }

    @Test func listsThroughSymlinkedDirectory() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file("real/inside.txt")
        let link = tmp.url.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tmp.url.appendingPathComponent("real"))

        #expect(try reader.list(link).map(\.name) == ["inside.txt"])
    }

    @Test func missingDirectoryThrowsNotFound() {
        #expect(throws: ListingError.notFound) {
            try reader.list(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        }
    }

    @Test func fileThrowsNotADirectory() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let file = try tmp.file("plain.txt")
        #expect(throws: ListingError.notADirectory) { try reader.list(file) }
    }

    @Test func unreadableDirectoryThrowsPermissionDenied() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let locked = try tmp.dir("locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        #expect(throws: ListingError.permissionDenied) { try reader.list(locked) }
    }

    @Test func nearestExistingDirectoryWalksUp() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try tmp.dir("a")
        let deep = a.appendingPathComponent("b/c", isDirectory: true)

        #expect(reader.nearestExistingDirectory(from: deep).path == a.path)
        #expect(reader.nearestExistingDirectory(from: a).path == a.path)
        #expect(reader.nearestExistingDirectory(from: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/x")).path == "/")
    }

    @Test func readsCreatedAndKind() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file("a.pdf", bytes: 1)
        try tmp.file("plain", bytes: 1)
        try tmp.dir("sub")

        let items = byName(try reader.list(tmp.url))
        #expect(items["a.pdf"]?.created != nil)
        #expect(items["a.pdf"]?.kindName.isEmpty == false)
        #expect(items["a.pdf"]?.kindName != "Document")
        #expect(items["plain"]?.kindName == "Document")
        #expect(items["sub"]?.kindName == "Folder")
    }
}
