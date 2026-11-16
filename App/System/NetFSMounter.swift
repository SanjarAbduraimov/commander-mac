import CommanderController
import Foundation
import NetFS

/// Protects a CheckedContinuation from being resumed more than once across concurrent callbacks.
private final class AtomicContinuation<T: Sendable, E: Error>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, E>?

    init(_ continuation: CheckedContinuation<T, E>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(returning: value)
        continuation = nil
    }

    func resume(throwing error: E) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

/// Mounts SMB shares through NetFS so macOS shows its own login dialog and reports where the share landed
/// (`NSWorkspace.open(smb://…)` would open a Finder window and never say).
struct NetFSMounter: ServerMounting {
    private static let userCancelled: Int32 = -128

    func mount(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let safeContinuation = AtomicContinuation(continuation)
            let openOptions = NSMutableDictionary()
            openOptions[kNAUIOptionKey] = kNAUIOptionAllowUI
            var requestID: AsyncRequestID?
            let started = NetFSMountURLAsync(url as CFURL, nil, nil, nil, openOptions, nil, &requestID, .main) { status, _, mountpoints in
                if let path = (mountpoints as? [String])?.first, status == 0 || status == EEXIST {
                    safeContinuation.resume(returning: URL(fileURLWithPath: path, isDirectory: true))
                } else {
                    safeContinuation.resume(throwing: Self.error(for: status))
                }
            }
            // A non-zero start means the report block will never run.
            if started != 0 { safeContinuation.resume(throwing: Self.error(for: started)) }
        }
    }

    private static func error(for status: Int32) -> any Error {
        if status == ECANCELED || status == userCancelled { return CancellationError() }
        let domain = (1...ELAST).contains(status) ? NSPOSIXErrorDomain : NSOSStatusErrorDomain
        return NSError(domain: domain, code: Int(status))
    }
}
