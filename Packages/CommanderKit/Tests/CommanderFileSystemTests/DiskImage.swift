import Foundation

/// A throwaway APFS volume, so tests can exercise cross-volume moves and ejecting.
struct DiskImage {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    let mountPoint: URL
    private let imageURL: URL

    init(sizeMB: Int = 300) throws {
        let volumeName = "CKTest-\(UUID().uuidString.prefix(8))"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CKImages-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        imageURL = folder.appendingPathComponent("\(volumeName).sparseimage")
        try Self.hdiutil([
            "create", "-size", "\(sizeMB)m", "-type", "SPARSE", "-fs", "APFS", "-volname", volumeName,
            imageURL.deletingPathExtension().path,
        ])
        mountPoint = URL(fileURLWithPath: "/Volumes/\(volumeName)", isDirectory: true)
        // Attached separately: only attach accepts -nobrowse, which keeps the test volume out of Finder.
        try Self.hdiutil(["attach", "-nobrowse", "-mountpoint", mountPoint.path, imageURL.path])
    }

    func detach() {
        try? Self.hdiutil(["detach", "-force", mountPoint.path])
        try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent())
    }

    private static func hdiutil(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw Failure(description: "hdiutil \(arguments.first ?? "") failed: \(text)")
        }
    }
}
