import Foundation

public struct VolumeInfo: Equatable, Sendable {
    public let name: String
    public let url: URL
    public let totalCapacity: Int64?
    public let availableCapacity: Int64?
    public let isEjectable: Bool
    public let isNetwork: Bool
}

public enum Volumes {
    private static let keys: [URLResourceKey] = [
        .volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        .volumeIsEjectableKey, .volumeIsLocalKey,
    ]

    /// Visible volumes, startup disk first.
    public static func mounted() -> [VolumeInfo] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        let volumes = urls.map { url -> VolumeInfo in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return VolumeInfo(
                name: values?.volumeLocalizedName ?? url.lastPathComponent,
                url: url,
                totalCapacity: values?.volumeTotalCapacity.map(Int64.init),
                availableCapacity: values?.volumeAvailableCapacity.map(Int64.init),
                isEjectable: values?.volumeIsEjectable ?? false,
                isNetwork: !(values?.volumeIsLocal ?? true)
            )
        }
        return volumes.sorted { a, b in
            if (a.url.path == "/") != (b.url.path == "/") { return a.url.path == "/" }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    public static func eject(_ url: URL) async throws {
        try await FileManager.default.unmountVolume(at: url, options: [.allPartitionsAndEjectDisk])
    }
}

public enum SMBAddress {
    /// "server/share" and " smb://server/share " both become smb://server/share; other schemes are rejected.
    public static func normalize(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "smb://\(trimmed)"
        guard let components = URLComponents(string: withScheme),
              components.scheme?.lowercased() == "smb",
              let host = components.host, !host.isEmpty
        else { return nil }
        return components.url
    }
}
