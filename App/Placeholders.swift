import AppKit
import CommanderController
import CommanderCore

// Stand-ins until the real AppKit pieces land (effects: Task 11, prompts: Task 14, pasteboard: Task 15,
// mounter: Task 16). Their answers are the safe ones: never overwrite, never delete permanently.

@MainActor
final class PlaceholderEffects: WindowEffects {
    func stateDidChange(_ change: StateChange) {}
    func focusPathField(_ side: PaneSide) {}
    func beginRename(_ side: PaneSide, name: String) {}
    func open(_ url: URL) {}
    func revealInFinder(_ urls: [URL]) {}
    func openInTerminal(_ directory: URL) {}
    func showSettings() {}
    func showConnectToServer() {}
    func askDestination(default url: URL, kind: OperationKind, count: Int) async -> URL? { nil }
    func showAlert(_ alert: AlertMessage) {}
    func beep() { NSSound.beep() }
}

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
