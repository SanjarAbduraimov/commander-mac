import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct SizeTests {
    private func harness() async throws -> FileHarness {
        let h = try await FileHarness(files: ["dir/", "a.txt"])
        try h.tmp.file("left/dir/1", bytes: 3)
        try h.tmp.file("left/dir/2", bytes: 3)
        return h
    }

    private func dir(_ h: FileHarness) -> FileItem {
        h.model.tab(.left).items.first { $0.name == "dir" }!
    }

    @Test func calculateSizeFillsFolderSize() async throws {
        let h = try await harness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.setCursor(name: "dir") }

        h.model.perform(.calculateSize)
        await h.model.waitUntilIdle()

        #expect(h.model.folderSize(.left, dir(h)) == 6)
        #expect(h.model.sizeProgress == nil)
    }

    @Test func statusIncludesCalculatedFolders() async throws {
        let h = try await harness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.toggleMark(name: "dir") }

        h.model.perform(.calculateSize)
        await h.model.waitUntilIdle()

        let status = PaneText.status(h.model.tab(.left), folderSizes: h.model.folderSizes(.left))
        #expect(status == "2 items · 1 marked · \(ByteCountFormatter.string(fromByteCount: 6, countStyle: .file))")
    }

    @Test func progressText() {
        #expect(SizeText.progress(SizeProgress(done: 2, total: 5)) == "Calculating size… 2 of 5 folders")
    }

    @Test func navigatingAwayCancelsAndClearsSizes() async throws {
        let h = try await harness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.setCursor(name: "dir") }
        h.model.perform(.calculateSize)
        await h.model.waitUntilIdle()

        h.model.perform(.open)
        await h.model.waitUntilIdle()
        h.model.perform(.goUp)
        await h.model.waitUntilIdle()
        #expect(h.model.folderSize(.left, dir(h)) == nil)

        h.model.mutateTab(.left) { $0.setCursor(name: "dir") }
        h.model.perform(.calculateSize)
        #expect(h.model.sizeProgress == SizeProgress(done: 0, total: 1))
        h.model.perform(.open)
        #expect(h.model.sizeProgress == nil)
        await h.model.waitUntilIdle()
        h.model.perform(.goUp)
        await h.model.waitUntilIdle()
        #expect(h.model.folderSize(.left, dir(h)) == nil)
    }

    @Test func reloadClearsSizes() async throws {
        let h = try await harness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.setCursor(name: "dir") }
        h.model.perform(.calculateSize)
        await h.model.waitUntilIdle()

        h.model.perform(.reload)
        await h.model.waitUntilIdle()

        #expect(h.model.folderSize(.left, dir(h)) == nil)
    }

    @Test func calculateSizeOnFileOnlyBeeps() async throws {
        let h = try await harness()
        defer { h.tmp.remove() }
        h.model.mutateTab(.left) { $0.setCursor(name: "a.txt") }

        h.model.perform(.calculateSize)
        await h.model.waitUntilIdle()

        #expect(h.harness.effects.beeps == 1)
        #expect(h.model.sizeProgress == nil)
    }
}
