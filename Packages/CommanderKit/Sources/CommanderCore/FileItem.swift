import Foundation

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

    public init(name: String, url: URL, kind: Kind, size: Int64?, modified: Date, isHidden: Bool) {
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.modified = modified
        self.isHidden = isHidden
    }

    public var isNavigable: Bool {
        switch kind {
        case .directory, .symlink(toDirectory: true): true
        default: false
        }
    }
}

public enum SortColumn: String, Codable, Sendable {
    case name, size, modified
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
            // Folders have no size; they stay in name order among themselves.
            guard let sa = a.size, let sb = b.size else { return .orderedSame }
            return sa == sb ? .orderedSame : (sa < sb ? .orderedAscending : .orderedDescending)
        case .modified:
            return a.modified == b.modified ? .orderedSame : (a.modified < b.modified ? .orderedAscending : .orderedDescending)
        }
    }
}
