import CommanderCore
import Foundation
import Testing
@testable import CommanderController

struct PaneTextTests {
    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    @Test func statusTexts() {
        var tab = TabState(path: root)
        tab.apply(listing: [item("a", size: 1_000), item("b", size: 2_000), item("c", size: 3_000)])
        #expect(PaneText.status(tab) == "3 items · \(bytes(6_000))")

        tab.toggleMark(name: "b")
        #expect(PaneText.status(tab) == "3 items · 1 marked · \(bytes(2_000))")

        var empty = TabState(path: root)
        empty.apply(listing: [])
        #expect(PaneText.status(empty) == "0 items · \(bytes(0))")

        var single = TabState(path: root)
        single.apply(listing: [item("x", size: 5)])
        #expect(PaneText.status(single) == "1 item · \(bytes(5))")
    }

    @Test func foldersCountAsZeroBytes() {
        var tab = TabState(path: root)
        tab.apply(listing: [item("dir", .directory), item("x", size: 5)])
        #expect(PaneText.status(tab) == "2 items · \(bytes(5))")
    }
}
