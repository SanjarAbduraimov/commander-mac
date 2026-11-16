import CommanderCore
import CommanderFileSystem
import Foundation
import Synchronization

@MainActor
public protocol OperationPrompts: AnyObject {
    func resolve(_ conflict: Conflict) async -> ConflictResolution
    func decide(_ failure: OperationFailure) async -> ErrorDecision
    func confirmPermanentDelete(_ urls: [URL]) async -> Bool
}

public enum OperationRequest: Equatable, Sendable {
    case copy(sources: [URL], destination: URL)
    case move(sources: [URL], destination: URL)
    case trash([URL])
    case delete([URL])

    var kind: OperationKind {
        switch self {
        case .copy: .copy
        case .move: .move
        case .trash: .trash
        case .delete: .delete
        }
    }

    var affectedDirectories: [URL] {
        let directories: [URL] = switch self {
        case let .copy(_, destination): [destination]
        case let .move(sources, destination): [destination] + sources.map { $0.deletingLastPathComponent() }
        case let .trash(urls), let .delete(urls): urls.map { $0.deletingLastPathComponent() }
        }
        var seen = Set<String>()
        return directories.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

@MainActor
public final class OperationCenter {
    public private(set) var operations: [OperationState] = []
    public var onChange: (() -> Void)?
    public var onFinish: ((_ affectedDirectories: [URL]) -> Void)?

    private let executor: OperationExecutor
    private let prompts: any OperationPrompts
    private let trasher: any Trasher
    private var tasks: [UUID: Task<Void, Never>] = [:]
    /// The tail of the prompt queue: two operations hitting a conflict at once must not stack two dialogs.
    private var lastPrompt: Task<Void, Never>?

    public init(executor: OperationExecutor = .operations, prompts: any OperationPrompts, trasher: any Trasher = SystemTrasher()) {
        self.executor = executor
        self.prompts = prompts
        self.trasher = trasher
    }

    public var isIdle: Bool { tasks.isEmpty }

    @discardableResult
    public func start(_ request: OperationRequest) -> UUID {
        let id = UUID()
        operations.append(OperationState(id: id, kind: request.kind))
        let bridge = DelegateBridge(id: id, center: self)
        let trasher = trasher
        tasks[id] = Task(executorPreference: executor) {
            await Self.execute(request, trasher: trasher, bridge: bridge)
            await self.finish(id, affected: request.affectedDirectories)
        }
        onChange?()
        return id
    }

    public func cancel(_ id: UUID) {
        tasks[id]?.cancel()
        if let index = operations.firstIndex(where: { $0.id == id }) {
            operations.remove(at: index)
        }
        onChange?()
    }

    public func cancelAll() {
        for task in tasks.values { task.cancel() }
        operations.removeAll()
        onChange?()
    }

    public func waitUntilIdle() async {
        while let task = tasks.values.first {
            await task.value
        }
    }

    /// Nonisolated so the operation body runs on the task's preferred executor, not the main actor.
    private nonisolated static func execute(_ request: OperationRequest, trasher: any Trasher, bridge: DelegateBridge) async {
        switch request {
        case let .copy(sources, destination):
            _ = await CopyOperation(sources: sources, destination: destination, delegate: bridge).run()
        case let .move(sources, destination):
            _ = await MoveOperation(sources: sources, destination: destination, delegate: bridge).run()
        case let .delete(urls):
            _ = await DeleteOperation(items: urls, delegate: bridge).run()
        case let .trash(urls):
            let (outcome, result) = await TrashOperation(items: urls, trasher: trasher, delegate: bridge).run()
            guard outcome == .completed, !result.unsupported.isEmpty else { return }
            if await bridge.confirmPermanentDelete(result.unsupported) {
                _ = await DeleteOperation(items: result.unsupported, delegate: bridge).run()
            }
        }
    }

    private func finish(_ id: UUID, affected: [URL]) {
        tasks[id] = nil
        operations.removeAll { $0.id == id }
        onChange?()
        onFinish?(affected)
    }

    fileprivate func update(_ id: UUID, progress: OperationProgress) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].progress = progress
        onChange?()
    }

    private func setStatus(_ id: UUID, _ status: OperationStatus) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].status = status
        onChange?()
    }

    fileprivate func ask<T: Sendable>(_ id: UUID, _ body: @escaping @MainActor (any OperationPrompts) async -> T) async -> T {
        let previous = lastPrompt
        let prompt = Task { @MainActor in
            await previous?.value
            setStatus(id, .waitingForUser)
            let answer = await body(prompts)
            setStatus(id, .running)
            return answer
        }
        lastPrompt = Task { _ = await prompt.value }
        return await prompt.value
    }
}

private final class DelegateBridge: OperationDelegate {
    private static let progressInterval: Duration = .milliseconds(100)

    private let id: UUID
    private let center: OperationCenter
    private let lastProgress = Mutex<ContinuousClock.Instant?>(nil)

    init(id: UUID, center: OperationCenter) {
        self.id = id
        self.center = center
    }

    func progress(_ progress: OperationProgress) {
        let now = ContinuousClock.now
        let due = lastProgress.withLock { last in
            guard last.map({ $0.duration(to: now) >= Self.progressInterval }) ?? true else { return false }
            last = now
            return true
        }
        guard due else { return }
        Task { @MainActor [id, center] in center.update(id, progress: progress) }
    }

    func resolve(_ conflict: Conflict) async -> ConflictResolution {
        await center.ask(id) { await $0.resolve(conflict) }
    }

    func decide(_ failure: OperationFailure) async -> ErrorDecision {
        await center.ask(id) { await $0.decide(failure) }
    }

    func confirmPermanentDelete(_ urls: [URL]) async -> Bool {
        await center.ask(id) { await $0.confirmPermanentDelete(urls) }
    }
}
