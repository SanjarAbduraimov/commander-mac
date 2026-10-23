import CommanderFileSystem
import Foundation

@MainActor
public final class SidebarModel {
    public private(set) var favorites: [URL]
    public private(set) var volumes: [VolumeInfo] = []
    public var onChange: (() -> Void)?

    private let listVolumes: @Sendable () -> [VolumeInfo]
    private let executor: OperationExecutor

    public init(favorites: [URL], volumes: @escaping @Sendable () -> [VolumeInfo], executor: OperationExecutor) {
        self.favorites = favorites
        listVolumes = volumes
        self.executor = executor
    }

    /// Off the main thread: asking a dead SMB mount for its capacity can block for a long time.
    public func refreshVolumes() async {
        let listVolumes = listVolumes
        guard let fresh = try? await executor.run({ listVolumes() }) else { return }
        volumes = fresh
        onChange?()
    }

    @discardableResult
    public func addFavorite(_ url: URL, at index: Int? = nil) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
        let path = url.standardizedFileURL.path
        guard !favorites.contains(where: { $0.standardizedFileURL.path == path }) else { return false }
        favorites.insert(url.standardizedFileURL, at: min(max(index ?? favorites.count, 0), favorites.count))
        onChange?()
        return true
    }

    public func removeFavorite(at index: Int) {
        guard favorites.indices.contains(index) else { return }
        favorites.remove(at: index)
        onChange?()
    }

    public static func capacityText(_ volume: VolumeInfo) -> String? {
        guard let available = volume.availableCapacity, let total = volume.totalCapacity else { return nil }
        return "\(byteText(available)) available of \(byteText(total))"
    }
}
