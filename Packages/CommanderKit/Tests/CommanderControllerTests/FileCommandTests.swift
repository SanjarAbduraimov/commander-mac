import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

/// Real folders `left/` and `right/` in a temp dir, read with `DirectoryReader`; the Trash is faked.
@MainActor
struct FileHarness {
    let tmp: TempDir
    let harness: Harness
    var model: WindowModel { harness.model }
    var left: URL { tmp.url.appendingPathComponent("left", isDirectory: true) }
    var right: URL { tmp.url.appendingPathComponent("right", isDirectory: true) }

    init(files: [String] = ["a.txt", "b.txt"], settings: AppSettings = AppSettings()) async throws {
        tmp = try TempDir()
        try tmp.dir("left")
        try tmp.dir("right")
        for name in files {
            if name.hasSuffix("/") { try tmp.dir("left/" + name) } else { try tmp.file("left/" + name, bytes: 3) }
        }
        harness = Harness(
            left: [tmp.url.appendingPathComponent("left", isDirectory: true)],
            right: [tmp.url.appendingPathComponent("right", isDirectory: true)],
            settings: settings,
            environment: .test(lister: DirectoryReader())
        )
        harness.model.start()
        await harness.model.waitUntilIdle()
    }

    func names(_ side: PaneSide) -> [String] {
        model.tab(side).items.map(\.name)
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: tmp.url.appendingPathComponent(path).path)
    }
}

@MainActor
struct FileCommandTests {
    @Test func f5CopiesTargetsToOtherPane() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.toggleMark(name: "a.txt"); $0.toggleMark(name: "b.txt") }

        h.model.perform(.copyToOtherPane)
        #expect(h.model.tab(.left).marked.isEmpty)
        await h.model.waitUntilIdle()

        #expect(h.exists("right/a.txt") && h.exists("right/b.txt"))
        #expect(h.exists("left/a.txt"))
        #expect(h.names(.right) == ["a.txt", "b.txt"])
    }

    @Test func f6MovesTargets() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.moveToOtherPane)
        await h.model.waitUntilIdle()

        #expect(h.exists("right/a.txt"))
        #expect(!h.exists("left/a.txt"))
        #expect(h.names(.left) == ["b.txt"])
        #expect(h.names(.right) == ["a.txt"])
    }

    @Test func askDestinationUsesAnswer() async throws {
        var settings = AppSettings()
        settings.behavior.askDestinationForCopyMove = true
        let h = try await FileHarness(settings: settings)
        defer { h.tmp.remove() }
        let other = try h.tmp.dir("other")
        h.harness.effects.destinationAnswer = other

        h.model.perform(.copyToOtherPane)
        await h.model.waitUntilIdle()

        #expect(h.exists("other/a.txt"))
        #expect(!h.exists("right/a.txt"))
        let request = try #require(h.harness.effects.destinationRequests.first)
        #expect(request.suggested.standardizedFileURL.path == h.right.standardizedFileURL.path)
        #expect(request.kind == .copy && request.count == 1)

        h.harness.effects.destinationAnswer = nil
        h.model.perform(.moveToOtherPane)
        await h.model.waitUntilIdle()
        #expect(h.exists("left/a.txt"))
        #expect(h.harness.effects.destinationRequests.count == 2)
    }

    @Test func duplicateCreatesCopyName() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.duplicate)
        await h.model.waitUntilIdle()

        #expect(h.names(.left) == ["a copy.txt", "a.txt", "b.txt"])
    }

    @Test func trashUsesOperationCenter() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.setCursor(name: "b.txt") }

        h.model.perform(.moveToTrash)
        await h.model.waitUntilIdle()

        #expect(h.harness.trasher.trashed.map(\.lastPathComponent) == ["b.txt"])
    }

    @Test func newFolderCreatesThenBeginsRename() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.newFolder)
        await h.model.waitUntilIdle()

        #expect(h.exists("left/untitled folder"))
        #expect(h.harness.effects.renames.map(\.name) == ["untitled folder"])
        #expect(h.harness.effects.renames.map(\.side) == [.left])
        #expect(h.model.tab(.left).cursor == "untitled folder")
    }

    @Test func openInTerminalFolderScope() async throws {
        let h = try await FileHarness(files: ["sub/", "a.txt"])
        defer { h.tmp.remove() }

        h.model.perform(.openInTerminal, scope: .folder)
        h.model.perform(.openInTerminal)
        h.model.mutateTab(.left) { $0.setCursor(name: "a.txt") }
        h.model.perform(.openInTerminal)

        #expect(h.harness.effects.terminals.map(\.lastPathComponent) == ["left", "sub", "left"])
    }

    @Test func revealAndPackageContents() async throws {
        let h = try await FileHarness(files: ["X.app/", "a.txt"])
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.setCursor(name: "X.app") }

        h.model.perform(.revealInFinder)
        #expect(h.harness.effects.revealed.map { $0.map(\.lastPathComponent) } == [["X.app"]])

        h.model.perform(.showPackageContents)
        await h.model.waitUntilIdle()
        #expect(h.model.tab(.left).path.lastPathComponent == "X.app")
    }

    @Test func newFileCreatesThenBeginsRename() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.newFile)
        await h.model.waitUntilIdle()

        #expect(h.exists("left/Untitled.txt"))
        #expect(h.harness.effects.renames.map(\.name).contains("Untitled.txt"))
        #expect(h.model.tab(.left).cursor == "Untitled.txt")
    }

    @Test func openRespectsFileAssociations() async throws {
        var settings = AppSettings()
        settings.setApp("/Applications/TextEdit.app", forExtension: "txt")
        let h = try await FileHarness(files: ["note.txt"], settings: settings)
        defer { h.tmp.remove() }

        h.model.mutateTab(.left) { $0.setCursor(name: "note.txt") }
        h.model.perform(.open)

        #expect(h.harness.effects.openedWithApp.count == 1)
        #expect(h.harness.effects.openedWithApp.first?.url.lastPathComponent == "note.txt")
        #expect(h.harness.effects.openedWithApp.first?.appURL?.path == "/Applications/TextEdit.app")
    }

    @Test func openWithAppAndQuickLookTriggerEffects() async throws {
        let h = try await FileHarness(files: ["photo.png"])
        defer { h.tmp.remove() }

        h.model.mutateTab(.left) { $0.setCursor(name: "photo.png") }
        h.model.perform(.openWithApp)
        h.model.perform(.quickLook)

        #expect(h.harness.effects.openWithAppPrompts.first?.map(\.lastPathComponent) == ["photo.png"])
        #expect(h.harness.effects.quickLooks.first?.map(\.lastPathComponent) == ["photo.png"])
    }
}
