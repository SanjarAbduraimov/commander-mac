import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

/// Serialized: the cancel tests cancel from a main-actor callback, and a parallel test writing a 200 MB
/// file on the main actor would delay that hop until the copy has already finished.
@MainActor @Suite(.serialized)
struct OperationCenterTests {
    private let bigFileBytes = 200_000_000

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @Test func copyCompletesAndReportsAffectedDirectory() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = try tmp.file("src/a.txt", bytes: 10)
        let destination = try tmp.dir("dst")
        let center = OperationCenter(prompts: FakePrompts(), trasher: FakeTrasher())
        var finished: [[String]] = []
        center.onFinish = { finished.append($0.map(\.standardizedFileURL.path)) }

        center.start(.copy(sources: [source], destination: destination))
        await center.waitUntilIdle()

        #expect(exists(destination.appendingPathComponent("a.txt")))
        #expect(center.operations.isEmpty)
        #expect(center.isIdle)
        #expect(finished == [[destination.path]])
    }

    @Test func waitingStatusWhileConflictPromptOpen() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = try tmp.file("src/a.txt", bytes: 10)
        try tmp.file("dst/a.txt")
        let prompts = FakePrompts()
        prompts.held = true
        let center = OperationCenter(prompts: prompts, trasher: FakeTrasher())

        center.start(.copy(sources: [source], destination: tmp.url.appendingPathComponent("dst")))

        #expect(await eventually { center.operations.first?.status == .waitingForUser && prompts.isHoldingConflict })
        prompts.answerHeldConflict(ConflictResolution(decision: .skip))
        await center.waitUntilIdle()
        #expect(center.operations.isEmpty)
    }

    @Test func promptsAreShownOneAtATime() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let first = try tmp.file("src1/a.txt", bytes: 10)
        let second = try tmp.file("src2/a.txt", bytes: 10)
        try tmp.file("dst/a.txt")
        let destination = tmp.url.appendingPathComponent("dst")
        let prompts = FakePrompts()
        prompts.delay = .milliseconds(50)
        let center = OperationCenter(prompts: prompts, trasher: FakeTrasher())

        center.start(.copy(sources: [first], destination: destination))
        center.start(.copy(sources: [second], destination: destination))
        await center.waitUntilIdle()

        #expect(prompts.conflicts.count == 2)
        #expect(prompts.maxConcurrent == 1)
        #expect(center.operations.isEmpty)
    }

    @Test func cancelStopsOperation() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = try tmp.file("src/big.bin", bytes: bigFileBytes)
        let destination = try tmp.dir("dst")
        let center = OperationCenter(prompts: FakePrompts(), trasher: FakeTrasher())
        // The totals report arrives just before data starts flowing; cancelling there keeps the test
        // independent of disk speed (later reports are throttled and a cached 200 MB copy can beat them).
        var id: UUID?
        center.onChange = {
            if let id, let state = center.operations.first(where: { $0.id == id }), state.progress.totalBytes > 0 {
                center.cancel(id)
            }
        }

        id = center.start(.copy(sources: [source], destination: destination))
        await center.waitUntilIdle()

        #expect(!exists(destination.appendingPathComponent("big.bin")))
        #expect(center.operations.isEmpty)
    }

    @Test func cancelAllStopsEveryOperation() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let source = try tmp.file("src/big.bin", bytes: bigFileBytes)
        let first = try tmp.dir("dst1")
        let second = try tmp.dir("dst2")
        let center = OperationCenter(prompts: FakePrompts(), trasher: FakeTrasher())
        center.onChange = {
            if center.operations.contains(where: { $0.progress.totalBytes > 0 }) { center.cancelAll() }
        }

        center.start(.copy(sources: [source], destination: first))
        center.start(.copy(sources: [source], destination: second))
        await center.waitUntilIdle()

        #expect(!exists(first.appendingPathComponent("big.bin")))
        #expect(!exists(second.appendingPathComponent("big.bin")))
        #expect(center.operations.isEmpty)
    }

    @Test func unsupportedTrashAsksThenDeletes() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let file = try tmp.file("x.txt")
        let prompts = FakePrompts()
        let center = OperationCenter(prompts: prompts, trasher: FakeTrasher(unsupported: [file]))
        var finished: [[String]] = []
        center.onFinish = { finished.append($0.map(\.standardizedFileURL.path)) }

        center.start(.trash([file]))
        await center.waitUntilIdle()

        #expect(prompts.deleteRequests == [[file]])
        #expect(!exists(file))
        #expect(finished == [[tmp.url.path]])
    }

    @Test func declinedPermanentDeleteKeepsFile() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let file = try tmp.file("x.txt")
        let prompts = FakePrompts()
        prompts.deleteAnswer = false
        let center = OperationCenter(prompts: prompts, trasher: FakeTrasher(unsupported: [file]))

        center.start(.trash([file]))
        await center.waitUntilIdle()

        #expect(prompts.deleteRequests == [[file]])
        #expect(exists(file))
    }

    @Test func operationBodyRunsOnOperationExecutor() async {
        let trasher = FakeTrasher()
        let center = OperationCenter(prompts: FakePrompts(), trasher: trasher)

        center.start(.trash([URL(fileURLWithPath: "/fake/a.txt")]))
        await center.waitUntilIdle()

        #expect(trasher.calledOnMainThread == [false])
    }
}
