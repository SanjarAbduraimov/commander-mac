import AppKit
import CommanderCore
import UniformTypeIdentifiers

/// Looking an icon up per file is slow on big folders; folders share one icon and files share one per extension.
@MainActor
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()
    private lazy var folderIcon = NSWorkspace.shared.icon(for: .folder)

    func icon(for item: FileItem) -> NSImage {
        switch item.kind {
        case .directory:
            return folderIcon
        case .package, .symlink:
            return cached("path:" + item.url.path) { NSWorkspace.shared.icon(forFile: item.url.path) }
        case .file:
            let ext = item.url.pathExtension.lowercased()
            return cached("ext:" + ext) {
                NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
            }
        }
    }

    private func cached(_ key: String, _ make: () -> NSImage) -> NSImage {
        if let image = cache.object(forKey: key as NSString) { return image }
        let image = make()
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}
