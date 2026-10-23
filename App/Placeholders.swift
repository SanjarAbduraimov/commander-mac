import AppKit
import CommanderController
import CommanderCore

// Stand-ins until the real AppKit pieces land (pasteboard: Task 15, mounter: Task 16).

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
