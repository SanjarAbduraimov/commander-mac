import CommanderCore
import Foundation

public protocol Trasher: Sendable {
    func trash(_ url: URL) throws
}

/// The volume has no Trash (some network shares and external disks); the UI then offers permanent deletion.
public struct TrashUnsupportedError: Error, Sendable {
    public init() {}
}

public struct SystemTrasher: Trasher {
    public init() {}

    public func trash(_ url: URL) throws {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFeatureUnsupportedError {
            throw TrashUnsupportedError()
        }
    }
}

public struct TrashResult: Equatable, Sendable {
    public var trashed: [URL]
    public var unsupported: [URL]

    public init(trashed: [URL] = [], unsupported: [URL] = []) {
        self.trashed = trashed
        self.unsupported = unsupported
    }
}

public struct TrashOperation: Sendable {
    let items: [URL]
    let trasher: any Trasher
    let delegate: any OperationDelegate

    public init(items: [URL], trasher: any Trasher, delegate: any OperationDelegate) {
        self.items = items
        self.trasher = trasher
        self.delegate = delegate
    }

    public func run() async -> (OperationOutcome, TrashResult) {
        let cancel = CancelFlag()
        return await withTaskCancellationHandler {
            var result = TrashResult()
            var progress = OperationProgress(totalFiles: items.count)
            for item in items {
                if cancel.isSet { return (.cancelled, result) }
                var unsupported = false
                let step = await attempt(item, delegate: delegate, cancel: cancel) {
                    do {
                        try trasher.trash(item)
                    } catch is TrashUnsupportedError {
                        unsupported = true
                    }
                }
                switch step {
                case .done:
                    if unsupported { result.unsupported.append(item) } else { result.trashed.append(item) }
                case .skipped:
                    break
                case .cancelAll:
                    return (.cancelled, result)
                }
                progress.completedFiles += 1
                progress.currentName = item.lastPathComponent
                delegate.progress(progress)
            }
            return (.completed, result)
        } onCancel: {
            cancel.set()
        }
    }
}

/// Permanent and irreversible; the UI runs it only after the user confirms.
public struct DeleteOperation: Sendable {
    let items: [URL]
    let delegate: any OperationDelegate

    public init(items: [URL], delegate: any OperationDelegate) {
        self.items = items
        self.delegate = delegate
    }

    public func run() async -> OperationOutcome {
        let cancel = CancelFlag()
        return await withTaskCancellationHandler {
            var progress = OperationProgress(totalFiles: items.count)
            for item in items {
                if cancel.isSet { return .cancelled }
                let step = await attempt(item, delegate: delegate, cancel: cancel) {
                    try FileManager.default.removeItem(at: item)
                }
                if step == .cancelAll { return .cancelled }
                progress.completedFiles += 1
                progress.currentName = item.lastPathComponent
                delegate.progress(progress)
            }
            return .completed
        } onCancel: {
            cancel.set()
        }
    }
}
