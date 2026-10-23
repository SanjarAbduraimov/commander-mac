import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct ClipboardTests {
    @Test func copyThenPasteCopies() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.copyToClipboard)
        #expect(h.harness.pasteboard.files?.isCut == false)
        h.model.activate(.right)
        h.model.perform(.paste)
        await h.model.waitUntilIdle()

        #expect(h.exists("right/a.txt") && h.exists("left/a.txt"))
        #expect(h.names(.right) == ["a.txt"])
    }

    @Test func cutThenPasteMovesAndClearsCut() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.cutToClipboard)
        h.model.activate(.right)
        h.model.perform(.paste)
        await h.model.waitUntilIdle()

        #expect(h.exists("right/a.txt") && !h.exists("left/a.txt"))
        #expect(h.harness.pasteboard.files?.isCut == false)
        #expect(h.names(.left) == ["b.txt"])
    }

    @Test func copyPathAndNameJoinLines() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.markAll() }

        h.model.perform(.copyPath)
        h.model.perform(.copyName)

        let paths = h.model.tab(.left).items.map(\.url.path)
        #expect(paths.map { ($0 as NSString).lastPathComponent } == ["a.txt", "b.txt"])
        #expect(h.harness.pasteboard.strings == [paths.joined(separator: "\n"), "a.txt\nb.txt"])
    }
}
