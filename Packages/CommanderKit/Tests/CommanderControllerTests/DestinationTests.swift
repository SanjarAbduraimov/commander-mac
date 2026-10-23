import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct DestinationTests {
    private func path(_ url: URL?) -> String? { url?.standardizedFileURL.resolvingSymlinksInPath().path }

    @Test func copyToUsesChosenFolderAndRemembersIt() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        let other = try h.tmp.dir("other")
        h.harness.effects.destinationAnswer = other

        h.model.perform(.copyTo)
        await h.model.waitUntilIdle()

        #expect(h.exists("other/a.txt"))
        #expect(!h.exists("right/a.txt"))
        #expect(h.exists("left/a.txt"))
        #expect(path(h.model.sessionSnapshot().recentDestinations.first) == path(other))
        #expect(h.harness.effects.destinationRequests.first?.kind == .copy)
    }

    @Test func moveToMovesAndClearsMarks() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        let other = try h.tmp.dir("other")
        h.harness.effects.destinationAnswer = other
        h.model.mutateTab(.left) { $0.toggleMark(name: "a.txt"); $0.toggleMark(name: "b.txt") }

        h.model.perform(.moveTo)
        await h.model.waitUntilIdle()

        #expect(h.exists("other/a.txt") && h.exists("other/b.txt"))
        #expect(!h.exists("left/a.txt"))
        #expect(h.model.tab(.left).marked.isEmpty)
        #expect(h.harness.effects.destinationRequests.first?.count == 2)
    }

    @Test func cancelledChoiceDoesNothing() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.toggleMark(name: "a.txt") }

        h.model.perform(.moveTo)
        await h.model.waitUntilIdle()

        #expect(h.exists("left/a.txt"))
        #expect(h.model.tab(.left).marked == ["a.txt"])
        #expect(h.model.sessionSnapshot().recentDestinations.isEmpty)
    }

    @Test func requestListsRecentTabsFavorites() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        let other = try h.tmp.dir("other")
        h.model.activate(.right)
        h.model.perform(.newTab)
        h.model.goToPath(.right, other.path)
        h.model.perform(.newTab)
        h.model.activate(.left)
        await h.model.waitUntilIdle()

        h.model.perform(.copyTo)
        await h.model.waitUntilIdle()

        let request = try #require(h.harness.effects.destinationRequests.first)
        #expect(request.tabs.map(path) == [path(h.right), path(other)])
        #expect(path(request.suggested) == path(other))
        #expect(request.favorites == h.model.sidebar.favorites)
        #expect(request.recent.isEmpty)
    }

    @Test func copyToIntoItselfIsRefused() async throws {
        let h = try await FileHarness(files: ["sub/"])
        defer { h.tmp.remove() }
        h.harness.effects.destinationAnswer = try h.tmp.dir("left/sub/inner")

        h.model.perform(.copyTo)
        await h.model.waitUntilIdle()

        #expect(h.harness.effects.beeps == 1)
        #expect(!h.exists("left/sub/inner/sub"))
        #expect(h.model.sessionSnapshot().recentDestinations.isEmpty)
    }

    @Test func createFolderInDestination() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        let other = try h.tmp.dir("other")

        let folder = try await h.model.createFolder(in: other)

        #expect(folder.lastPathComponent == "untitled folder")
        #expect(h.exists("other/untitled folder"))
    }

    @Test func createDirectoryMakesIntermediates() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        try await h.model.createDirectory(at: h.tmp.url.appendingPathComponent("a/b/c"))

        #expect(h.exists("a/b/c"))
    }

    @Test func folderSuggestionsMatchPrefix() async throws {
        let h = try await FileHarness(files: ["sub/", "Second/", "sa.txt", ".secret/"])
        defer { h.tmp.remove() }

        #expect(h.model.folderSuggestions(for: h.left.path + "/s") == [h.left.path + "/Second", h.left.path + "/sub"])
        #expect(h.model.folderSuggestions(for: h.left.path + "/SU") == [h.left.path + "/sub"])
        #expect(h.model.folderSuggestions(for: h.left.path + "/.s") == [h.left.path + "/.secret"])
        #expect(h.model.folderSuggestions(for: h.left.path + "/nope/x").isEmpty)
    }

    @Test func askDestinationSettingUsesSameDialog() async throws {
        var settings = AppSettings()
        settings.behavior.askDestinationForCopyMove = true
        let h = try await FileHarness(settings: settings)
        defer { h.tmp.remove() }

        h.model.perform(.copyToOtherPane)
        await h.model.waitUntilIdle()

        let request = try #require(h.harness.effects.destinationRequests.first)
        #expect(request.kind == .copy)
        #expect(path(request.suggested) == path(h.right))
        #expect(!h.exists("right/a.txt"))
    }
}
