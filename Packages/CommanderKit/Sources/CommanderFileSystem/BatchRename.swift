import Darwin
import Foundation

public struct RenamePair: Equatable, Sendable {
    public let from: URL
    public let to: URL

    public init(from: URL, to: URL) {
        self.from = from
        self.to = to
    }
}

public struct BatchRenameError: Error, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum BatchRename {
    /// Every item first moves to a temporary name, then to its final one, so swaps (a→b, b→a) work. If any step
    /// fails, the items already moved go back to their original names before the error is thrown.
    public static func run(_ pairs: [RenamePair]) throws(BatchRenameError) {
        let moves = pairs.filter { $0.from.standardizedFileURL.path != $0.to.standardizedFileURL.path }
        guard !moves.isEmpty else { return }
        for move in moves where exists(move.to) {
            // A target may be one of the batch's own sources (it moves away first), or the same file under
            // another letter case; anything else would be overwritten.
            guard moves.contains(where: { sameFile($0.from, move.to) }) else {
                throw BatchRenameError(message: "“\(move.to.lastPathComponent)” already exists.")
            }
        }

        let token = UUID().uuidString
        // (where the item is now, where it came from)
        var moved: [(current: URL, original: URL)] = []
        // Also in two steps: in a half-done swap an original name may still be taken by another item.
        func rollBack() {
            let parked = moved.enumerated().map { index, entry in
                let temp = entry.current.deletingLastPathComponent().appendingPathComponent(".commander-undo-\(token)-\(index)")
                return renameExclusive(entry.current, temp) ? temp : entry.current
            }
            for (index, entry) in moved.enumerated() { _ = renameExclusive(parked[index], entry.original) }
        }

        var temporary: [URL] = []
        for (index, move) in moves.enumerated() {
            let temp = move.from.deletingLastPathComponent().appendingPathComponent(".commander-rename-\(token)-\(index)")
            guard renameExclusive(move.from, temp) else {
                let reason = String(cString: strerror(errno))
                rollBack()
                throw BatchRenameError(message: "Couldn't rename “\(move.from.lastPathComponent)”: \(reason)")
            }
            moved.append((temp, move.from))
            temporary.append(temp)
        }
        for (index, move) in moves.enumerated() {
            guard renameExclusive(temporary[index], move.to) else {
                let reason = String(cString: strerror(errno))
                rollBack()
                throw BatchRenameError(message: "Couldn't rename “\(move.from.lastPathComponent)”: \(reason)")
            }
            moved[index].current = move.to
        }
    }

    /// Never replaces an existing item, so a failed or racing step can't destroy a file.
    private static func renameExclusive(_ from: URL, _ to: URL) -> Bool {
        renamex_np(from.path, to.path, UInt32(RENAME_EXCL)) == 0
    }

    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    private static func sameFile(_ a: URL, _ b: URL) -> Bool {
        var first = stat()
        var second = stat()
        guard lstat(a.path, &first) == 0, lstat(b.path, &second) == 0 else { return false }
        return first.st_dev == second.st_dev && first.st_ino == second.st_ino
    }
}
