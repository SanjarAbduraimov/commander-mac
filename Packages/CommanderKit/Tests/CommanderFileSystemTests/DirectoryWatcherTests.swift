import Foundation
import Synchronization
import Testing
@testable import CommanderFileSystem

private final class CallCounter: Sendable {
    private let count = Mutex(0)
    func increment() { count.withLock { $0 += 1 } }
    var value: Int { count.withLock { $0 } }
    func reset() { count.withLock { $0 = 0 } }
}

private func waitUntil(_ timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition(), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(20))
    }
}

/// FSEvents needs a moment after start, and may still deliver changes made just before it
/// (creating the temp directory); tests count only what happens after the warm-up.
private func warmUp(_ calls: CallCounter) async throws {
    try await Task.sleep(for: .milliseconds(300))
    calls.reset()
}

@Suite(.serialized)
struct DirectoryWatcherTests {
    @Test func fileCreationTriggersChange() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let calls = CallCounter()
        let watcher = DirectoryWatcher(directory: tmp.url) { calls.increment() }
        watcher.start()
        defer { watcher.stop() }
        try await warmUp(calls)

        try tmp.file("new.txt")
        try await waitUntil { calls.value > 0 }
        #expect(calls.value > 0)
    }

    @Test func burstCoalescesIntoFewCallbacks() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let calls = CallCounter()
        let watcher = DirectoryWatcher(directory: tmp.url) { calls.increment() }
        watcher.start()
        defer { watcher.stop() }
        try await warmUp(calls)

        for i in 0..<50 { try tmp.file("burst-\(i).txt") }
        try await Task.sleep(for: .seconds(1))
        #expect(calls.value >= 1)
        #expect(calls.value <= 3)
    }

    @Test func changesInSubfolderAreIgnored() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.dir("sub")
        let calls = CallCounter()
        let watcher = DirectoryWatcher(directory: tmp.url) { calls.increment() }
        watcher.start()
        defer { watcher.stop() }
        try await warmUp(calls)

        try tmp.file("sub/x.txt")
        try await Task.sleep(for: .seconds(1))
        #expect(calls.value == 0)
    }

    @Test func deletingWatchedDirectoryTriggersChange() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let watched = try tmp.dir("watched")
        let calls = CallCounter()
        let watcher = DirectoryWatcher(directory: watched) { calls.increment() }
        watcher.start()
        defer { watcher.stop() }
        try await warmUp(calls)

        try FileManager.default.removeItem(at: watched)
        try await waitUntil { calls.value > 0 }
        #expect(calls.value > 0)
    }

    @Test func stopPreventsFurtherCallbacks() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let calls = CallCounter()
        let watcher = DirectoryWatcher(directory: tmp.url) { calls.increment() }
        watcher.start()
        try await warmUp(calls)
        watcher.stop()

        try tmp.file("after-stop.txt")
        try await Task.sleep(for: .seconds(1))
        #expect(calls.value == 0)
    }
}
