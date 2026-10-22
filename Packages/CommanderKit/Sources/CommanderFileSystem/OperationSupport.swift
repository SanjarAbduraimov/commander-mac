import CommanderCore
import Darwin
import Foundation
import Synchronization

/// Set from a task-cancellation handler, read from synchronous copy loops and copyfile callbacks.
final class CancelFlag: Sendable {
    private let value = Mutex(false)
    func set() { value.withLock { $0 = true } }
    var isSet: Bool { value.withLock { $0 } }
}

enum StepResult {
    case done
    /// Something under this item was skipped, so the item was not fully processed.
    case skipped
    case cancelAll
}

/// Runs `body`, asking the delegate what to do on failure until it succeeds, is skipped or everything is cancelled.
func attempt(_ url: URL, delegate: any OperationDelegate, cancel: CancelFlag, _ body: () throws -> Void) async -> StepResult {
    while true {
        do {
            try body()
            return .done
        } catch {
            if cancel.isSet || error is CancellationError { return .cancelAll }
            switch await delegate.decide(OperationFailure(url: url, reason: failureReason(error))) {
            case .retry: continue
            case .skip: return .skipped
            case .cancelAll: return .cancelAll
            }
        }
    }
}

func failureReason(_ error: Error) -> OperationFailure.Reason {
    let nsError = error as NSError
    var code: Int32?
    if let posix = error as? POSIXError {
        code = posix.code.rawValue
    } else if nsError.domain == NSPOSIXErrorDomain {
        code = Int32(nsError.code)
    } else if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError, underlying.domain == NSPOSIXErrorDomain {
        code = Int32(underlying.code)
    } else if nsError.domain == NSCocoaErrorDomain {
        switch nsError.code {
        case NSFileReadNoPermissionError, NSFileWriteNoPermissionError: code = EACCES
        case NSFileWriteOutOfSpaceError: code = ENOSPC
        default: break
        }
    }
    switch code {
    case EACCES, EPERM: return .permissionDenied
    case EBUSY, ETXTBSY: return .fileBusy
    case ENOSPC: return .diskFull
    default: return .other(nsError.localizedDescription)
    }
}

/// Like fileExists, but true for broken symlinks too: a name that is taken is taken.
func pathExists(_ url: URL) -> Bool {
    var info = stat()
    return lstat(url.path, &info) == 0
}

/// Resolves symlinks and /private aliases so two spellings of one directory compare equal.
func canonicalPath(_ url: URL) -> String {
    guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL.path }
    defer { free(resolved) }
    return String(cString: resolved)
}
