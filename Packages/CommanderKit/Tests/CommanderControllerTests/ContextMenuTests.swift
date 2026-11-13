import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct ContextMenuTests {
    private func commands(_ menu: [MenuItemModel]) -> [Command?] {
        menu.map { if case let .entry(entry) = $0 { entry.command } else { nil } }
    }

    private func entry(_ menu: [MenuItemModel], _ command: Command) -> MenuEntry? {
        for item in menu { if case let .entry(entry) = item, entry.command == command { return entry } }
        return nil
    }

    @Test func menuOnUnmarkedRowMovesCursor() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.toggleMark(name: "a") }

        _ = model.contextMenu(.left, row: "b.txt")

        #expect(model.tab(.left).cursor == "b.txt")
        #expect(model.tab(.left).targets.map(\.name) == ["a"])
        model.mutateTab(.left) { $0.clearMarks() }
        _ = model.contextMenu(.left, row: "c.txt")
        #expect(model.tab(.left).targets.map(\.name) == ["c.txt"])
    }

    @Test func menuOnMarkedRowKeepsMarks() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.toggleMark(name: "b.txt"); $0.toggleMark(name: "c.txt") }

        _ = model.contextMenu(.left, row: "c.txt")

        #expect(model.tab(.left).marked == ["b.txt", "c.txt"])
        #expect(model.tab(.left).cursor == "a")
    }

    @Test func fileMenuEntries() async {
        let model = await startedHarness().model

        let menu = model.contextMenu(.left, row: "b.txt")

        #expect(commands(menu) == [
            .open, .openWithApp, .quickLook, nil, .copyToOtherPane, .moveToOtherPane, .copyTo, .moveTo, nil, .rename, .multiRename, .duplicate, .moveToTrash, .deleteImmediately, nil,
            .copyPath, .copyName, nil, .revealInFinder, .openInTerminal,
        ])
        #expect(entry(menu, .copyToOtherPane)?.shortcut == "F5")
        #expect(entry(menu, .moveToOtherPane)?.shortcut == "F6")
        #expect(entry(menu, .copyTo)?.shortcut == "⌥F5")
        #expect(entry(menu, .rename)?.shortcut == "F2")
        #expect(entry(menu, .duplicate)?.shortcut == "⌘D")
        #expect(entry(menu, .moveToTrash)?.shortcut == "⌘⌫")
        #expect(entry(menu, .openWithApp)?.shortcut == "⌥↩")
        #expect(entry(menu, .quickLook)?.shortcut == "F3")
        #expect(entry(menu, .copyPath)?.shortcut == nil)
        #expect(entry(menu, .copyName)?.title == "Copy Name")
        #expect(entry(menu, .openInTerminal)?.scope == .targets)
    }

    @Test func packageContentsOnlyForSinglePackage() async {
        let lister = FakeLister(["/root": [item("X.app", .package), item("Y.app", .package), item("b.txt")]])
        let model = await startedHarness(lister).model

        #expect(commands(model.contextMenu(.left, row: "X.app")).contains(.showPackageContents))
        #expect(!commands(model.contextMenu(.left, row: "b.txt")).contains(.showPackageContents))
        model.mutateTab(.left) { $0.toggleMark(name: "X.app"); $0.toggleMark(name: "Y.app") }
        #expect(!commands(model.contextMenu(.left, row: "X.app")).contains(.showPackageContents))
    }

    @Test func emptySpaceMenu() async {
        let harness = await startedHarness()
        let model = harness.model

        let menu = model.contextMenu(.left, row: nil)
        #expect(commands(menu) == [.newFolder, .newFile, .pasteImage, .toggleHiddenFiles, nil, .openInTerminal])
        #expect(entry(menu, .toggleHiddenFiles)?.title == "Show Hidden Files")
        #expect(entry(menu, .openInTerminal)?.scope == .folder)
        #expect(entry(menu, .newFolder)?.shortcut == "F7")
        #expect(entry(menu, .newFile)?.shortcut == "⌘N")

        harness.pasteboard.writeFiles([root.appendingPathComponent("b.txt")], cut: false)
        model.perform(.toggleHiddenFiles)
        let afterToggle = model.contextMenu(.left, row: nil)
        #expect(commands(afterToggle) == [.newFolder, .newFile, .paste, .pasteImage, .toggleHiddenFiles, nil, .openInTerminal])
        #expect(entry(afterToggle, .toggleHiddenFiles)?.title == "Hide Hidden Files")
    }

    @Test func menuActivatesPane() async {
        let model = await startedHarness().model

        _ = model.contextMenu(.right, row: nil)

        #expect(model.state.activeSide == .right)
    }
}
