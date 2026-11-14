import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct CommandTests {
    private let a = root.appendingPathComponent("a")

    @Test func openFolderNavigatesAndLoads() async {
        let model = await startedHarness().model

        model.perform(.open)
        await model.waitUntilIdle()

        #expect(model.tab(.left).path.standardizedFileURL.path == a.path)
        #expect(model.tab(.left).items.map(\.name) == ["inner.txt"])
    }

    @Test func openFileAndPackageUseEffects() async {
        let lister = FakeLister(["/root": [item("b.txt"), item("X.app", .package)]])
        let harness = await startedHarness(lister)

        harness.model.perform(.open)
        harness.model.mutateTab(.left) { $0.setCursor(name: "X.app") }
        harness.model.perform(.open)

        #expect(harness.effects.opened == [root.appendingPathComponent("b.txt"), root.appendingPathComponent("X.app", isDirectory: true)])
        #expect(harness.model.tab(.left).path == root)
    }

    @Test func goUpPutsCursorOnLeftFolder() async {
        let model = await startedHarness(left: [a]).model

        model.perform(.goUp)
        await model.waitUntilIdle()

        #expect(model.tab(.left).path.standardizedFileURL.path == "/root")
        #expect(model.tab(.left).cursor == "a")
    }

    @Test func backspaceFollowsHistoryBackBehavior() async {
        let lister = thirtyItemLister()
        lister.set("/other", [item("o.txt", in: URL(fileURLWithPath: "/other"))])
        var settings = AppSettings()
        settings.behavior.backspaceAction = .historyBack
        let model = await startedHarness(lister, left: [a], settings: settings).model
        model.navigate(.left, to: URL(fileURLWithPath: "/other"))
        await model.waitUntilIdle()

        #expect(model.handleKey(KeyChord("backspace"), context: .table))
        await model.waitUntilIdle()

        #expect(model.tab(.left).path == a)
    }

    @Test func spaceRespectsSpaceAdvances() async {
        let model = await startedHarness().model
        model.perform(.toggleMark)
        #expect(model.tab(.left).marked == ["a"])
        #expect(model.tab(.left).cursor == "b.txt")

        var settings = AppSettings()
        settings.behavior.spaceAdvances = false
        let staying = await startedHarness(settings: settings).model
        staying.perform(.toggleMark)
        #expect(staying.tab(.left).marked == ["a"])
        #expect(staying.tab(.left).cursor == "a")
    }

    @Test func switchPaneAndTabs() async {
        let watchers = FakeWatcherFactory()
        let model = await startedHarness(watchers: watchers).model

        model.perform(.switchPane)
        #expect(model.state.activeSide == .right)

        model.perform(.newTab)
        await model.waitUntilIdle()
        #expect(model.state.right.tabs.count == 2)
        #expect(model.state.right.activeTabIndex == 1)
        #expect(model.tab(.right).items.count == 30)

        model.perform(.closeTab)
        #expect(model.state.right.tabs.count == 1)
        model.perform(.closeTab)
        #expect(model.state.right.tabs.count == 1)

        model.perform(.newTab)
        model.perform(.newTab)
        model.closeTab(.right, at: 0)
        #expect(model.state.right.tabs.count == 2)
        model.perform(.previousTab)
        #expect(model.state.right.activeTabIndex == 1)
        model.selectTab(.right, at: 0)
        #expect(model.state.right.activeTabIndex == 0)
        await model.waitUntilIdle()
        #expect(watchers.active.count == 2)
    }

    @Test func toggleHiddenAndReload() async {
        let lister = FakeLister(["/root": [item(".hidden"), item("b.txt")]])
        let model = await startedHarness(lister).model
        #expect(model.tab(.left).items.map(\.name) == ["b.txt"])

        model.perform(.toggleHiddenFiles)
        #expect(model.tab(.left).items.map(\.name) == [".hidden", "b.txt"])

        let calls = lister.calls.count
        model.perform(.reload)
        await model.waitUntilIdle()
        #expect(lister.calls.count == calls + 1)
    }

    @Test func focusPathFieldUsesEffects() async {
        let harness = await startedHarness()

        harness.model.perform(.focusPathField)
        harness.model.perform(.openSettings)
        harness.model.perform(.connectToServer)

        #expect(harness.effects.focusedPathFields == [.left])
        #expect(harness.effects.settingsShown == 1)
        #expect(harness.effects.connectShown == 1)
    }

    @Test func goToPathHandlesTildeFileAndMissing() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file("b.txt")
        let harness = Harness(left: [tmp.url], right: [tmp.url], environment: .test(lister: DirectoryReader()))
        let model = harness.model
        model.start()
        await model.waitUntilIdle()

        #expect(model.goToPath(.left, "  ~ "))
        #expect(model.tab(.left).path.standardizedFileURL.path == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path)

        #expect(model.goToPath(.left, tmp.url.appendingPathComponent("b.txt").path))
        await model.waitUntilIdle()
        #expect(model.tab(.left).path.standardizedFileURL.path == tmp.url.standardizedFileURL.path)
        #expect(model.tab(.left).cursor == "b.txt")

        #expect(!model.goToPath(.left, tmp.url.appendingPathComponent("missing").path))
        #expect(harness.effects.beeps == 1)
    }

    @Test func targetCommandsDisabledOnEmptyFolder() async {
        let model = await startedHarness(FakeLister(["/root": []])).model

        for command in [Command.copyToOtherPane, .moveToOtherPane, .duplicate, .moveToTrash, .copyToClipboard,
                        .cutToClipboard, .copyPath, .copyName, .revealInFinder, .rename, .showPackageContents, .paste] {
            #expect(!model.isEnabled(command, context: .table), "\(command)")
        }
        #expect(model.isEnabled(.newFolder, context: .table))
        #expect(model.isEnabled(.openInTerminal, context: .table))
    }

    @Test func toggleQuickViewTogglesOppositePaneAndEscClosesIt() async {
        let model = await startedHarness().model

        #expect(model.quickViewSide == nil)
        #expect(model.isEnabled(.toggleQuickView, context: .table))

        // Toggle on: left is active, so quickViewSide becomes right
        model.perform(.toggleQuickView)
        #expect(model.quickViewSide == .right)
        #expect(model.isEnabled(.unmarkAll, context: .table))

        // Esc (.unmarkAll) closes Quick View
        model.perform(.unmarkAll)
        #expect(model.quickViewSide == nil)

        // Toggle on again
        model.perform(.toggleQuickView)
        #expect(model.quickViewSide == .right)

        // Toggle again turns it off
        model.perform(.toggleQuickView)
        #expect(model.quickViewSide == nil)
    }
}
