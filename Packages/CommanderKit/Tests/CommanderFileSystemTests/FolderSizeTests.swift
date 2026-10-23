import Foundation
import Testing
@testable import CommanderFileSystem

struct FolderSizeTests {
    @Test func measuresNestedFilesWithoutFollowingSymlinks() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file("a/1", bytes: 3)
        try tmp.file("a/b/2", bytes: 5)
        try FileManager.default.createSymbolicLink(
            at: tmp.url.appendingPathComponent("a/link"), withDestinationURL: URL(fileURLWithPath: "/usr"))

        let result = FolderSize.measure(tmp.url.appendingPathComponent("a")) { false }

        #expect(result?.files == 3)
        #expect(result?.bytes == 8)
    }

    @Test func cancelledMeasurementReturnsNil() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try tmp.file("a/1", bytes: 3)

        #expect(FolderSize.measure(tmp.url.appendingPathComponent("a")) { true } == nil)
    }
}
