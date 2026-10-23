import AppKit
import CommanderController
import CommanderCore

// Stand-ins until the real AppKit pieces land (prompts: Task 14, pasteboard: Task 15, mounter: Task 16). Their answers are the safe ones: never overwrite, never delete permanently.

@MainActor
final class PlaceholderPrompts: OperationPrompts {
    func resolve(_ conflict: Conflict) async -> ConflictResolution { ConflictResolution(decision: .skip) }
    func decide(_ failure: OperationFailure) async -> ErrorDecision { .cancelAll }
    func confirmPermanentDelete(_ urls: [URL]) async -> Bool { false }
}

@MainActor
final class PlaceholderPasteboard: FilePasteboard {
    func writeFiles(_ urls: [URL], cut: Bool) {}
    func writeString(_ string: String) {}
    func readFiles() -> (urls: [URL], isCut: Bool)? { nil }
    func clearCut() {}
}

struct PlaceholderMounter: ServerMounting {
    func mount(_ url: URL) async throws -> URL { throw CancellationError() }
}
