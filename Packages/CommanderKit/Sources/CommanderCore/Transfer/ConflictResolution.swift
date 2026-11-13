import Foundation

public struct ConflictDetails: Equatable, Sendable {
    public let sourceURL: URL
    public let targetURL: URL
    public let sourceSize: Int64
    public let targetSize: Int64
    public let sourceModified: Date
    public let targetModified: Date

    public init(
        sourceURL: URL,
        targetURL: URL,
        sourceSize: Int64,
        targetSize: Int64,
        sourceModified: Date,
        targetModified: Date
    ) {
        self.sourceURL = sourceURL
        self.targetURL = targetURL
        self.sourceSize = sourceSize
        self.targetSize = targetSize
        self.sourceModified = sourceModified
        self.targetModified = targetModified
    }

    public var isSourceNewer: Bool {
        sourceModified > targetModified
    }

    public var hasSizeDifference: Bool {
        sourceSize != targetSize
    }
}

public enum ConflictAction: String, Codable, Sendable {
    case overwrite
    case overwriteAll
    case overwriteIfOlder
    case overwriteIfSizeDiffers
    case skip
    case skipAll
    case autoRename
    case resume
    case cancel
}
