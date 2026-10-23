import CommanderCore
import Foundation
import Testing
@testable import CommanderController

struct DropPolicyTests {
    private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    private func operation(_ sources: [String], _ destination: String, forceCopy: Bool = false, sameVolume: Bool = true) -> DropOperation {
        DropPolicy.operation(sources: sources.map(url), destination: url(destination), forceCopy: forceCopy) { _, _ in sameVolume }
    }

    @Test func sameVolumeMoves_otherVolumeCopies_optionCopies() {
        #expect(operation(["/x/f"], "/y") == .move)
        #expect(operation(["/x/f"], "/y", sameVolume: false) == .copy)
        #expect(operation(["/x/f"], "/y", forceCopy: true) == .copy)
    }

    @Test func dropIntoSelfOrOwnFolderIsNone() {
        #expect(operation(["/a"], "/a/sub") == .none)
        #expect(operation(["/a"], "/a") == .none)
        #expect(operation(["/x/f"], "/x") == .none)
        #expect(operation(["/x/f"], "/x/", forceCopy: true) == .none)
        #expect(operation([], "/y") == .none)
        #expect(operation(["/ab"], "/a/b") == .move)
        #expect(operation(["/x/f", "/z/g"], "/x") == .move)
    }

    @Test @MainActor func dropOntoFolderRowTargetsThatFolder() async throws {
        let h = try await FileHarness(files: ["sub/", "a.txt"])
        defer { h.tmp.remove() }
        let outside = try h.tmp.file("outside/f.txt", bytes: 1)

        #expect(h.model.dropOperation([outside], on: .left, intoFolder: "sub", forceCopy: true) == .copy)
        #expect(h.model.drop([outside], on: .left, intoFolder: "sub", forceCopy: true))
        await h.model.waitUntilIdle()
        #expect(h.exists("left/sub/f.txt"))

        #expect(h.model.drop([outside], on: .left, intoFolder: "a.txt", forceCopy: true))
        await h.model.waitUntilIdle()
        #expect(h.exists("left/f.txt"))

        let own = h.left.appendingPathComponent("a.txt")
        #expect(!h.model.drop([own], on: .left, intoFolder: nil, forceCopy: false))
    }
}
