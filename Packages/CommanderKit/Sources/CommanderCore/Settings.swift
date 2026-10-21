public enum BackspaceAction: String, Codable, Sendable {
    case parent, historyBack
}

public struct BehaviorSettings: Codable, Equatable, Sendable {
    public var backspaceAction: BackspaceAction = .parent
    public var spaceAdvances = true
    public var askDestinationForCopyMove = false
    public var forwardDeleteTrashes = true
    public var showHiddenByDefault = false
    public var restoreTabsOnLaunch = true

    public init() {}
}
