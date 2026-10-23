import AppKit
import CommanderController
import CommanderCore

// Stand-ins until the real AppKit pieces land (mounter: Task 16).

struct PlaceholderMounter: ServerMounting {
    func mount(_ url: URL) async throws -> URL { throw CancellationError() }
}
