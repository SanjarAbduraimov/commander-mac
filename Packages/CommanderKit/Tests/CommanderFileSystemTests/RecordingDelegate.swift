import CommanderCore
import Foundation
import Synchronization

/// Answers conflicts and failures from queues given up front (skip when a queue runs dry)
/// and records everything the operation reported.
final class RecordingDelegate: OperationDelegate {
    private struct State {
        var resolutions: [ConflictResolution]
        var decisions: [ErrorDecision]
        var progressLog: [OperationProgress] = []
        var conflicts: [Conflict] = []
        var failures: [OperationFailure] = []
    }

    private let state: Mutex<State>
    private let onProgress: (@Sendable (OperationProgress) -> Void)?

    init(resolutions: [ConflictResolution] = [], decisions: [ErrorDecision] = [], onProgress: (@Sendable (OperationProgress) -> Void)? = nil) {
        state = Mutex(State(resolutions: resolutions, decisions: decisions))
        self.onProgress = onProgress
    }

    func progress(_ progress: OperationProgress) {
        state.withLock { $0.progressLog.append(progress) }
        onProgress?(progress)
    }

    func resolve(_ conflict: Conflict) async -> ConflictResolution {
        state.withLock { s in
            s.conflicts.append(conflict)
            return s.resolutions.isEmpty ? ConflictResolution(decision: .skip) : s.resolutions.removeFirst()
        }
    }

    func decide(_ failure: OperationFailure) async -> ErrorDecision {
        state.withLock { s in
            s.failures.append(failure)
            return s.decisions.isEmpty ? .skip : s.decisions.removeFirst()
        }
    }

    var progressLog: [OperationProgress] { state.withLock { $0.progressLog } }
    var conflicts: [Conflict] { state.withLock { $0.conflicts } }
    var failures: [OperationFailure] { state.withLock { $0.failures } }
}
