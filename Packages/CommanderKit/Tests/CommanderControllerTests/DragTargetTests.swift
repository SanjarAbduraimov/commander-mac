import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct DragTargetTests {
    @Test func breadcrumbsSplitPath() {
        #expect(Breadcrumbs.of(URL(fileURLWithPath: "/")) == [Breadcrumb(title: "/", url: URL(fileURLWithPath: "/"))])
        let crumbs = Breadcrumbs.of(URL(fileURLWithPath: "/Users/s"))
        #expect(crumbs.map(\.title) == ["/", "Users", "s"])
        #expect(crumbs.map(\.url.path) == ["/", "/Users", "/Users/s"])
    }

    @Test func springLoadEntersFolderAndActivates() async {
        let model = await startedHarness(rootLister()).model
        model.activate(.right)

        model.springLoad(.left, into: "a")
        await model.waitUntilIdle()

        #expect(model.state.activeSide == .left)
        #expect(model.tab(.left).path.path == "/root/a")
    }

    @Test func springLoadOnFileDoesNothing() async {
        let model = await startedHarness(rootLister()).model

        model.springLoad(.left, into: "b.txt")

        #expect(model.tab(.left).path.path == "/root")
    }

    @Test func springLoadParentGoesUp() async {
        let model = await startedHarness(rootLister()).model
        model.openFolder(.left, root.appendingPathComponent("a"))
        await model.waitUntilIdle()
        model.activate(.right)

        model.springLoadParent(.left)
        await model.waitUntilIdle()

        #expect(model.tab(.left).path.path == "/root")
        #expect(model.tab(.left).cursor == "a")
        #expect(model.state.activeSide == .left)
    }

    @Test func springLoadTabSelectsTab() async {
        let model = await startedHarness(rootLister()).model
        model.perform(.newTab)
        model.selectTab(.left, at: 0)
        model.activate(.right)

        model.springLoadTab(.left, at: 1)

        #expect(model.state.left.activeTabIndex == 1)
        #expect(model.state.activeSide == .left)
        #expect(model.tabPath(.left, at: 1)?.path == "/root")
        #expect(model.tabPath(.left, at: 5) == nil)
    }

    @Test func dropToURLUsesPolicy() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        let source = h.left.appendingPathComponent("a.txt")

        #expect(h.model.dropOperation([source], to: h.right, forceCopy: false) == .move)
        #expect(h.model.dropOperation([source], to: h.right, forceCopy: true) == .copy)
        #expect(h.model.drop([source], to: h.right, forceCopy: false))
        await h.model.waitUntilIdle()

        #expect(h.exists("right/a.txt"))
        #expect(!h.exists("left/a.txt"))
    }

    @Test func dropIntoDraggedFolderAfterSpringLoadIsNone() async throws {
        let h = try await FileHarness(files: ["sub/"])
        defer { h.tmp.remove() }
        let sub = h.left.appendingPathComponent("sub")

        #expect(h.model.dropOperation([sub], to: sub, forceCopy: false) == .none)
        #expect(!h.model.drop([sub], to: sub, forceCopy: false))
    }
}
