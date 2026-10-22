import Foundation
import Testing
@testable import CommanderCore

struct TabStateNavigationTests {
    @Test func navigateClearsMarksAndPushesHistory() {
        var state = tab(at: "/a", items: "x", "y")
        state.marked = ["x"]
        state.navigate(to: url("/b"))
        #expect(state.marked.isEmpty)
        #expect(state.backHistory.map(\.path) == ["/a"])
        #expect(state.forwardHistory.isEmpty)
        #expect(state.path.path == "/b")
    }

    @Test func navigateToSamePathIsNoOp() {
        var state = tab(at: "/a", items: "x")
        state.marked = ["x"]
        state.navigate(to: url("/a"))
        #expect(state.backHistory.isEmpty)
        #expect(state.marked == ["x"])
        #expect(state.items.count == 1)
    }

    @Test func goUpPlacesCursorOnFolderWeLeft() {
        var state = TabState(path: url("/a/b"))
        let movedUp = state.goUp()
        #expect(movedUp)
        #expect(state.path.path == "/a")
        state.apply(listing: [fixtureItem("a1", directory: true, in: "/a"), fixtureItem("b", directory: true, in: "/a"), fixtureItem("c", in: "/a")])
        #expect(state.cursor == "b")
    }

    @Test func goUpAtRootReturnsFalse() {
        var state = TabState(path: url("/"))
        let movedUp = state.goUp()
        #expect(movedUp == false)
        #expect(state.path.path == "/")
        #expect(state.backHistory.isEmpty)
    }

    @Test func backAndForward() {
        var state = TabState(path: url("/a"))
        state.navigate(to: url("/b"))
        let wentBack = state.goBack()
        #expect(wentBack)
        #expect(state.path.path == "/a")
        #expect(state.forwardHistory.map(\.path) == ["/b"])
        let wentForward = state.goForward()
        #expect(wentForward)
        #expect(state.path.path == "/b")
        #expect(state.backHistory.map(\.path) == ["/a"])
        let wentForwardAgain = state.goForward()
        #expect(wentForwardAgain == false)
    }

    @Test func reloadKeepsCursorAndMarksByName() {
        var state = tab(items: "a", "b", "c")
        state.cursor = "c"
        state.marked = ["a", "c"]
        state.apply(listing: fixtureItems("c", "b"))
        #expect(state.cursor == "c")
        #expect(state.marked == ["c"])
    }

    @Test func cursorFallsBackToSameIndexWhenItemRemoved() {
        var state = tab(items: "a", "b", "c")
        state.cursor = "b"
        state.apply(listing: fixtureItems("a", "c"))
        #expect(state.cursor == "c")

        var short = tab(items: "a", "b")
        short.cursor = "b"
        short.apply(listing: fixtureItems("a"))
        #expect(short.cursor == "a")
    }

    @Test func hiddenFilesFilteredUntilShown() {
        var state = tab(items: ".git", "src")
        #expect(state.items.map(\.name) == ["src"])
        state.setShowHidden(true)
        #expect(state.items.map(\.name) == [".git", "src"])
    }

    @Test func emptyListingHasNilCursorAndNoTargets() {
        var state = tab(items: "a")
        state.apply(listing: [])
        #expect(state.cursor == nil)
        #expect(state.cursorIndex == nil)
        #expect(state.cursorItem == nil)
        #expect(state.targets.isEmpty)
    }

    @Test func allHiddenListingBehavesAsEmpty() {
        let state = tab(items: ".a", ".b")
        #expect(state.items.isEmpty)
        #expect(state.cursor == nil)
        #expect(state.targets.isEmpty)
    }

    @Test func targetsPreferMarkedInDisplayOrder() {
        var state = tab(items: "a", "b", "c")
        state.marked = ["c", "a"]
        #expect(state.targets.map(\.name) == ["a", "c"])
        state.marked = []
        state.cursor = "b"
        #expect(state.targets.map(\.name) == ["b"])
    }
}
