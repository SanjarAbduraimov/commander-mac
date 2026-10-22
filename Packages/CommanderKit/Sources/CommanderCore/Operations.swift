import Foundation

public struct OperationProgress: Equatable, Sendable {
    public var totalFiles: Int
    public var completedFiles: Int
    public var totalBytes: Int64
    public var completedBytes: Int64
    public var currentName: String?

    public init(totalFiles: Int = 0, completedFiles: Int = 0, totalBytes: Int64 = 0, completedBytes: Int64 = 0, currentName: String? = nil) {
        self.totalFiles = totalFiles
        self.completedFiles = completedFiles
        self.totalBytes = totalBytes
        self.completedBytes = completedBytes
        self.currentName = currentName
    }
}

public struct Conflict: Sendable {
    public let source: URL
    public let existing: URL

    public init(source: URL, existing: URL) {
        self.source = source
        self.existing = existing
    }
}

public enum ConflictDecision: Sendable {
    case replace, skip, keepBoth
}

public struct ConflictResolution: Sendable {
    public let decision: ConflictDecision
    public let applyToAll: Bool

    public init(decision: ConflictDecision, applyToAll: Bool = false) {
        self.decision = decision
        self.applyToAll = applyToAll
    }
}

public struct OperationFailure: Error, Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case permissionDenied, fileBusy, diskFull, destinationInsideSource
        case other(String)
    }

    public let url: URL
    public let reason: Reason

    public init(url: URL, reason: Reason) {
        self.url = url
        self.reason = reason
    }
}

public enum ErrorDecision: Sendable {
    case retry, skip, cancelAll
}

public enum OperationOutcome: Equatable, Sendable {
    case completed, cancelled
}

public protocol OperationDelegate: Sendable {
    func progress(_ progress: OperationProgress)
    func resolve(_ conflict: Conflict) async -> ConflictResolution
    func decide(_ failure: OperationFailure) async -> ErrorDecision
}

public enum OperationKind: Sendable {
    case copy, move, trash, delete
}

public enum OperationStatus: Equatable, Sendable {
    case running, waitingForUser, completed, cancelled
}

public struct OperationState: Identifiable, Sendable {
    public let id: UUID
    public let kind: OperationKind
    public var progress: OperationProgress
    public var status: OperationStatus

    public init(id: UUID = UUID(), kind: OperationKind, progress: OperationProgress = .init(), status: OperationStatus = .running) {
        self.id = id
        self.kind = kind
        self.progress = progress
        self.status = status
    }
}
