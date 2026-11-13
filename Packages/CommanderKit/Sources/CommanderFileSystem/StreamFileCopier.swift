import Foundation
import CommanderCore

public final class StreamFileCopier: Sendable {
    public let bufferSize: Int
    private let volumeResolver: VolumeResolver

    public init(bufferSize: Int = 2 * 1024 * 1024, volumeResolver: VolumeResolver = VolumeResolver()) {
        self.bufferSize = max(4096, bufferSize)
        self.volumeResolver = volumeResolver
    }

    public typealias ProgressHandler = @Sendable (_ bytesTransferred: Int64, _ totalBytes: Int64, _ bytesPerSecond: Double) -> Void

    public func copyFile(
        from source: URL,
        to destination: URL,
        resume: Bool = false,
        onProgress: ProgressHandler? = nil
    ) async throws {
        try Task.checkCancellation()

        let srcPath = source.standardizedFileURL.path
        let dstPath = destination.standardizedFileURL.path

        let srcAttrs = try FileManager.default.attributesOfItem(atPath: srcPath)
        let totalBytes = (srcAttrs[.size] as? NSNumber)?.int64Value ?? 0

        // 1. Try APFS clone if on same volume, not resuming, and destination doesn't exist yet
        if !resume && volumeResolver.isSameVolume(source, destination) && !FileManager.default.fileExists(atPath: dstPath) {
            if clonefile(srcPath, dstPath, 0) == 0 {
                // Instantly cloned
                onProgress?(totalBytes, totalBytes, 0)
                return
            }
        }

        // 2. Stream copying with chunked buffer
        var bytesCopied: Int64 = 0
        var sourceOffset: UInt64 = 0

        if resume && FileManager.default.fileExists(atPath: dstPath) {
            let dstAttrs = try? FileManager.default.attributesOfItem(atPath: dstPath)
            let existingBytes = (dstAttrs?[.size] as? NSNumber)?.int64Value ?? 0
            if existingBytes >= totalBytes {
                onProgress?(totalBytes, totalBytes, 0)
                return
            }
            bytesCopied = existingBytes
            sourceOffset = UInt64(existingBytes)
        } else {
            // Remove existing if any (non-resume overwrite)
            if FileManager.default.fileExists(atPath: dstPath) {
                try? FileManager.default.removeItem(atPath: dstPath)
            }
            FileManager.default.createFile(atPath: dstPath, contents: nil, attributes: nil)
        }

        guard let srcHandle = FileHandle(forReadingAtPath: srcPath) else {
            throw POSIXError(.ENOENT)
        }
        defer { try? srcHandle.close() }

        guard let dstHandle = FileHandle(forUpdatingAtPath: dstPath) else {
            throw POSIXError(.EACCES)
        }
        defer { try? dstHandle.close() }

        if sourceOffset > 0 {
            try srcHandle.seek(toOffset: sourceOffset)
            try dstHandle.seekToEnd()
        }

        let startTime = Date()
        var lastReportTime = startTime

        onProgress?(bytesCopied, totalBytes, 0)

        while bytesCopied < totalBytes {
            try Task.checkCancellation()

            let chunkSize = min(bufferSize, Int(totalBytes - bytesCopied))
            let chunk = srcHandle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }

            dstHandle.write(chunk)
            bytesCopied += Int64(chunk.count)

            let now = Date()
            let intervalSinceLastReport = now.timeIntervalSince(lastReportTime)
            if intervalSinceLastReport >= 0.1 || bytesCopied >= totalBytes {
                let totalElapsed = max(0.001, now.timeIntervalSince(startTime))
                let speed = Double(bytesCopied - Int64(sourceOffset)) / totalElapsed
                onProgress?(bytesCopied, totalBytes, speed)
                lastReportTime = now
            }
        }

        // Preserve attributes: modification date and permissions
        var updatedAttrs: [FileAttributeKey: Any] = [:]
        if let modDate = srcAttrs[.modificationDate] {
            updatedAttrs[.modificationDate] = modDate
        }
        if let perms = srcAttrs[.posixPermissions] {
            updatedAttrs[.posixPermissions] = perms
        }
        if !updatedAttrs.isEmpty {
            try? FileManager.default.setAttributes(updatedAttrs, ofItemAtPath: dstPath)
        }
    }

    public func copyItem(
        from source: URL,
        to destination: URL,
        resume: Bool = false,
        onProgress: ProgressHandler? = nil
    ) async throws {
        try Task.checkCancellation()

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir) else {
            throw POSIXError(.ENOENT)
        }

        if isDir.boolValue {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let contents = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            for child in contents {
                try Task.checkCancellation()
                let targetChild = destination.appendingPathComponent(child.lastPathComponent)
                try await copyItem(from: child, to: targetChild, resume: resume, onProgress: onProgress)
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: source.path) {
                var dirAttrs: [FileAttributeKey: Any] = [:]
                if let modDate = attrs[.modificationDate] { dirAttrs[.modificationDate] = modDate }
                if let perms = attrs[.posixPermissions] { dirAttrs[.posixPermissions] = perms }
                try? FileManager.default.setAttributes(dirAttrs, ofItemAtPath: destination.path)
            }
        } else {
            try await copyFile(from: source, to: destination, resume: resume, onProgress: onProgress)
        }
    }
}
