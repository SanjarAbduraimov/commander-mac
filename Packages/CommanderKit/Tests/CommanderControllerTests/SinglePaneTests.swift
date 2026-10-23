import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct SinglePaneTests {
    private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

    @Test func toggleSinglePaneActivatesLeftAndPersists() async {
        let model = await startedHarness().model
        model.activate(.right)

        model.perform(.toggleSinglePane)

        #expect(model.isSinglePane)
        #expect(model.state.activeSide == .left)
        #expect(model.sessionSnapshot().singlePane)
        model.perform(.toggleSinglePane)
        #expect(!model.isSinglePane)
    }

    @Test func tabDoesNothingInSinglePane() async {
        let model = await startedHarness().model
        model.perform(.toggleSinglePane)

        #expect(!model.handleKey(chord("tab"), context: .table))
        model.activate(.right)
        #expect(model.state.activeSide == .left)
    }

    @Test func singlePaneF5AsksForDestination() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        h.model.perform(.toggleSinglePane)

        h.model.perform(.copyToOtherPane)
        await h.model.waitUntilIdle()
        h.model.perform(.moveToOtherPane)
        await h.model.waitUntilIdle()

        #expect(h.harness.effects.destinationRequests.map(\.kind) == [.copy, .move])
        #expect(h.harness.effects.destinationRequests.first?.suggested.lastPathComponent == "left")
        #expect(!h.exists("right/a.txt"))
        #expect(h.exists("left/a.txt"))
    }

    @Test func singlePaneSuggestsLastRecentDestination() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        let other = try h.tmp.dir("other")
        h.harness.effects.destinationAnswer = other
        h.model.perform(.copyTo)
        await h.model.waitUntilIdle()
        h.model.perform(.toggleSinglePane)

        h.model.perform(.copyTo)
        await h.model.waitUntilIdle()

        #expect(h.harness.effects.destinationRequests.last?.suggested.lastPathComponent == "other")
    }

    @Test func toggleIsAllowedInTextField() async {
        let model = await startedHarness().model
        #expect(model.handleKey(chord("cmd+\\"), context: .textField))
        #expect(model.isSinglePane)
    }
}
