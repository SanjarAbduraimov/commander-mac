import CommanderCore
import CommanderFileSystem
import Foundation
import Synchronization
@testable import CommanderController

/// Answers prompts from queues given up front (skip / delete when a queue runs dry), records every call
/// and the most prompts that were open at once. In `held` mode a conflict waits until the test answers it.
@MainActor
final class FakePrompts: OperationPrompts {
    var conflictAnswers: [ConflictResolution] = []
    var errorAnswers: [ErrorDecision] = []
    var deleteAnswer = true
    var held = false
    var delay: Duration = .zero

    private(set) var conflicts: [Conflict] = []
    private(set) var failures: [OperationFailure] = []
    private(set) var deleteRequests: [[URL]] = []
    private(set) var maxConcurrent = 0
    private var active = 0
    private var heldConflict: CheckedContinuation<ConflictResolution, Never>?

    var isHoldingConflict: Bool { heldConflict != nil }

    func answerHeldConflict(_ resolution: ConflictResolution) {
        heldConflict?.resume(returning: resolution)
        heldConflict = nil
    }

    func resolve(_ conflict: Conflict) async -> ConflictResolution {
        conflicts.append(conflict)
        return await tracked {
            if held { return await withCheckedContinuation { heldConflict = $0 } }
            return conflictAnswers.isEmpty ? ConflictResolution(decision: .skip) : conflictAnswers.removeFirst()
        }
    }

    func decide(_ failure: OperationFailure) async -> ErrorDecision {
        failures.append(failure)
        return await tracked { errorAnswers.isEmpty ? .skip : errorAnswers.removeFirst() }
    }

    func confirmPermanentDelete(_ urls: [URL]) async -> Bool {
        deleteRequests.append(urls)
        return await tracked { deleteAnswer }
    }

    private func tracked<T>(_ body: () async -> T) async -> T {
        active += 1
        maxConcurrent = max(maxConcurrent, active)
        if delay > .zero { try? await Task.sleep(for: delay) }
        let result = await body()
        active -= 1
        return result
    }
}

/// Never touches the real Trash: records what it was asked to trash and on which thread.
final class FakeTrasher: Trasher {
    private let unsupported: Set<URL>
    private let log = Mutex<(trashed: [URL], onMain: [Bool])>(([], []))

    init(unsupported: Set<URL> = []) {
        self.unsupported = unsupported
    }

    func trash(_ url: URL) throws {
        log.withLock { $0.onMain.append(Thread.isMainThread) }
        if unsupported.contains(url) { throw TrashUnsupportedError() }
        log.withLock { $0.trashed.append(url) }
    }

    var trashed: [URL] { log.withLock { $0.trashed } }
    var calledOnMainThread: [Bool] { log.withLock { $0.onMain } }
}
