import Foundation

public enum TransferKind: String, Codable, Sendable {
    case copy
    case move
}

public struct TransferProgress: Equatable, Sendable {
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public let filesTransferred: Int
    public let totalFiles: Int
    public let currentFileName: String
    public let bytesPerSecond: Double
    public let estimatedSecondsRemaining: Double?

    public init(
        bytesTransferred: Int64,
        totalBytes: Int64,
        filesTransferred: Int,
        totalFiles: Int,
        currentFileName: String,
        bytesPerSecond: Double,
        estimatedSecondsRemaining: Double?
    ) {
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.filesTransferred = filesTransferred
        self.totalFiles = totalFiles
        self.currentFileName = currentFileName
        self.bytesPerSecond = bytesPerSecond
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
    }

    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesTransferred) / Double(totalBytes)))
    }

    public var formattedSpeed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        let formatted = formatter.string(fromByteCount: Int64(bytesPerSecond))
        return "\(formatted)/s"
    }

    public var formattedETA: String {
        guard let remaining = estimatedSecondsRemaining, remaining.isFinite, remaining >= 0 else {
            return "--:--"
        }
        let totalSeconds = Int(remaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

public enum JobState: Equatable, Sendable {
    case queued
    case running(TransferProgress)
    case paused(TransferProgress)
    case resolvingConflict(ConflictDetails)
    case completed
    case failed(String)
    case cancelled
}

public struct TransferJob: Identifiable, Sendable {
    public let id: UUID
    public let kind: TransferKind
    public let sources: [URL]
    public let destinationDirectory: URL
    public let sourceVolumeIdentifier: String?
    public let targetVolumeIdentifier: String?
    public var state: JobState
    public var conflictAction: ConflictAction?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: TransferKind,
        sources: [URL],
        destinationDirectory: URL,
        sourceVolumeIdentifier: String? = nil,
        targetVolumeIdentifier: String? = nil,
        state: JobState = .queued,
        conflictAction: ConflictAction? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.sources = sources
        self.destinationDirectory = destinationDirectory
        self.sourceVolumeIdentifier = sourceVolumeIdentifier
        self.targetVolumeIdentifier = targetVolumeIdentifier
        self.state = state
        self.conflictAction = conflictAction
        self.createdAt = createdAt
    }

    public var isSameVolume: Bool {
        guard let src = sourceVolumeIdentifier, let dst = targetVolumeIdentifier else {
            return true
        }
        return src == dst
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    public var isTerminal: Bool {
        switch state {
        case .completed, .failed, .cancelled:
            return true
        case .queued, .running, .paused, .resolvingConflict:
            return false
        }
    }
}
