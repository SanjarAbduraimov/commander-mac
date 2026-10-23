import Dispatch

/// Runs blocking file-system work outside Swift's cooperative pool. That pool has one thread per
/// core, so a few copies stuck on a dead SMB share would otherwise freeze every other task;
/// a custom concurrent queue overcommits and keeps spawning threads while work is blocked.
public final class OperationExecutor: TaskExecutor, Sendable {
    public static let operations = OperationExecutor(label: "Commander.operations")
    public static let listing = OperationExecutor(label: "Commander.listing")

    private let queue: DispatchQueue

    public init(label: String) {
        queue = DispatchQueue(label: label, qos: .userInitiated, attributes: .concurrent)
    }

    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async { job.runSynchronously(on: self.asUnownedTaskExecutor()) }
    }

    public func run<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task(executorPreference: self) { try body() }.value
    }
}
