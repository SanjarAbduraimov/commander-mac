public struct PaneState: Sendable {
    public private(set) var tabs: [TabState]
    public private(set) var activeTabIndex: Int

    public init(tabs: [TabState], activeTabIndex: Int = 0) {
        precondition(!tabs.isEmpty, "A pane always has at least one tab")
        self.tabs = tabs
        self.activeTabIndex = min(max(activeTabIndex, 0), tabs.count - 1)
    }

    public var activeTab: TabState {
        get { tabs[activeTabIndex] }
        set { tabs[activeTabIndex] = newValue }
    }

    public mutating func newTab() {
        let current = activeTab
        tabs.insert(TabState(path: current.path, sort: current.sort, showHidden: current.showHidden), at: activeTabIndex + 1)
        activeTabIndex += 1
    }

    @discardableResult
    public mutating func closeActiveTab() -> Bool {
        guard tabs.count > 1 else { return false }
        tabs.remove(at: activeTabIndex)
        activeTabIndex = min(activeTabIndex, tabs.count - 1)
        return true
    }

    public mutating func selectNextTab() {
        activeTabIndex = (activeTabIndex + 1) % tabs.count
    }

    public mutating func selectPreviousTab() {
        activeTabIndex = (activeTabIndex - 1 + tabs.count) % tabs.count
    }

    public mutating func selectTab(at index: Int) {
        if tabs.indices.contains(index) { activeTabIndex = index }
    }
}

public enum PaneSide: String, Codable, Sendable {
    case left, right
}

public struct WindowState: Sendable {
    public var left: PaneState
    public var right: PaneState
    public var activeSide: PaneSide

    public init(left: PaneState, right: PaneState, activeSide: PaneSide = .left) {
        self.left = left
        self.right = right
        self.activeSide = activeSide
    }

    public var activePane: PaneState {
        get { activeSide == .left ? left : right }
        set { if activeSide == .left { left = newValue } else { right = newValue } }
    }

    public var otherPane: PaneState {
        get { activeSide == .left ? right : left }
        set { if activeSide == .left { right = newValue } else { left = newValue } }
    }

    public mutating func switchActiveSide() {
        activeSide = activeSide == .left ? .right : .left
    }
}
