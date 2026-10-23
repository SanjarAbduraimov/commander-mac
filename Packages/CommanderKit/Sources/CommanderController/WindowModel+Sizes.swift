import CommanderCore
import CommanderFileSystem
import Foundation
import Synchronization

public struct SizeProgress: Equatable, Sendable {
    public let done: Int
    public let total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }
}

public enum SizeText {
    public static func progress(_ p: SizeProgress) -> String {
        "Calculating size… \(p.done) of \(p.total) \(p.total == 1 ? "folder" : "folders")"
    }
}

final class SizeCancel: Sendable {
    private let flag = Mutex(false)
    func cancel() { flag.withLock { $0 = true } }
    var isCancelled: Bool { flag.withLock { $0 } }
}

struct SizeRun {
    let id = UUID()
    let side: PaneSide
    let cancel = SizeCancel()
    var progress: SizeProgress
}

extension WindowModel {
    public func folderSize(_ side: PaneSide, _ item: FileItem) -> Int64? {
        folderSizesBySide[side]?[item.url.standardizedFileURL.path]
    }

    public func folderSizes(_ side: PaneSide) -> [String: Int64] {
        folderSizesBySide[side] ?? [:]
    }

    public var sizeProgress: SizeProgress? { sizeRun?.progress }

    public func cancelSizeCalculation() {
        guard let run = sizeRun else { return }
        run.cancel.cancel()
        sizeRun = nil
        effects.stateDidChange(.operations)
    }

    func clearSizes(_ side: PaneSide) {
        if sizeRun?.side == side { cancelSizeCalculation() }
        folderSizesBySide[side] = nil
    }

    func calculateSizes(_ side: PaneSide) {
        let folders = tab(side).targets.filter { $0.kind == .directory || $0.kind == .package }
        guard !folders.isEmpty else {
            effects.beep()
            return
        }
        cancelSizeCalculation()
        let run = SizeRun(side: side, progress: SizeProgress(done: 0, total: folders.count))
        sizeRun = run
        effects.stateDidChange(.operations)
        let directory = tab(side).path
        let executor = environment.listingExecutor
        let cancel = run.cancel
        track {
            for folder in folders {
                let url = folder.url
                let measured = try? await executor.run { FolderSize.measure(url) { cancel.isCancelled } }
                guard !cancel.isCancelled, self.sizeRun?.id == run.id, samePath(self.tab(side).path, directory) else { return }
                if let measured = measured ?? nil {
                    self.folderSizesBySide[side, default: [:]][url.standardizedFileURL.path] = measured.bytes
                }
                let done = (self.sizeRun?.progress.done ?? 0) + 1
                self.sizeRun?.progress = SizeProgress(done: done, total: folders.count)
                self.effects.stateDidChange(.pane(side))
                self.effects.stateDidChange(.operations)
            }
            if self.sizeRun?.id == run.id {
                self.sizeRun = nil
                self.effects.stateDidChange(.operations)
            }
        }
    }
}
