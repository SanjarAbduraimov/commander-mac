import Foundation

public enum FolderSize {
    /// Files and bytes under `url`. Symlinks are counted as items but never followed; nil once `isCancelled` says so.
    public static func measure(_ url: URL, isCancelled: () -> Bool) -> (files: Int, bytes: Int64)? {
        measure(path: url.path, isCancelled: isCancelled)
    }

    static func measure(path: String, isCancelled: () -> Bool) -> (files: Int, bytes: Int64)? {
        if isCancelled() { return nil }
        var info = stat()
        guard lstat(path, &info) == 0 else { return (0, 0) }
        guard (info.st_mode & S_IFMT) == S_IFDIR else {
            return (1, (info.st_mode & S_IFMT) == S_IFREG ? Int64(info.st_size) : 0)
        }
        var total = (files: 0, bytes: Int64(0))
        for child in (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? [] {
            guard let sub = measure(path: (path as NSString).appendingPathComponent(child), isCancelled: isCancelled) else { return nil }
            total.files += sub.files
            total.bytes += sub.bytes
        }
        return total
    }
}
