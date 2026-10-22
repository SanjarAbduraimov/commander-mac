import CommanderCore
import Darwin
import Foundation

public enum RenameError: Error, Equatable, Sendable {
    case empty, invalidCharacter, alreadyExists
    case failed(String)
}

public enum FileActions {
    public static func createFolder(in directory: URL) throws -> URL {
        let name = UniqueName.newFolder { pathExists(directory.appendingPathComponent($0)) }
        let folder = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }

    public static func rename(_ url: URL, to newName: String) throws(RenameError) -> URL {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw .empty }
        guard !name.contains("/"), !name.contains(":") else { throw .invalidCharacter }
        guard name != url.lastPathComponent else { return url }

        let target = url.deletingLastPathComponent().appendingPathComponent(name)
        // On a case-insensitive volume "A.txt" already "exists" as the file itself; only a different file is a clash.
        if pathExists(target), !isSameFile(url, target) { throw .alreadyExists }
        // rename(2) rather than FileManager: it handles case-only renames in place.
        guard Darwin.rename(url.path, target.path) == 0 else {
            throw .failed(String(cString: strerror(errno)))
        }
        return target
    }

    private static func isSameFile(_ a: URL, _ b: URL) -> Bool {
        var first = stat()
        var second = stat()
        guard lstat(a.path, &first) == 0, lstat(b.path, &second) == 0 else { return false }
        return first.st_dev == second.st_dev && first.st_ino == second.st_ino
    }
}
