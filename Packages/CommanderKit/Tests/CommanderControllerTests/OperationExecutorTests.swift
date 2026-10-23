import Dispatch
import Foundation
import Synchronization
import Testing
@testable import CommanderController

private struct BodyError: Error, Equatable {}

@MainActor
struct OperationExecutorTests {
    @Test func runExecutesOffMainThreadOnItsQueue() async throws {
        let executor = OperationExecutor(label: "test.executor")

        let (isMain, label) = try await executor.run {
            (Thread.isMainThread, String(cString: __dispatch_queue_get_label(nil)))
        }

        #expect(isMain == false)
        #expect(label == "test.executor")
    }

    @Test func runRethrowsBodyError() async {
        let executor = OperationExecutor(label: "test.executor")

        await #expect(throws: BodyError()) {
            try await executor.run { throw BodyError() }
        }
    }

    @Test func doesNotCapThreadsAtCoreCount() async {
        let executor = OperationExecutor(label: "test.blocking")
        let n = ProcessInfo.processInfo.activeProcessorCount + 4
        let gate = DispatchSemaphore(value: 0)
        let entered = Atomic<Int>(0)

        let tasks = (0..<n).map { _ in
            Task { try await executor.run { entered.add(1, ordering: .relaxed); gate.wait() } }
        }

        let allEntered = await eventually(timeout: .seconds(5)) { entered.load(ordering: .relaxed) == n }
        for _ in 0..<n { gate.signal() }
        for task in tasks { _ = try? await task.value }

        #expect(allEntered)
    }

    @Test func cooperativePoolStaysResponsiveWhileBlocked() async {
        let executor = OperationExecutor(label: "test.blocking")
        let n = ProcessInfo.processInfo.activeProcessorCount + 4
        let gate = DispatchSemaphore(value: 0)
        let entered = Atomic<Int>(0)

        let tasks = (0..<n).map { _ in
            Task { try await executor.run { entered.add(1, ordering: .relaxed); gate.wait() } }
        }
        _ = await eventually(timeout: .seconds(5)) { entered.load(ordering: .relaxed) == n }

        let finished = Atomic<Bool>(false)
        Task.detached { finished.store(true, ordering: .relaxed) }
        let responsive = await eventually(timeout: .seconds(1)) { finished.load(ordering: .relaxed) }

        for _ in 0..<n { gate.signal() }
        for task in tasks { _ = try? await task.value }

        #expect(responsive)
    }
}
