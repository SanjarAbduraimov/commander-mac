import Testing
@testable import CommanderCore

private func pane(_ paths: String..., active: Int = 0) -> PaneState {
    PaneState(tabs: paths.map { TabState(path: url($0)) }, activeTabIndex: active)
}

private func paths(_ pane: PaneState) -> [String] { pane.tabs.map(\.path.path) }

struct PaneStateTests {
    @Test func newTabOpensCurrentPathAfterActive() {
        var state = pane("/a", "/b")
        state.newTab()
        #expect(paths(state) == ["/a", "/a", "/b"])
        #expect(state.activeTabIndex == 1)
    }

    @Test func newTabStartsWithoutMarks() {
        var state = PaneState(tabs: [tab(at: "/a", items: "x", "y")])
        state.activeTab.markAll()
        state.newTab()
        #expect(state.activeTab.marked.isEmpty)
        #expect(state.tabs[0].marked == ["x", "y"])
    }

    @Test func cannotCloseLastTab() {
        var state = pane("/a")
        let closed = state.closeActiveTab()
        #expect(closed == false)
        #expect(state.tabs.count == 1)
    }

    @Test func closeActivatesNeighbor() {
        var last = pane("/a", "/b", "/c", active: 2)
        let closedLast = last.closeActiveTab()
        #expect(closedLast)
        #expect(paths(last) == ["/a", "/b"])
        #expect(last.activeTabIndex == 1)

        var first = pane("/a", "/b", "/c", active: 0)
        let closedFirst = first.closeActiveTab()
        #expect(closedFirst)
        #expect(paths(first) == ["/b", "/c"])
        #expect(first.activeTabIndex == 0)
    }

    @Test func nextAndPreviousWrapAround() {
        var state = pane("/a", "/b", "/c", active: 2)
        state.selectNextTab()
        #expect(state.activeTabIndex == 0)
        state.selectPreviousTab()
        #expect(state.activeTabIndex == 2)
        state.selectTab(at: 1)
        #expect(state.activeTabIndex == 1)
        state.selectTab(at: 9)
        #expect(state.activeTabIndex == 1)
    }

    @Test func switchActiveSideSwapsActiveAndOther() {
        var window = WindowState(left: pane("/left"), right: pane("/right"))
        #expect(window.activePane.activeTab.path.path == "/left")
        #expect(window.otherPane.activeTab.path.path == "/right")
        window.switchActiveSide()
        #expect(window.activeSide == .right)
        #expect(window.activePane.activeTab.path.path == "/right")
        #expect(window.otherPane.activeTab.path.path == "/left")
    }
}
