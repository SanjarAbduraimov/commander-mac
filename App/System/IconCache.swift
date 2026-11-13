import AppKit
import CommanderCore
import UniformTypeIdentifiers

/// High-performance modern SF Symbols 6 icon provider with distinct colors for file types.
@MainActor
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()

    func icon(for item: FileItem, size: CGFloat = 16) -> NSImage {
        let ext = item.url.pathExtension.lowercased()
        let key = "k:\(String(describing: item.kind))_s:\(Int(size))_e:\(ext)_n:\(item.name.lowercased())"
        if let image = cache.object(forKey: key as NSString) { return image }

        let image = makeIcon(for: item, size: size)
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    private func makeIcon(for item: FileItem, size: CGFloat) -> NSImage {
        switch item.kind {
        case .directory:
            return sfIcon("folder.fill", tint: .systemBlue, size: size)
        case .package:
            if item.url.pathExtension.lowercased() == "app" {
                let img = NSWorkspace.shared.icon(forFile: item.url.path)
                img.size = NSSize(width: size, height: size)
                return img
            }
            return sfIcon("shippingbox.fill", tint: .systemOrange, size: size)
        case .symlink:
            return sfIcon("link", tint: .systemCyan, size: size)
        case .file:
            let ext = item.url.pathExtension.lowercased()
            return fileIcon(forExtension: ext, size: size)
        }
    }

    private func fileIcon(forExtension ext: String, size: CGFloat) -> NSImage {
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp", "tiff", "ico":
            return sfIcon("photo.fill", tint: .systemPurple, size: size)
        case "mp4", "mov", "mkv", "avi", "webm", "m4v":
            return sfIcon("film.fill", tint: .systemPink, size: size)
        case "mp3", "wav", "m4a", "flac", "aac", "ogg":
            return sfIcon("waveform", tint: .systemRed, size: size)
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "dmg", "pkg":
            return sfIcon("archivebox.fill", tint: .systemBrown, size: size)
        case "swift", "ts", "js", "jsx", "tsx", "py", "rs", "go", "c", "cpp", "h", "java", "kt", "rb", "php", "html", "css", "scss", "sql", "sh", "zsh":
            return sfIcon("curlybraces", tint: .systemOrange, size: size)
        case "json", "yaml", "yml", "xml", "plist", "toml":
            return sfIcon("doc.badge.gearshape.fill", tint: .systemTeal, size: size)
        case "pdf":
            return sfIcon("doc.richtext.fill", tint: .systemRed, size: size)
        case "md", "markdown", "txt", "rtf", "log":
            return sfIcon("doc.text.fill", tint: .systemCyan, size: size)
        case "xlsx", "xls", "csv", "numbers":
            return sfIcon("tablecells.fill", tint: .systemGreen, size: size)
        case "key", "ppt", "pptx":
            return sfIcon("presentation.fill", tint: .systemOrange, size: size)
        default:
            return sfIcon("doc.fill", tint: .secondaryLabelColor, size: size)
        }
    }

    private func sfIcon(_ name: String, tint: NSColor, size: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(hierarchicalColor: tint)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            let fallback = NSWorkspace.shared.icon(for: .data)
            fallback.size = NSSize(width: size, height: size)
            return fallback
        }
        base.size = NSSize(width: size, height: size)
        return base
    }
}
