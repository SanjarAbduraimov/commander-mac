extension TabState {
    public mutating func moveCursor(by delta: Int) {
        guard let index = cursorIndex else { return }
        cursor = items[clamped(index + delta)].name
    }

    public mutating func moveCursorToStart() {
        if let first = items.first { cursor = first.name }
    }

    public mutating func moveCursorToEnd() {
        if let last = items.last { cursor = last.name }
    }

    public mutating func setCursor(name: String) {
        if items.contains(where: { $0.name == name }) { cursor = name }
    }

    public mutating func toggleMark(advance: Bool) {
        guard let index = cursorIndex else { return }
        toggle(items[index].name)
        if advance { moveCursor(by: 1) }
    }

    public mutating func moveCursorMarking(by delta: Int) {
        guard let index = cursorIndex else { return }
        let target = clamped(index + delta)
        mark(from: index, to: target)
        cursor = items[target].name
    }

    public mutating func markRange(toName name: String) {
        guard let index = cursorIndex, let target = items.firstIndex(where: { $0.name == name }) else { return }
        mark(from: index, to: target)
        cursor = name
    }

    public mutating func toggleMark(name: String) {
        if items.contains(where: { $0.name == name }) { toggle(name) }
    }

    public mutating func markAll() {
        marked = Set(items.map(\.name))
    }

    public mutating func clearMarks() {
        marked = []
    }

    private func clamped(_ index: Int) -> Int {
        min(max(index, 0), items.count - 1)
    }

    private mutating func toggle(_ name: String) {
        if marked.remove(name) == nil { marked.insert(name) }
    }

    private mutating func mark(from start: Int, to end: Int) {
        for i in min(start, end)...max(start, end) { marked.insert(items[i].name) }
    }
}
