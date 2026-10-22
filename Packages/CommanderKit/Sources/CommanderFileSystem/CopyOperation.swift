import CommanderCore
import Darwin
import Foundation

public struct CopyOperation: Sendable {
    let sources: [URL]
    let destination: URL
    let delegate: any OperationDelegate

    public init(sources: [URL], destination: URL, delegate: any OperationDelegate) {
        self.sources = sources
        self.destination = destination
        self.delegate = delegate
    }

    public func run() async -> OperationOutcome {
        await runReportingCopied().outcome
    }

    /// MoveOperation deletes only the sources listed in `copied`.
    func runReportingCopied() async -> (outcome: OperationOutcome, copied: [URL]) {
        let cancel = CancelFlag()
        return await withTaskCancellationHandler {
            await CopyRun(destination: destination, delegate: delegate, cancel: cancel).run(sources)
        } onCancel: {
            cancel.set()
        }
    }
}

private final class CopyRun {
    private let destination: URL
    private let delegate: any OperationDelegate
    private let cancel: CancelFlag
    private var progress = OperationProgress()
    private var conflictDecisionForAll: ConflictDecision?

    init(destination: URL, delegate: any OperationDelegate, cancel: CancelFlag) {
        self.destination = destination
        self.delegate = delegate
        self.cancel = cancel
    }

    func run(_ sources: [URL]) async -> (outcome: OperationOutcome, copied: [URL]) {
        var accepted: [URL] = []
        for source in sources {
            if isSameOrInside(destination, source) {
                // Copying a folder into itself would recurse forever; retry cannot help, so it is a skip.
                let decision = await delegate.decide(OperationFailure(url: source, reason: .destinationInsideSource))
                if decision == .cancelAll { return (.cancelled, []) }
                continue
            }
            accepted.append(source)
        }

        for source in accepted {
            let (files, bytes) = Self.totals(source.path)
            progress.totalFiles += files
            progress.totalBytes += bytes
        }
        delegate.progress(progress)

        var copied: [URL] = []
        for source in accepted {
            if cancel.isSet { return (.cancelled, copied) }
            switch await copyTopLevel(source) {
            case .done: copied.append(source)
            case .skipped: break
            case .cancelAll: return (.cancelled, copied)
            }
        }
        return (cancel.isSet ? .cancelled : .completed, copied)
    }

    private func copyTopLevel(_ source: URL) async -> StepResult {
        let name = source.lastPathComponent
        let taken: (String) -> Bool = { pathExists(self.destination.appendingPathComponent($0)) }
        var target = destination.appendingPathComponent(name)

        if isSameDirectory(source.deletingLastPathComponent(), destination) {
            // Replace would delete the source itself, so a copy into its own folder is always a duplicate.
            target = destination.appendingPathComponent(UniqueName.duplicate(name, exists: taken))
        } else if pathExists(target) {
            switch await conflictDecision(source: source, existing: target) {
            case .skip:
                account(skipped: source)
                return .skipped
            case .keepBoth:
                target = destination.appendingPathComponent(UniqueName.keepBoth(name, exists: taken))
            case .replace:
                if isSameOrInside(source, target) {
                    let decision = await delegate.decide(OperationFailure(url: target, reason: .targetContainsSource))
                    return decision == .cancelAll ? .cancelAll : .skipped
                }
                let removal = await attempt(target, delegate: delegate, cancel: cancel) {
                    try FileManager.default.removeItem(at: target)
                }
                if removal != .done { return removal }
            }
        }
        return await copyTree(source, to: target)
    }

    private func conflictDecision(source: URL, existing: URL) async -> ConflictDecision {
        if let decision = conflictDecisionForAll { return decision }
        let resolution = await delegate.resolve(Conflict(source: source, existing: existing))
        if resolution.applyToAll { conflictDecisionForAll = resolution.decision }
        return resolution.decision
    }

    private func copyTree(_ source: URL, to target: URL) async -> StepResult {
        if cancel.isSet { return .cancelAll }
        var info = stat()
        guard lstat(source.path, &info) == 0 else {
            return await attempt(source, delegate: delegate, cancel: cancel) {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .ENOENT)
            }
        }

