import CommanderCore
import Foundation

public struct MoveOperation: Sendable {
    let sources: [URL]
    let destination: URL
    let delegate: any OperationDelegate

    public init(sources: [URL], destination: URL, delegate: any OperationDelegate) {
        self.sources = sources
        self.destination = destination
        self.delegate = delegate
    }

    public func run() async -> OperationOutcome {
        let cancel = CancelFlag()
        return await withTaskCancellationHandler {
            await perform(cancel: cancel)
        } onCancel: {
            cancel.set()
        }
    }

    private func perform(cancel: CancelFlag) async -> OperationOutcome {
        let destinationVolume = Self.volume(of: destination)
        var renames: [URL] = []
        var copies: [URL] = []
        for source in sources {
            if isSameDirectory(source.deletingLastPathComponent(), destination) { continue }
            if isSameOrInside(destination, source) {
                let decision = await delegate.decide(OperationFailure(url: source, reason: .destinationInsideSource))
                if decision == .cancelAll { return .cancelled }
                continue
            }
            if let volume = Self.volume(of: source), let destinationVolume, volume.isEqual(destinationVolume) {
                renames.append(source)
            } else {
                copies.append(source)
            }
        }

        if await moveWithinVolume(renames, cancel: cancel) == .cancelAll { return .cancelled }
        guard !copies.isEmpty else { return cancel.isSet ? .cancelled : .completed }

        let (outcome, copied) = await CopyOperation(sources: copies, destination: destination, delegate: delegate).runReportingCopied()
        // Only fully copied sources are removed; skipped, failed or cancelled ones stay where they were.
        for source in copied {
            let removal = await attempt(source, delegate: delegate, cancel: CancelFlag()) {
                try FileManager.default.removeItem(at: source)
            }
            if removal == .cancelAll { return .cancelled }
        }
        return outcome
    }

    private func moveWithinVolume(_ sources: [URL], cancel: CancelFlag) async -> StepResult {
        var progress = OperationProgress(totalFiles: sources.count)
        var decisionForAll: ConflictDecision?
        let taken: (String) -> Bool = { pathExists(destination.appendingPathComponent($0)) }

        for source in sources {
            if cancel.isSet { return .cancelAll }
            let name = source.lastPathComponent
            var target = destination.appendingPathComponent(name)
            var skip = false

            if pathExists(target) {
                let decision: ConflictDecision
                if let decisionForAll {
                    decision = decisionForAll
                } else {
                    let resolution = await delegate.resolve(Conflict(source: source, existing: target))
                    if resolution.applyToAll { decisionForAll = resolution.decision }
                    decision = resolution.decision
                }
                switch decision {
                case .skip:
                    skip = true
                case .keepBoth:
                    target = destination.appendingPathComponent(UniqueName.keepBoth(name, exists: taken))
                case .replace:
                    if isSameOrInside(source, target) {
                        let refusal = await delegate.decide(OperationFailure(url: target, reason: .targetContainsSource))
                        if refusal == .cancelAll { return .cancelAll }
                        skip = true
                        break
                    }
                    let removal = await attempt(target, delegate: delegate, cancel: cancel) {
                        try FileManager.default.removeItem(at: target)
                    }
                    if removal == .cancelAll { return .cancelAll }
                    skip = removal == .skipped
                }
            }

            if !skip {
                let moved = await attempt(source, delegate: delegate, cancel: cancel) {
                    try FileManager.default.moveItem(at: source, to: target)
                }
                if moved == .cancelAll { return .cancelAll }
            }
            progress.completedFiles += 1
            progress.currentName = name
            delegate.progress(progress)
        }
        return .done
    }

    private static func volume(of url: URL) -> NSObject? {
        (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
    }
}
