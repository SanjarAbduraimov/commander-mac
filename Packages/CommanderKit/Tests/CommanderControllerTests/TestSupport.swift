import CommanderCore
import Foundation

struct TempDir {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommanderControllerTests-\(UUID().uuidString)", isDirectory: true)
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

@MainActor
func eventually(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

func item(_ name: String, _ kind: FileItem.Kind = .file, size: Int64? = 0, in dir: URL = URL(fileURLWithPath: "/root")) -> FileItem {
    let isDirectory = kind != .file
    return FileItem(
        name: name,
        url: dir.appendingPathComponent(name, isDirectory: isDirectory),
        kind: kind,
        size: kind == .file ? size : nil,
        modified: Date(timeIntervalSince1970: 0),
        isHidden: name.hasPrefix(".")
    )
}
