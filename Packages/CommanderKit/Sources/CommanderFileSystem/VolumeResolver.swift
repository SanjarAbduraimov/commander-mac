import Foundation

public struct VolumeResolver: Sendable {
    public init() {}

    public func volumeIdentifier(for url: URL) -> String? {
        var current = url.standardizedFileURL
        let fileManager = FileManager.default

        // If URL doesn't exist yet, walk up to the nearest existing ancestor.
        while !fileManager.fileExists(atPath: current.path) && current.path != "/" {
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        if let values = try? current.resourceValues(forKeys: [.volumeIdentifierKey]) {
            if let volId = values.volumeIdentifier as? String {
                return volId
            }
            if let volId = values.volumeIdentifier {
                return String(describing: volId)
            }
        }

        var stat = statfs()
        if statfs(current.path, &stat) == 0 {
            return "\(stat.f_fsid.val.0)_\(stat.f_fsid.val.1)"
        }

        return nil
    }

    public func isSameVolume(_ url1: URL, _ url2: URL) -> Bool {
        guard let id1 = volumeIdentifier(for: url1),
              let id2 = volumeIdentifier(for: url2) else {
            return true
        }
        return id1 == id2
    }
}
