import Foundation

struct TempDir {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommanderKitTests-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func file(_ name: String, bytes: Int = 0) throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: bytes).write(to: fileURL)
        return fileURL
    }

    @discardableResult
    func dir(_ name: String) throws -> URL {
        let dirURL = url.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