        if (info.st_mode & S_IFMT) == S_IFDIR {
            let created = await attempt(source, delegate: delegate, cancel: cancel) {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            }
            if created != .done { return created }
            var children: [String] = []
            let listed = await attempt(source, delegate: delegate, cancel: cancel) {
                children = try FileManager.default.contentsOfDirectory(atPath: source.path)
            }
            if listed != .done { return listed }

            var result = StepResult.done
            for child in children.sorted() {
                switch await copyTree(source.appendingPathComponent(child), to: target.appendingPathComponent(child)) {
                case .done: break
                case .skipped: result = .skipped
                case .cancelAll: return .cancelAll
                }
            }
            // Applied after the children: writing them would reset the mtime, and a read-only
            // folder would block them. Best effort; a volume without ACLs or xattrs still keeps the files.
            copyfile(source.path, target.path, nil, copyfile_flags_t(COPYFILE_METADATA | COPYFILE_NOFOLLOW))
            return result
        }

        let size = (info.st_mode & S_IFMT) == S_IFREG ? Int64(info.st_size) : 0
        progress.currentName = source.lastPathComponent
        let base = progress
        let copiedFile = await attempt(source, delegate: delegate, cancel: cancel) {
            try copyFile(source, to: target, base: base)
        }
        if copiedFile == .done {
            progress.completedFiles += 1
            progress.completedBytes = base.completedBytes + size
            delegate.progress(progress)
        }
        return copiedFile
    }

    private func copyFile(_ source: URL, to target: URL, base: OperationProgress) throws {
        let context = Unmanaged.passRetained(CopyCallbackContext(base: base, delegate: delegate, cancel: cancel))
        defer { context.release() }
        let state = copyfile_state_alloc()
        defer { copyfile_state_free(state) }

        let callback: copyfile_callback_t = { what, stage, state, _, _, info in
            guard let info else { return COPYFILE_CONTINUE }
            let context = Unmanaged<CopyCallbackContext>.fromOpaque(info).takeUnretainedValue()
            if what == COPYFILE_COPY_DATA, stage == COPYFILE_PROGRESS {
                var copied: off_t = 0
                copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied)
                context.report(copiedBytes: Int64(copied))
            }
            return context.cancel.isSet ? COPYFILE_QUIT : COPYFILE_CONTINUE
        }
        copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CB), unsafeBitCast(callback, to: UnsafeRawPointer.self))
        copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CTX), context.toOpaque())

        // NOFOLLOW copies a symlink as a link (no loops); EXCL never overwrites what conflict handling kept.
        let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_NOFOLLOW | COPYFILE_EXCL)
        guard copyfile(source.path, target.path, state, flags) != 0 else { return }

        let code = errno
        if code != EEXIST { try? FileManager.default.removeItem(at: target) }
        if cancel.isSet { throw CancellationError() }
        throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }

    private func account(skipped source: URL) {
        let (files, bytes) = Self.totals(source.path)
        progress.completedFiles += files
        progress.completedBytes += bytes
        delegate.progress(progress)
    }

    /// Files and bytes under `path`, without following symlinks.
    static func totals(_ path: String) -> (files: Int, bytes: Int64) {
        var info = stat()
        guard lstat(path, &info) == 0 else { return (0, 0) }
        guard (info.st_mode & S_IFMT) == S_IFDIR else {
            return (1, (info.st_mode & S_IFMT) == S_IFREG ? Int64(info.st_size) : 0)
        }
        let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return children.reduce((0, 0)) { sum, child in
            let sub = totals((path as NSString).appendingPathComponent(child))
            return (sum.0 + sub.files, sum.1 + sub.bytes)
        }
    }
}

private final class CopyCallbackContext {
    let base: OperationProgress
    let delegate: any OperationDelegate
    let cancel: CancelFlag

    init(base: OperationProgress, delegate: any OperationDelegate, cancel: CancelFlag) {
        self.base = base
        self.delegate = delegate
        self.cancel = cancel
    }

    func report(copiedBytes: Int64) {
        var progress = base
        progress.completedBytes = base.completedBytes + copiedBytes
        delegate.progress(progress)
    }
}
