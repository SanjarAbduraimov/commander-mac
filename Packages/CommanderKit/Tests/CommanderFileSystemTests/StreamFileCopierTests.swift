import Foundation
import Testing
@testable import CommanderCore
@testable import CommanderFileSystem

private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _reportedBytes: [Int64] = []

    func append(_ bytes: Int64) {
        lock.lock()
        defer { lock.unlock() }
        _reportedBytes.append(bytes)
    }

    var reportedBytes: [Int64] {
        lock.lock()
        defer { lock.unlock() }
        return _reportedBytes
    }

    var lastReported: Int64? {
        lock.lock()
        defer { lock.unlock() }
        return _reportedBytes.last
    }
}

struct StreamFileCopierTests {
    @Test func copiesSingleFileWithProgress() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let srcURL = tempDir.appendingPathComponent("source.bin")
        let dstURL = tempDir.appendingPathComponent("dest.bin")

        // 1 MB test payload
        let payload = Data((0..<1_048_576).map { UInt8($0 % 255) })
        try payload.write(to: srcURL)

        let box = ProgressBox()
        let copier = StreamFileCopier(bufferSize: 65536) // 64 KB chunk for test granularity

        try await copier.copyFile(
            from: srcURL,
            to: dstURL,
            resume: false,
            onProgress: { bytesTransferred, totalBytes, speed in
                box.append(bytesTransferred)
            }
        )

        let dstData = try Data(contentsOf: dstURL)
        #expect(dstData == payload)
        #expect(box.lastReported == 1_048_576)
    }

    @Test func resumeInterruptedCopyAppendsCorrectly() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let srcURL = tempDir.appendingPathComponent("source.bin")
        let dstURL = tempDir.appendingPathComponent("dest.bin")

        // Full 500 KB payload
        let fullPayload = Data((0..<500_000).map { UInt8($0 % 251) })
        try fullPayload.write(to: srcURL)

        // Write partial (first 200 KB) to destination
        let partialPayload = fullPayload.prefix(200_000)
        try partialPayload.write(to: dstURL)

        let copier = StreamFileCopier(bufferSize: 32768)
        let box = ProgressBox()

        try await copier.copyFile(
            from: srcURL,
            to: dstURL,
            resume: true,
            onProgress: { bytesTransferred, totalBytes, speed in
                box.append(bytesTransferred)
            }
        )

        let dstData = try Data(contentsOf: dstURL)
        #expect(dstData == fullPayload)
        #expect(box.lastReported == 500_000)
    }

    @Test func recursiveDirectoryCopyWithDatesAndPermissions() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let srcDir = tempDir.appendingPathComponent("srcFolder")
        let subDir = srcDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let file1 = srcDir.appendingPathComponent("1.txt")
        let file2 = subDir.appendingPathComponent("2.txt")
        try "file1-data".write(to: file1, atomically: true, encoding: .utf8)
        try "file2-data".write(to: file2, atomically: true, encoding: .utf8)

        let pastDate = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.modificationDate: pastDate], ofItemAtPath: file1.path)

        let dstDir = tempDir.appendingPathComponent("dstFolder")

        let copier = StreamFileCopier()
        try await copier.copyItem(from: srcDir, to: dstDir)

        let copiedFile1 = dstDir.appendingPathComponent("1.txt")
        let copiedFile2 = dstDir.appendingPathComponent("sub/2.txt")

        #expect(FileManager.default.fileExists(atPath: copiedFile1.path))
        #expect(FileManager.default.fileExists(atPath: copiedFile2.path))

        let attrs = try FileManager.default.attributesOfItem(atPath: copiedFile1.path)
        if let modDate = attrs[.modificationDate] as? Date {
            #expect(abs(modDate.timeIntervalSince(pastDate)) < 2.0)
        }
    }
}
