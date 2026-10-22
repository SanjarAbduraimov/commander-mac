import CommanderCore
import Foundation

public enum ListingError: Error, Equatable, Sendable {
    case notFound, notADirectory, permissionDenied
    case other(String)
}

public struct DirectoryReader: Sendable {
    // isPackageKey is left out of the prefetch: it costs a LaunchServices lookup per item,
    // so it is asked only for directories that have an extension.
    private static let keys: [URLResourceKey] = [
        .nameKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
    ]
    private static let keySet = Set(keys)

    public init() {}

    public func list(_ directory: URL) throws(ListingError) -> [FileItem] {
        // fileExists follows symlinks; URL resource values would describe the link itself.
        guard let isDirectory = Self.followedIsDirectory(directory) else { throw .notFound }
        guard isDirectory else { throw .notADirectory }

        // contentsOfDirectory(at:) does not follow a symlinked directory, so list its target
        // while keeping item URLs under the path the user navigated to.
        let resolved = directory.resolvingSymlinksInPath()
        let isLink = resolved.path != directory.standardizedFileURL.path
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(at: resolved, includingPropertiesForKeys: Self.keys, options: [])
        } catch {
            throw Self.listingError(from: error)
        }
        return urls.compactMap { url in
            Self.item(at: url, shownAt: isLink ? directory.appendingPathComponent(url.lastPathComponent) : url)
        }
    }

    public func nearestExistingDirectory(from url: URL) -> URL {
        var candidate = url.standardizedFileURL
        while candidate.path != "/" {
            if Self.followedIsDirectory(candidate) == true { return candidate }
            candidate = candidate.deletingLastPathComponent()
        }
        return candidate
    }

    /// nil when nothing exists at the path (or a symlink is broken).
    private static func followedIsDirectory(_ url: URL) -> Bool? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue
    }

    private static func item(at url: URL, shownAt shownURL: URL) -> FileItem? {
        guard let values = try? url.resourceValues(forKeys: keySet) else { return nil }
        let kind: FileItem.Kind
        if values.isSymbolicLink == true {
            kind = .symlink(toDirectory: followedIsDirectory(url) ?? false)
        } else if values.isDirectory == true {
            let isPackage = !url.pathExtension.isEmpty && (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
            kind = isPackage ? .package : .directory
        } else {
            kind = .file
        }
        let hasSize = kind == .file || kind == .symlink(toDirectory: false)
        return FileItem(
            name: values.name ?? url.lastPathComponent,
            url: shownURL,
            kind: kind,
            size: hasSize ? Int64(values.fileSize ?? 0) : nil,
            modified: values.contentModificationDate ?? .distantPast,
            isHidden: values.isHidden ?? url.lastPathComponent.hasPrefix(".")
        )
    }

    private static func listingError(from error: Error) -> ListingError {
        let nsError = error as NSError
        let posix = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError).flatMap { $0.domain == NSPOSIXErrorDomain ? $0.code : nil }
        switch (nsError.domain, nsError.code) {
        case (NSCocoaErrorDomain, NSFileReadNoSuchFileError), (NSCocoaErrorDomain, NSFileNoSuchFileError):
            return .notFound
        case (NSCocoaErrorDomain, NSFileReadNoPermissionError):
            return .permissionDenied
        default:
            if posix == Int(EACCES) || posix == Int(EPERM) { return .permissionDenied }
            if posix == Int(ENOENT) { return .notFound }
            if posix == Int(ENOTDIR) { return .notADirectory }
            return .other(nsError.localizedDescription)
        }
    }
}
