import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct RevealTests {
    @Test func revealFileOpensParentInNewTab() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.activate(.right)

        h.model.reveal(h.left.appendingPathComponent("b.txt"))
        await h.model.waitUntilIdle()

        #expect(h.model.state.right.tabs.count == 2)
        #expect(h.model.tab(.right).path.lastPathComponent == "left")
        #expect(h.model.tab(.right).cursor == "b.txt")
        #expect(h.model.state.left.tabs.count == 1)
    }

    @Test func revealFolderOpensIt() async throws {
        let h = try await FileHarness(files: ["sub/", "a.txt"])
        defer { h.tmp.remove() }

        h.model.reveal(h.left.appendingPathComponent("sub"))
        await h.model.waitUntilIdle()

        #expect(h.model.state.left.tabs.count == 2)
        #expect(h.model.tab(.left).path.lastPathComponent == "sub")
    }

    @Test func revealPackageSelectsIt() async throws {
        let h = try await FileHarness(files: ["X.app/", "a.txt"])
        defer { h.tmp.remove() }
        h.model.activate(.right)

        h.model.reveal(h.left.appendingPathComponent("X.app"))
        await h.model.waitUntilIdle()

        #expect(h.model.tab(.right).path.lastPathComponent == "left")
        #expect(h.model.tab(.right).cursor == "X.app")
    }

    @Test func revealMissingBeeps() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.reveal(h.left.appendingPathComponent("gone.txt"))

        #expect(h.harness.effects.beeps == 1)
        #expect(h.model.state.left.tabs.count == 1)
    }
}
