import CommanderCore
import CommanderFileSystem
import Darwin
import Foundation

public struct MultiRenameRequest: Equatable, Sendable {
    public let side: PaneSide
    public let folder: URL
    public let items: [FileItem]
    /// Every name in the folder, hidden ones too: the pane may not show what a new name would collide with.
    public let existing: Set<String>
}

extension WindowModel {
    public var canUndoMultiRename: Bool { multiRenameUndo != nil }

    func startMultiRename(_ side: PaneSide) {
        let tab = tab(side)
        guard !tab.targets.isEmpty else {
            effects.beep()
            return
        }
        let folder = tab.path
        let items = tab.targets
        let executor = environment.listingExecutor
        track {
            let names = (try? await executor.run { try FileManager.default.contentsOfDirectory(atPath: folder.path) }) ?? []
            self.effects.showMultiRename(MultiRenameRequest(side: side, folder: folder, items: items, existing: Set(names)))
        }
    }

    /// nil on success, otherwise a message for the dialog.
    public func applyMultiRename(_ rows: [MultiRenameRow], in request: MultiRenameRequest) async -> String? {
        guard rows.allSatisfy({ $0.problem == nil }) else { return "Some new names have problems." }
        let changed = rows.filter(\.isChanged)
        guard !changed.isEmpty else { return nil }
        let pairs = changed.map { RenamePair(from: $0.item.url, to: request.folder.appendingPathComponent($0.newName)) }
        do {
            try await environment.listingExecutor.run { () throws -> Void in try BatchRename.run(pairs) }
        } catch let error as BatchRenameError {
            return error.message
        } catch {
            return error.localizedDescription
        }
        multiRenameUndo = pairs.map { RenamePair(from: $0.to, to: $0.from) }
        let side = request.side
        if samePath(tab(side).path, request.folder) {
            mutateTab(side) { $0.clearMarks() }
            pendingCursor[side] = changed[0].newName
        }
        await reloadShowing(request.folder)
        return nil
    }

    /// Items renamed again or deleted since are skipped; the message counts them.
    public func undoMultiRename() async -> String? {
        guard let pairs = multiRenameUndo else { return nil }
        multiRenameUndo = nil
        // lstat, not fileExists: the latter follows symlinks, so a dangling one would look missing both as a
        // source to restore and as an occupier blocking a restore.
        let possible = pairs.filter { Self.isPresent($0.from) && !Self.isPresent($0.to) }
        var failed = pairs.count - possible.count
        if !possible.isEmpty {
            do {
                try await environment.listingExecutor.run { () throws -> Void in try BatchRename.run(possible) }
            } catch {
                failed = pairs.count
            }
        }
        if let folder = pairs.first?.to.deletingLastPathComponent() { await reloadShowing(folder) }
        guard failed > 0 else { return nil }
        return failed == 1 ? "1 item could not be restored." : "\(failed) items could not be restored."
    }

    private static func isPresent(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    private func reloadShowing(_ folder: URL) async {
        for side in [PaneSide.left, .right] where samePath(tab(side).path, folder) {
            await reloadAndWait(side)
        }
    }
}
