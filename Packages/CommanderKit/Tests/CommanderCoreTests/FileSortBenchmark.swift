import Foundation
import Testing
import CommanderCore

/// Sorting runs on the main actor for every listing; on the Intel target it must stay a small part of the
/// 100 ms folder-open budget whichever column is chosen.
struct FileSortBenchmark {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CK_BENCHMARK"] == "1"), arguments: [SortColumn.name, .ext, .kind])
    func sort5000ItemsUnder30ms(_ column: SortColumn) {
        let extensions = ["txt", "pdf", "png", "swift", "zip", "md", "json", "jpg", ""]
        let items = (0..<5_000).map { i in
            let ext = extensions[i % extensions.count]
            let name = String(format: "file-%05d", i) + (ext.isEmpty ? "" : "." + ext)
            return FileItem(name: name, url: URL(fileURLWithPath: "/tmp/" + name), kind: .file, size: 0,
                            modified: Date(timeIntervalSince1970: 0), isHidden: false)
        }
        let sort = FileSort(column: column)
        _ = sort.sorted(items)
        let clock = ContinuousClock()
        var samples: [Duration] = []
        for _ in 0..<5 { samples.append(clock.measure { _ = sort.sorted(items) }) }
        let median = samples.sorted()[samples.count / 2]
        print("FileSortBenchmark \(column) median: \(median)")
        #expect(median <= .milliseconds(30))
    }
}
