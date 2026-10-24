import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct MultiRenameCommandTests {
    private func markAll(_ h: FileHarness) {
        h.model.mutateTab(.left) { $0.markAll() }
    }

    private func request(_ h: FileHarness) async throws -> MultiRenameRequest {
        h.model.perform(.multiRename)
        await h.model.waitUntilIdle()
        return try #require(h.harness.effects.multiRenameRequests.last)
    }

    private func rows(_ request: MultiRenameRequest, mask: String) -> [MultiRenameRow] {
        var options = MultiRenameOptions()
        options.nameMask = mask
        return MultiRename.preview(request.items, folderName: request.folder.lastPathComponent, existing: request.existing, options: options)
    }

    @Test func ctrlMOpensRequestWithHiddenNames() async throws {
        let h = try await FileHarness(files: ["a.txt", "b.txt", ".hidden"])
        defer { h.tmp.remove() }
        markAll(h)

        let request = try await request(h)

        #expect(request.items.map(\.name) == ["a.txt", "b.txt"])
        #expect(request.existing.contains(".hidden"))
        #expect(request.side == .left)
        #expect(h.model.handleKey(KeyChord(string: "ctrl+m")!, context: .table))
    }

    @Test func previewSeesHiddenNames() async throws {
        let h = try await FileHarness(files: ["a.txt", ".hidden"])
        defer { h.tmp.remove() }

        let request = try await request(h)
        var options = MultiRenameOptions()
        options.nameMask = ".hidden"
        options.extMask = ""
        let preview = MultiRename.preview(request.items, folderName: "left", existing: request.existing, options: options)

        #expect(preview[0].problem == .exists)
    }

    @Test func f2WithSeveralMarkedOpensMultiRename() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }

        h.model.perform(.rename)
        #expect(h.harness.effects.renames.count == 1)
        markAll(h)
        h.model.perform(.rename)
        await h.model.waitUntilIdle()

        #expect(h.harness.effects.renames.count == 1)
        #expect(h.harness.effects.multiRenameRequests.count == 1)
    }

    @Test func applyRenamesAndReloads() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        markAll(h)
        let request = try await request(h)

        let error = await h.model.applyMultiRename(rows(request, mask: "[N]_x"), in: request)
        await h.model.waitUntilIdle()

        #expect(error == nil)
        #expect(h.names(.left) == ["a_x.txt", "b_x.txt"])
        #expect(h.model.tab(.left).marked.isEmpty)
        #expect(h.model.tab(.left).cursor == "a_x.txt")
        #expect(h.model.canUndoMultiRename)
        #expect(h.model.isEnabled(.undoMultiRename, context: .table))
    }

    @Test func undoRestoresNames() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        markAll(h)
        let request = try await request(h)
        _ = await h.model.applyMultiRename(rows(request, mask: "[N]_x"), in: request)

        let message = await h.model.undoMultiRename()
        await h.model.waitUntilIdle()

        #expect(message == nil)
        #expect(h.names(.left) == ["a.txt", "b.txt"])
        #expect(!h.model.canUndoMultiRename)
    }

    @Test func undoSkipsMissing() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        markAll(h)
        let request = try await request(h)
        _ = await h.model.applyMultiRename(rows(request, mask: "[N]_x"), in: request)
        try FileManager.default.removeItem(at: h.left.appendingPathComponent("b_x.txt"))

        let message = await h.model.undoMultiRename()
        await h.model.waitUntilIdle()

        #expect(message == "1 item could not be restored.")
        #expect(h.exists("left/a.txt"))
    }

    @Test func applyWithProblemsIsRefused() async throws {
        let h = try await FileHarness()
        defer { h.tmp.remove() }
        markAll(h)
        let request = try await request(h)

        let error = await h.model.applyMultiRename(rows(request, mask: "same"), in: request)

        #expect(error != nil)
        #expect(h.exists("left/a.txt") && h.exists("left/b.txt"))
    }
}
