import Foundation
import Synchronization
import UniformTypeIdentifiers

public struct FileItem: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case file, directory, package
        case symlink(toDirectory: Bool)
    }

    public let name: String
    public let url: URL
    public let kind: Kind
    public let size: Int64?
    public let modified: Date
    public let isHidden: Bool
    public let created: Date?

    public init(
        name: String, url: URL, kind: Kind, size: Int64?, modified: Date, isHidden: Bool,
        created: Date? = nil
    ) {
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.modified = modified
        self.isHidden = isHidden
        self.created = created
    }

    /// The system's description of the type ("PDF document", "Folder"). Looked up on demand and cached per
    /// extension: only the Kind column and Kind sorting need it, so listing a folder doesn't pay for it.
    public var kindName: String {
        switch kind {
        case .directory, .symlink(toDirectory: true): return "Folder"
        case .symlink(toDirectory: false): return "Alias"
        case .file, .package: break
        }
        let ext = ext.lowercased()
        guard !ext.isEmpty else { return "Document" }
        return Self.kindNames.withLock { cache in
            if let cached = cache[ext] { return cached }
            let description = UTType(filenameExtension: ext)?.localizedDescription ?? "\(ext.uppercased()) file"
            cache[ext] = description
            return description
        }
    }

    private static let kindNames = Mutex<[String: String]>([:])

    /// Folders have none; a leading dot (".env") or a trailing one ("file.") is part of the name, not an extension.
    public var ext: String { Self.ext(of: name, kind: kind) }

    public static func ext(of name: String, kind: Kind) -> String {
        if kind == .directory || kind == .symlink(toDirectory: true) { return "" }
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty, name.count > ext.count + 1 else { return "" }
        return ext
    }

    public var baseName: String {
        let ext = ext
        return ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
    }

    public var isNavigable: Bool {
        switch kind {
        case .directory, .symlink(toDirectory: true): true
        default: false
        }
    }
}

public enum SortColumn: String, Codable, Sendable {
    case name, size, modified, ext, created, kind
}

public struct FileSort: Codable, Hashable, Sendable {
    public var column: SortColumn
    public var ascending: Bool

    public init(column: SortColumn = .name, ascending: Bool = true) {
        self.column = column
        self.ascending = ascending
    }

    public func sorted(_ items: [FileItem]) -> [FileItem] {
        items.sorted { a, b in
            if a.isNavigable != b.isNavigable { return a.isNavigable }
            let order = compare(a, b)
            if order != .orderedSame { return ascending ? order == .orderedAscending : order == .orderedDescending }
            // Name tie-break keeps the order stable regardless of direction.
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    private func compare(_ a: FileItem, _ b: FileItem) -> ComparisonResult {
        switch column {
        case .name:
            return a.name.localizedStandardCompare(b.name)
        case .size:
            // No size (folders, packages) ranks below every real size; returning "same" for nil
            // made the order non-transitive once packages sit among files.
            let sa = a.size ?? -1
            let sb = b.size ?? -1
            return sa == sb ? .orderedSame : (sa < sb ? .orderedAscending : .orderedDescending)
        case .modified:
            return a.modified == b.modified ? .orderedSame : (a.modified < b.modified ? .orderedAscending : .orderedDescending)
        case .ext:
            return a.ext.caseInsensitiveCompare(b.ext)
        case .created:
            let ca = a.created ?? .distantPast
            let cb = b.created ?? .distantPast
            return ca == cb ? .orderedSame : (ca < cb ? .orderedAscending : .orderedDescending)
        case .kind:
            return a.kindName.localizedStandardCompare(b.kindName)
        }
    }
}
