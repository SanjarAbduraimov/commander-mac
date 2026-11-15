import Foundation

public struct TabState: Sendable {
    public private(set) var path: URL
    public private(set) var backHistory: [URL] = []
    public private(set) var forwardHistory: [URL] = []
    public var canGoBack: Bool { !backHistory.isEmpty }
    public var canGoForward: Bool { !forwardHistory.isEmpty }
    public private(set) var items: [FileItem] = []
    public internal(set) var cursor: String?
    public internal(set) var marked: Set<String> = []
    public private(set) var sort: FileSort
    public private(set) var showHidden: Bool

    private var allItems: [FileItem] = []
    private var pendingCursor: String?

    public init(path: URL, sort: FileSort = .init(), showHidden: Bool = false) {
        self.path = path
        self.sort = sort
        self.showHidden = showHidden
    }

    public mutating func navigate(to url: URL) {
        guard url.standardizedFileURL.path != path.standardizedFileURL.path else { return }
        backHistory.append(path)
        forwardHistory.removeAll()
        reset(to: url)
    }

    @discardableResult
    public mutating func goUp() -> Bool {
        guard path.standardizedFileURL.path != "/" else { return false }
        let leftFolder = path.lastPathComponent
        navigate(to: path.deletingLastPathComponent())
        pendingCursor = leftFolder
        return true
    }

    @discardableResult
    public mutating func goBack() -> Bool {
        guard let previous = backHistory.popLast() else { return false }
        forwardHistory.append(path)
        reset(to: previous)
        return true
    }

    @discardableResult
    public mutating func goForward() -> Bool {
        guard let next = forwardHistory.popLast() else { return false }
        backHistory.append(path)
        reset(to: next)
        return true
    }

    public mutating func apply(listing: [FileItem]) {
        allItems = listing
        rebuild()
    }

    public mutating func setSort(_ sort: FileSort) {
        self.sort = sort
        rebuild()
    }

    public mutating func setShowHidden(_ show: Bool) {
        showHidden = show
        rebuild()
    }

    public var cursorIndex: Int? {
        guard let cursor else { return nil }
        return items.firstIndex { $0.name == cursor }
    }

    public var cursorItem: FileItem? {
        cursorIndex.map { items[$0] }
    }

    public var targets: [FileItem] {
        if !marked.isEmpty { return items.filter { marked.contains($0.name) } }
        return cursorItem.map { [$0] } ?? []
    }

    private mutating func reset(to url: URL) {
        path = url
        allItems = []
        items = []
        cursor = nil
        marked = []
        pendingCursor = nil
    }

    private mutating func rebuild() {
        let previousIndex = cursorIndex
        let visible = showHidden ? allItems : allItems.filter { !$0.isHidden }
        items = sort.sorted(visible)
        let names = Set(items.map(\.name))

        if let pending = pendingCursor, names.contains(pending) {
            cursor = pending
        } else if let current = cursor, names.contains(current) {
            cursor = current
        } else if let previousIndex, !items.isEmpty {
            cursor = items[min(previousIndex, items.count - 1)].name
        } else {
            cursor = items.first?.name
        }
        pendingCursor = nil
        marked.formIntersection(names)
    }
}
