import CommanderCore
import Foundation
import Testing
@testable import CommanderFileSystem

private func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func names(in url: URL) throws -> Set<String> {
    Set(try FileManager.default.contentsOfDirectory(atPath: url.path))
}

struct CopyOperationTests {
    @Test func copiesFilesAndFoldersRecursively() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try write("A", to: tmp.url.appendingPathComponent("src/a.txt"))
        try write("B", to: tmp.url.appendingPathComponent("src/dir/b.txt"))
        let dst = try tmp.dir("dst")

        let outcome = await CopyOperation(
            sources: [tmp.url.appendingPathComponent("src/a.txt"), tmp.url.appendingPathComponent("src/dir")],
            destination: dst, delegate: RecordingDelegate()
        ).run()

        #expect(outcome == .completed)
        #expect(try read(dst.appendingPathComponent("a.txt")) == "A")
        #expect(try read(dst.appendingPathComponent("dir/b.txt")) == "B")
        #expect(try read(tmp.url.appendingPathComponent("src/a.txt")) == "A")
    }

    @Test func folderPermissionsAndDatesAreKept() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let folder = try tmp.dir("src/private")
        try tmp.file("src/private/key", bytes: 4)
        let modified = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.posixPermissions: 0o700, .modificationDate: modified], ofItemAtPath: folder.path)
        let dst = try tmp.dir("dst")

        _ = await CopyOperation(sources: [folder], destination: dst, delegate: RecordingDelegate()).run()

        let copied = try FileManager.default.attributesOfItem(atPath: dst.appendingPathComponent("private").path)
        #expect((copied[.posixPermissions] as? Int) == 0o700)
        #expect((copied[.modificationDate] as? Date) == modified)
    }

    @Test func reportsProgressTotals() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try tmp.file("src/a.bin", bytes: 1_000)
        let b = try tmp.file("src/b.bin", bytes: 3_000)
        let delegate = RecordingDelegate()

        _ = await CopyOperation(sources: [a, b], destination: try tmp.dir("dst"), delegate: delegate).run()

        let last = try #require(delegate.progressLog.last)
        #expect(last.totalFiles == 2)
        #expect(last.completedFiles == 2)
        #expect(last.totalBytes == 4_000)
        #expect(last.completedBytes == 4_000)
    }

    @Test func conflictReplace() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let src = tmp.url.appendingPathComponent("src/a.txt")
        try write("new", to: src)
        try write("old", to: tmp.url.appendingPathComponent("dst/a.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .replace)])
        _ = await CopyOperation(sources: [src], destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(delegate.conflicts.count == 1)
        #expect(try read(tmp.url.appendingPathComponent("dst/a.txt")) == "new")
    }

    @Test func conflictSkip() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let src = tmp.url.appendingPathComponent("src/a.txt")
        try write("new", to: src)
        try write("old", to: tmp.url.appendingPathComponent("dst/a.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .skip)])
        let outcome = await CopyOperation(sources: [src], destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(try read(tmp.url.appendingPathComponent("dst/a.txt")) == "old")
    }

    @Test func conflictKeepBoth() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let src = tmp.url.appendingPathComponent("src/a.txt")
        try write("new", to: src)
        try write("old", to: tmp.url.appendingPathComponent("dst/a.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .keepBoth)])
        _ = await CopyOperation(sources: [src], destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(try read(tmp.url.appendingPathComponent("dst/a.txt")) == "old")
        #expect(try read(tmp.url.appendingPathComponent("dst/a 2.txt")) == "new")
    }

    @Test func conflictReplaceIfOlder() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let src = tmp.url.appendingPathComponent("src/a.txt")
        let dst = tmp.url.appendingPathComponent("dst/a.txt")
        try write("new-content", to: src)
        try write("old-content", to: dst)

        let olderDate = Date(timeIntervalSince1970: 1_500_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: newerDate], ofItemAtPath: src.path)
        try FileManager.default.setAttributes([.modificationDate: olderDate], ofItemAtPath: dst.path)

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .replaceIfOlder)])
        let outcome = await CopyOperation(sources: [src], destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(try read(dst) == "new-content")
    }

    @Test func conflictReplaceIfSizeDiffers() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let src = tmp.url.appendingPathComponent("src/a.txt")
        let dst = tmp.url.appendingPathComponent("dst/a.txt")
        try write("different-size-source", to: src)
        try write("short", to: dst)

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .replaceIfSizeDiffers)])
        let outcome = await CopyOperation(sources: [src], destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(try read(dst) == "different-size-source")
    }

    @Test func applyToAllAsksOnce() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        var sources: [URL] = []
        for name in ["a", "b", "c"] {
            let src = tmp.url.appendingPathComponent("src/\(name).txt")
            try write("new", to: src)
            try write("old", to: tmp.url.appendingPathComponent("dst/\(name).txt"))
            sources.append(src)
        }

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .skip, applyToAll: true)])
        _ = await CopyOperation(sources: sources, destination: tmp.url.appendingPathComponent("dst"), delegate: delegate).run()

        #expect(delegate.conflicts.count == 1)
        for name in ["a", "b", "c"] {
            #expect(try read(tmp.url.appendingPathComponent("dst/\(name).txt")) == "old")
        }
    }

    @Test func sameFolderMakesDuplicateWithoutAsking() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let src = tmp.url.appendingPathComponent("a.txt")
        try write("A", to: src)

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .replace)])
        let outcome = await CopyOperation(sources: [src], destination: tmp.url, delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(delegate.conflicts.isEmpty)
        #expect(try read(src) == "A")
        #expect(try read(tmp.url.appendingPathComponent("a copy.txt")) == "A")
    }

    @Test func destinationInsideSourceIsRefused() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let dir = tmp.url.appendingPathComponent("dir")
        try write("x", to: dir.appendingPathComponent("sub/x.txt"))
        let sub = dir.appendingPathComponent("sub")

        let delegate = RecordingDelegate()
        _ = await CopyOperation(sources: [dir], destination: sub, delegate: delegate).run()

        #expect(delegate.failures.map(\.reason) == [.destinationInsideSource])
        #expect(try names(in: sub) == ["x.txt"])
    }

    @Test func symlinkCopiedAsLink() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let target = try tmp.file("target.txt")
        let link = tmp.url.appendingPathComponent("src/link")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let dst = try tmp.dir("dst")

        _ = await CopyOperation(sources: [link], destination: dst, delegate: RecordingDelegate()).run()

        let copied = dst.appendingPathComponent("link").path
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: copied) == FileManager.default.destinationOfSymbolicLink(atPath: link.path))
    }

    @Test func cancelRemovesPartialFileKeepsFinished() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let small = try tmp.file("src/small.txt", bytes: 10)
        let big = try tmp.file("src/big.bin", bytes: 200 * 1024 * 1024)
        let dst = try tmp.dir("dst")

        // Progress is reported on the copying task itself, so it can cancel that task mid-file.
        let delegate = RecordingDelegate(onProgress: { progress in
            if progress.currentName == "big.bin", progress.completedBytes > 10 {
                withUnsafeCurrentTask { $0?.cancel() }
            }
        })
        let outcome = await Task { await CopyOperation(sources: [small, big], destination: dst, delegate: delegate).run() }.value

        #expect(outcome == .cancelled)
        #expect(try names(in: dst) == ["small.txt"])
    }

    @Test func permissionErrorSkipContinues() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let locked = try tmp.file("src/locked.txt", bytes: 5)
        let ok = try tmp.file("src/ok.txt", bytes: 5)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        let dst = try tmp.dir("dst")

        let delegate = RecordingDelegate(decisions: [.skip])
        let outcome = await CopyOperation(sources: [locked, ok], destination: dst, delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(delegate.failures.map(\.reason) == [.permissionDenied])
        #expect(try names(in: dst) == ["ok.txt"])
    }

    @Test func permissionErrorRetryThenSkip() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let locked = try tmp.file("src/locked.txt", bytes: 5)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }

        let delegate = RecordingDelegate(decisions: [.retry, .skip])
        _ = await CopyOperation(sources: [locked], destination: try tmp.dir("dst"), delegate: delegate).run()

        #expect(delegate.failures.count == 2)
    }

    @Test func replaceRefusesWhenExistingTargetContainsSource() async throws {
        // /A/foo/foo copied into /A collides with /A/foo; replacing it would delete the source itself.
        let tmp = try TempDir()
        defer { tmp.remove() }
        let outer = tmp.url.appendingPathComponent("A/foo")
        try write("keep", to: outer.appendingPathComponent("precious.txt"))
        try write("x", to: outer.appendingPathComponent("foo/x.txt"))

        let delegate = RecordingDelegate(resolutions: [ConflictResolution(decision: .replace)])
        _ = await CopyOperation(sources: [outer.appendingPathComponent("foo")], destination: tmp.url.appendingPathComponent("A"), delegate: delegate).run()

        #expect(delegate.failures.map(\.reason) == [.targetContainsSource])
        #expect(try read(outer.appendingPathComponent("precious.txt")) == "keep")
        #expect(try read(outer.appendingPathComponent("foo/x.txt")) == "x")
    }

    @Test func symlinkIntoItsOwnTargetIsCopiedAsLink() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let sub = try tmp.dir("real/sub")
        let link = tmp.url.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tmp.url.appendingPathComponent("real"))

        let delegate = RecordingDelegate()
        let outcome = await CopyOperation(sources: [link], destination: sub, delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(delegate.failures.isEmpty)
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: sub.appendingPathComponent("link").path)) != nil)
    }

    @Test func cancelAllStopsRemainingSources() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let locked = try tmp.file("src/locked.txt", bytes: 5)
        let ok = try tmp.file("src/ok.txt", bytes: 5)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        let dst = try tmp.dir("dst")

        let outcome = await CopyOperation(sources: [locked, ok], destination: dst, delegate: RecordingDelegate(decisions: [.cancelAll])).run()

        #expect(outcome == .cancelled)
        #expect(try names(in: dst).isEmpty)
    }
}
