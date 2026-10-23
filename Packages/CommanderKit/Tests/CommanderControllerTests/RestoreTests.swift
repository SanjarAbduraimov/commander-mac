import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

struct RestoreTests {
    private let home = FileManager.default.homeDirectoryForCurrentUser

    @Test func restoresTabsAndActiveSide() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let (d1, d2, d3) = (try tmp.dir("d1"), try tmp.dir("d2"), try tmp.dir("d3"))
        var session = Session()
        session.left = PaneSession(tabPaths: [d1, d2], activeTab: 1)
        session.right = PaneSession(tabPaths: [d3])
        session.activeSide = .right

        let state = WindowState.restored(from: session, behavior: BehaviorSettings(), lister: DirectoryReader())

        #expect(state.left.tabs.map(\.path.path) == [d1.path, d2.path])
        #expect(state.left.activeTabIndex == 1)
        #expect(state.right.tabs.map(\.path.path) == [d3.path])
        #expect(state.activeSide == .right)
    }

    @Test func restoreFallsBackForMissingPaths() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try tmp.dir("a")
        var session = Session()
        session.left = PaneSession(tabPaths: [a.appendingPathComponent("b")], activeTab: 5)

        let state = WindowState.restored(from: session, behavior: BehaviorSettings(), lister: DirectoryReader())

        #expect(state.left.tabs.map(\.path.standardizedFileURL.path) == [a.standardizedFileURL.path])
        #expect(state.left.activeTabIndex == 0)
    }

    @Test func restoreDisabledOpensHomeOnce() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        var session = Session()
        session.left = PaneSession(tabPaths: [try tmp.dir("x"), try tmp.dir("y")])
        session.activeSide = .right
        var behavior = BehaviorSettings()
        behavior.restoreTabsOnLaunch = false

        let state = WindowState.restored(from: session, behavior: behavior, lister: DirectoryReader())

        #expect(state.left.tabs.map(\.path) == [home])
        #expect(state.right.tabs.map(\.path) == [home])
        #expect(state.activeSide == .left)
    }

    @Test func newTabsUseShowHiddenDefault() {
        var behavior = BehaviorSettings()
        behavior.showHiddenByDefault = true

        let state = WindowState.restored(from: Session(), behavior: behavior, lister: DirectoryReader())

        let tabs = state.left.tabs + state.right.tabs
        #expect(tabs.allSatisfy { $0.showHidden })
    }

    @Test func launchFoldersUsedWhenNotRestoring() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        var behavior = BehaviorSettings()
        behavior.restoreTabsOnLaunch = false
        behavior.launchLeftFolder = try tmp.dir("a")

        let state = WindowState.restored(from: Session(), behavior: behavior, lister: DirectoryReader())

        #expect(state.left.tabs.map(\.path.standardizedFileURL.path) == [tmp.url.appendingPathComponent("a").standardizedFileURL.path])
        #expect(state.right.tabs.map(\.path) == [home])
    }

    @Test func missingLaunchFolderFallsBackToParent() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        var behavior = BehaviorSettings()
        behavior.restoreTabsOnLaunch = false
        behavior.launchRightFolder = try tmp.dir("a").appendingPathComponent("gone")

        let state = WindowState.restored(from: Session(), behavior: behavior, lister: DirectoryReader())

        #expect(state.right.tabs.map(\.path.standardizedFileURL.path) == [tmp.url.appendingPathComponent("a").standardizedFileURL.path])
    }

    @Test func singlePaneRestoresLeftAsActive() {
        var session = Session()
        session.singlePane = true
        session.activeSide = .right

        let state = WindowState.restored(from: session, behavior: BehaviorSettings(), lister: DirectoryReader())

        #expect(state.activeSide == .left)
    }
}
