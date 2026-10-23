import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct WindowModelLoadingTests {
    private let a = root.appendingPathComponent("a")

    @Test func startLoadsBothPanes() async {
        let harness = Harness(environment: .test(lister: rootLister()))
        let model = harness.model

        model.start()
        await model.waitUntilIdle()

        for side in [PaneSide.left, .right] {
            #expect(model.tab(side).items.map(\.name) == ["a", "b.txt", "c.txt"])
            #expect(model.tab(side).cursor == "a")
            #expect(model.listingVersion(side) == 1)
        }
    }

    @Test func staleListingIsDropped() async {
        let lister = rootLister()
        lister.set("/slow", [item("slow.txt", in: URL(fileURLWithPath: "/slow"))])
        lister.set("/fast", [item("fast.txt", in: URL(fileURLWithPath: "/fast"))])
        let gated = GatedLister(lister, gating: ["/slow"])
        let model = Harness(environment: .test(lister: gated)).model
        model.start()
        await model.waitUntilIdle()

        model.navigate(.left, to: URL(fileURLWithPath: "/slow"))
        model.navigate(.left, to: URL(fileURLWithPath: "/fast"))
        #expect(await eventually { model.tab(.left).items.map(\.name) == ["fast.txt"] })
        gated.open()
        await model.waitUntilIdle()

        #expect(model.tab(.left).path.path == "/fast")
        #expect(model.tab(.left).items.map(\.name) == ["fast.txt"])
    }

    @Test func deletedFolderFallsBackToNearestParent() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let folder = try tmp.dir("a")
        let environment = WindowEnvironment.test(lister: DirectoryReader())
        let model = Harness(left: [folder], right: [tmp.url], environment: environment).model
        model.start()
        await model.waitUntilIdle()

        try FileManager.default.removeItem(at: folder)
        model.reload(.left)
        await model.waitUntilIdle()

        #expect(model.tab(.left).path.standardizedFileURL.path == tmp.url.standardizedFileURL.path)
        #expect(model.tab(.left).items.isEmpty)
    }

    @Test func permissionDeniedShowsBannerUntilSuccess() async {
        let lister = rootLister()
        lister.fail("/root", .permissionDenied)
        let model = Harness(environment: .test(lister: lister)).model
        model.start()
        await model.waitUntilIdle()

        #expect(model.banner(.left) == .noAccess)
        #expect(model.tab(.left).items.isEmpty)

        lister.set("/root", [item("b.txt")])
        model.reload(.left)
        await model.waitUntilIdle()

        #expect(model.banner(.left) == nil)
        #expect(model.tab(.left).items.map(\.name) == ["b.txt"])
    }

    @Test func otherErrorShowsUnreadableBanner() async {
        let lister = rootLister()
        lister.fail("/root", .other("boom"))
        let model = Harness(environment: .test(lister: lister)).model

        model.start()
        await model.waitUntilIdle()

        #expect(model.banner(.left) == .unreadable("boom"))
    }

    @Test func activeTabIsWatched() async {
        let watchers = FakeWatcherFactory()
        let model = Harness(right: [a], environment: .test(lister: rootLister(), watchers: watchers)).model

        model.start()
        await model.waitUntilIdle()

        #expect(watchers.active.map(\.path.path).sorted() == ["/root", "/root/a"])
    }

    @Test func navigationSwapsWatcher() async {
        let watchers = FakeWatcherFactory()
        let model = Harness(environment: .test(lister: rootLister(), watchers: watchers)).model
        model.start()
        await model.waitUntilIdle()
        let leftWatcher = watchers.watchers[0]

        model.navigate(.left, to: a)
        await model.waitUntilIdle()

        #expect(leftWatcher.isStopped)
        #expect(watchers.active.map(\.path.path).sorted() == ["/root", "/root/a"])
    }

    @Test func watcherEventReloadsKeepingCursor() async {
        let lister = rootLister()
        let watchers = FakeWatcherFactory()
        let model = Harness(environment: .test(lister: lister, watchers: watchers)).model
        model.start()
        await model.waitUntilIdle()
        model.mutateTab(.left) { $0.setCursor(name: "c.txt") }

        lister.set("/root", [item("a", .directory), item("b.txt"), item("c.txt"), item("d.txt")])
        watchers.watchers.first { $0.path.path == "/root" && $0.isStarted }!.fire()

        #expect(await eventually { model.tab(.left).items.count == 4 })
        #expect(model.tab(.left).cursor == "c.txt")
    }

    @Test func lateWatcherEventAfterStopIsIgnored() async throws {
        let lister = rootLister()
        let watchers = FakeWatcherFactory()
        let model = Harness(right: [a], environment: .test(lister: lister, watchers: watchers)).model
        model.start()
        await model.waitUntilIdle()
        let oldLeft = watchers.watchers[0]
        model.navigate(.left, to: a)
        await model.waitUntilIdle()
        let callsBefore = lister.calls.count

        oldLeft.fire()
        try await Task.sleep(for: .milliseconds(50))
        await model.waitUntilIdle()

        #expect(lister.calls.count == callsBefore)
    }

    @Test func networkPanesReloadOnFocus() async {
        let lister = rootLister()
        lister.set("/net", [item("n.txt", in: URL(fileURLWithPath: "/net"))])
        let environment = WindowEnvironment.test(lister: lister, isNetworkPath: { $0.path.hasPrefix("/net") })
        let model = Harness(right: [URL(fileURLWithPath: "/net")], environment: environment).model
        model.start()
        await model.waitUntilIdle()
        let callsBefore = lister.calls.count

        model.appDidBecomeActive()
        await model.waitUntilIdle()
        #expect(Array(lister.calls.dropFirst(callsBefore)) == ["/net"])

        model.activate(.right)
        await model.waitUntilIdle()
        #expect(Array(lister.calls.dropFirst(callsBefore)) == ["/net", "/net"])
        #expect(model.state.activeSide == .right)

        model.activate(.left)
        await model.waitUntilIdle()
        #expect(Array(lister.calls.dropFirst(callsBefore)) == ["/net", "/net"])
    }

    @Test func sessionSnapshotFollowsState() async {
        let model = Harness(environment: .test(lister: rootLister())).model
        var published: [Session] = []
        model.onSessionChange = { published.append($0) }
        model.start()
        await model.waitUntilIdle()

        model.navigate(.left, to: a)
        await model.waitUntilIdle()

        #expect(published.last?.left.tabPaths == [a])
        #expect(model.sessionSnapshot().left.tabPaths == [a])
        #expect(Set(published.map(\.left.tabPaths)).count == published.count)
    }
}
