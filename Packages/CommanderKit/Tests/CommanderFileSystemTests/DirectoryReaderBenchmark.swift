import Foundation
import Testing
import CommanderFileSystem

struct DirectoryReaderBenchmark {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CK_BENCHMARK"] == "1"))
    func list5000FilesUnder100ms() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        for i in 0..<5_000 { try tmp.file(String(format: "file-%05d.txt", i)) }

        let reader = DirectoryReader()
        #expect(try reader.list(tmp.url).count == 5_000)
        let clock = ContinuousClock()
        var samples: [Duration] = []
        for _ in 0..<5 {
            samples.append(clock.measure { _ = try? reader.list(tmp.url) })
        }
        let median = samples.sorted()[samples.count / 2]
        print("DirectoryReaderBenchmark median: \(median)")
        #expect(median <= .milliseconds(100))
    }
}
