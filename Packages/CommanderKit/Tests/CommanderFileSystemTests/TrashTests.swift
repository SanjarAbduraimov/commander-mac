import CommanderCore
import Foundation
import Synchronization
import Testing
@testable import CommanderFileSystem

private struct GenericTrashError: Error {}

/// Never touches the real Trash: records what it was asked to trash, or fails for chosen URLs.
private final class FakeTrasher: Trasher {
    private let unsupported: Set<URL>
    private let failing: Set<URL>
    private let recorded = Mutex<[URL]>([])

    init(unsupported: Set<URL> = [], failing: Set<URL> = []) {
        self.unsupported = unsupported
        self.failing = failing
    }

    func trash(_ url: URL) throws {
        if unsupported.contains(url) { throw TrashUnsupportedError() }
        if failing.contains(url) { throw GenericTrashError() }
        recorded.withLock { $0.append(url) }
    }

    var trashed: [URL] { recorded.withLock { $0 } }
}

struct TrashTests {
    private let a = URL(fileURLWithPath: "/fake/a.txt")
    private let b = URL(fileURLWithPath: "/fake/b.txt")
    private let c = URL(fileURLWithPath: "/fake/c.txt")

    @Test func trashesAllSupported() async {
        let trasher = FakeTrasher()
        let (outcome, result) = await TrashOperation(items: [a, b], trasher: trasher, delegate: RecordingDelegate()).run()

        #expect(outcome == .completed)
        #expect(result == TrashResult(trashed: [a, b], unsupported: []))
        #expect(trasher.trashed == [a, b])
    }

    @Test func unsupportedCollectedNotFailed() async {
        let delegate = RecordingDelegate()
        let (outcome, result) = await TrashOperation(items: [a, b, c], trasher: FakeTrasher(unsupported: [b]), delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(result == TrashResult(trashed: [a, c], unsupported: [b]))
        #expect(delegate.failures.isEmpty)
    }

    @Test func otherErrorsAskDelegate() async {
        let delegate = RecordingDelegate(decisions: [.skip])
        let (outcome, result) = await TrashOperation(items: [a, b], trasher: FakeTrasher(failing: [a]), delegate: delegate).run()

        #expect(outcome == .completed)
        #expect(delegate.failures.map(\.url) == [a])
        #expect(result == TrashResult(trashed: [b], unsupported: []))
    }

    @Test func deleteRemovesRecursively() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let dir = try tmp.dir("dir")
        try tmp.file("dir/nested/x.txt", bytes: 3)
        let file = try tmp.file("y.txt")

        let outcome = await DeleteOperation(items: [dir, file], delegate: RecordingDelegate()).run()

        #expect(outcome == .completed)
        #expect(try FileManager.default.contentsOfDirectory(atPath: tmp.url.path).isEmpty)
    }
}
