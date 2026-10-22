import CommanderCore
import Darwin
import Foundation
import Testing
@testable import CommanderFileSystem

private func inode(_ url: URL) -> ino_t? {
    var info = stat()
    return lstat(url.path, &info) == 0 ? info.st_ino : nil
}

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

@Suite(.serialized)
struct MoveOperationTests {
    @Test func sameVolumeMoveIsRename() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = try tmp.file("src/a.txt", bytes: 3)
        let before = inode(source)
        let dst = try tmp.dir("dst")

        let outcome = await MoveOperation(sources: [source], destination: dst, delegate: RecordingDelegate()).run()

        #expect(outcome == .completed)
        #expect(!exists(source))
        #expect(inode(dst.appendingPathComponent("a.txt")) == before)
    }

    @Test func moveIntoSameFolderIsNoOp() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = try tmp.file("a.txt", bytes: 3)
        let delegate = RecordingDelegate()

        let outcome = await MoveOperation(sources: [source], destination: tmp.url, delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(exists(source))
        #expect(delegate.conflicts.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: tmp.url.path) == ["a.txt"])
    }

    @Test func moveConflictKeepBoth() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = tmp.url.appendingPathComponent("src/a.txt")
        try write("new", to: source)
        try write("old", to: tmp.url.appendingPathComponent("dst/a.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .keepBoth)])
        _ = await MoveOperation(sources: [source], destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(!exists(source))
        #expect(try read(tmp.url.appendingPathComponent("dst/a.txt")) == "old")
        #expect(try read(tmp.url.appendingPathComponent("dst/a 2.txt")) == "new")
    }

    @Test func moveFolderIntoItselfIsRefused() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let dir = try tmp.dir("dir")
        let sub = try tmp.dir("dir/sub")

        let delegate = RecordingDelegate()
        _ = await MoveOperation(sources: [dir], destination: sub, delegate: delegate).run()

        #expect(delegate.failures.map(\.reason) == [.destinationInsideSource])
        #expect(exists(sub))
    }

    @Test func replaceRefusesWhenExistingTargetContainsSource() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let outer = tmp.url.appendingPathComponent("A/foo")
        try write("keep", to: outer.appendingPathComponent("precious.txt"))
        try write("x", to: outer.appendingPathComponent("foo/x.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .replace)])
        _ = await MoveOperation(sources: [outer.appendingPathComponent("foo")], destination: tmp.url.appendingPathComponent("A"), delegate: delegate).run()

        #expect(delegate.failures.map(\.reason) == [.targetContainsSource])
        #expect(try read(outer.appendingPathComponent("precious.txt")) == "keep")
        #expect(try read(outer.appendingPathComponent("foo/x.txt")) == "x")
    }

    @Test func crossVolumeMoveCopiesThenDeletes() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let image = try #require(try? DiskImage(), "hdiutil could not create a disk image")
        defer { image.detach() }
        let source = tmp.url.appendingPathComponent("a.txt")
        try write("A", to: source)

        let outcome = await MoveOperation(sources: [source], destination: image.mountPoint, delegate: RecordingDelegate()).run()

        #expect(outcome == .completed)
        #expect(!exists(source))
        #expect(try read(image.mountPoint.appendingPathComponent("a.txt")) == "A")
    }

    @Test func crossVolumeCancelKeepsSources() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let image = try #require(try? DiskImage(), "hdiutil could not create a disk image")
        defer { image.detach() }
        let big = try tmp.file("big.bin", bytes: 200 * 1024 * 1024)

        let delegate = RecordingDelegate(onProgress: { progress in
            if progress.completedBytes > 0 { withUnsafeCurrentTask { $0?.cancel() } }
        })
        let outcome = await Task {
            await MoveOperation(sources: [big], destination: image.mountPoint, delegate: delegate).run()
        }.value

        #expect(outcome == .cancelled)
        #expect(exists(big))
        #expect(!exists(image.mountPoint.appendingPathComponent("big.bin")))
    }

    @Test func crossVolumeSkippedItemKeepsSource() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let image = try #require(try? DiskImage(), "hdiutil could not create a disk image")
        defer { image.detach() }
        let a = tmp.url.appendingPathComponent("a.txt")
        let b = tmp.url.appendingPathComponent("b.txt")
        try write("A", to: a)
        try write("new", to: b)
        try write("old", to: image.mountPoint.appendingPathComponent("b.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .skip)])
        let outcome = await MoveOperation(sources: [a, b], destination: image.mountPoint, delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(!exists(a))
        #expect(try read(image.mountPoint.appendingPathComponent("a.txt")) == "A")
        #expect(try read(b) == "new")
        #expect(try read(image.mountPoint.appendingPathComponent("b.txt")) == "old")
    }
}
