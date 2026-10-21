import Synchronization
import Testing
@testable import CommanderCore

private final class Recorder: Sendable {
    private let values = Mutex<[Int]>([])
    func append(_ value: Int) { values.withLock { $0.append(value) } }
    var all: [Int] { values.withLock { $0 } }
}

struct DebouncedWriterTests {
    @Test func burstRunsOnce() async throws {
        let writer = DebouncedWriter(interval: .milliseconds(50))
        let recorder = Recorder()
        for i in 1...3 {
            await writer.schedule { recorder.append(i) }
        }
        try await Task.sleep(for: .milliseconds(250))
        #expect(recorder.all == [3])
    }

    @Test func flushRunsPendingImmediately() async {
        let writer = DebouncedWriter(interval: .seconds(10))
        let recorder = Recorder()
        await writer.schedule { recorder.append(1) }
        await writer.flush()
        #expect(recorder.all == [1])
        await writer.flush()
        #expect(recorder.all == [1])
    }
}
