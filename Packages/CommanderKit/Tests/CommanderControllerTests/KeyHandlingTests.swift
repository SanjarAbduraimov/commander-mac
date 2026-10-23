import CommanderCore
import Foundation
import Testing
@testable import CommanderController

/// /root: folder "a", "b.txt", "c.txt" and 27 more files — 30 items.
func thirtyItemLister() -> FakeLister {
    let files = (1...27).map { item(String(format: "d%02d.txt", $0)) }
    return FakeLister([
        "/root": [item("a", .directory), item("b.txt"), item("c.txt")] + files,
        "/root/a": [item("inner.txt", in: root.appendingPathComponent("a"))],
    ])
}

@MainActor
func startedHarness(
    _ lister: FakeLister = thirtyItemLister(), left: [URL] = [root], settings: AppSettings = AppSettings(),
    clock: FakeClock = FakeClock(), watchers: FakeWatcherFactory = FakeWatcherFactory()
) async -> Harness {
    let harness = Harness(left: left, settings: settings, environment: .test(lister: lister, watchers: watchers, clock: clock))
    harness.model.start()
    await harness.model.waitUntilIdle()
    return harness
}

@MainActor
struct KeyHandlingTests {
    private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

    @Test func arrowMovesCursorAndReturnsTrue() async {
        let model = await startedHarness().model

        #expect(model.handleKey(chord("down"), context: .table))
        #expect(model.tab(.left).cursor == "b.txt")
    }

    @Test func unknownChordReturnsFalse() async {
        let model = await startedHarness().model

        #expect(!model.handleKey(chord("cmd+j"), context: .table))
    }

    @Test func fileCommandsAreDisabledInTextField() async {
        let model = await startedHarness().model
        model.mutateTab(.left) { $0.setCursor(name: "b.txt") }

        for key in ["backspace", "space", "cmd+backspace", "cmd+d"] {
            #expect(!model.handleKey(chord(key), context: .textField))
        }
        #expect(model.tab(.left).path == root)
        #expect(model.tab(.left).cursor == "b.txt")
        #expect(model.tab(.left).marked.isEmpty)
        #expect(!model.isEnabled(.duplicate, context: .textField))
    }

    @Test func whitelistedCommandWorksInTextField() async {
        let model = await startedHarness().model

        #expect(model.handleKey(chord("cmd+t"), context: .textField))
        #expect(model.state.left.tabs.count == 2)
    }

    @Test func pageDownUsesPageSize() async {
        let model = await startedHarness().model
        model.setPageSize(.left, rows: 10)

        model.perform(.pageDown)

        #expect(model.tab(.left).cursorIndex == 9)
    }

    @Test func typeAheadJumpsAndResets() async {
        let clock = FakeClock()
        let model = await startedHarness(clock: clock).model

        model.typeAhead("b")
        #expect(model.tab(.left).cursor == "b.txt")

        clock.advance(by: .milliseconds(1_100))
        model.typeAhead("c")
        #expect(model.tab(.left).cursor == "c.txt")
    }
}
