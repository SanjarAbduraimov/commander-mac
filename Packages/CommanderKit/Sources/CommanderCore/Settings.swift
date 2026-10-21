public enum BackspaceAction: String, Codable, Sendable {
    case parent, historyBack
}

public enum Theme: String, Codable, Sendable {
    case system, light, dark
}

public struct BehaviorSettings: Codable, Equatable, Sendable {
    public var backspaceAction: BackspaceAction = .parent
    public var spaceAdvances = true
    public var askDestinationForCopyMove = false
    public var forwardDeleteTrashes = true
    public var showHiddenByDefault = false
    public var restoreTabsOnLaunch = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BehaviorSettings()
        backspaceAction = try c.value(.backspaceAction, default: d.backspaceAction)
        spaceAdvances = try c.value(.spaceAdvances, default: d.spaceAdvances)
        askDestinationForCopyMove = try c.value(.askDestinationForCopyMove, default: d.askDestinationForCopyMove)
        forwardDeleteTrashes = try c.value(.forwardDeleteTrashes, default: d.forwardDeleteTrashes)
        showHiddenByDefault = try c.value(.showHiddenByDefault, default: d.showHiddenByDefault)
        restoreTabsOnLaunch = try c.value(.restoreTabsOnLaunch, default: d.restoreTabsOnLaunch)
    }
}

public struct AppearanceSettings: Codable, Equatable, Sendable {
    public var theme: Theme = .system
    public var fontName: String? = nil
    public var fontSize: Double = 13
    public var iconSize: Double = 16
    public var rowHeight: Double = 22

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppearanceSettings()
        theme = try c.value(.theme, default: d.theme)
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName)
        fontSize = try c.value(.fontSize, default: d.fontSize)
        iconSize = try c.value(.iconSize, default: d.iconSize)
        rowHeight = try c.value(.rowHeight, default: d.rowHeight)
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = currentVersion
    public var appearance = AppearanceSettings()
    public var behavior = BehaviorSettings()
    /// Only the user's changes; defaults live in `KeyBindings.defaults(for:)`.
    public var shortcutOverrides: [Command: [KeyChord]] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, appearance, behavior, shortcutOverrides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.value(.version, default: Self.currentVersion)
        appearance = try c.value(.appearance, default: AppearanceSettings())
        behavior = try c.value(.behavior, default: BehaviorSettings())
        // Stored by command name so overrides for commands removed in a later version are dropped, not fatal.
        let raw = try c.decodeIfPresent([String: [String]].self, forKey: .shortcutOverrides) ?? [:]
        shortcutOverrides = Dictionary(uniqueKeysWithValues: raw.compactMap { name, chords in
            Command(rawValue: name).map { ($0, chords.compactMap(KeyChord.init(string:))) }
        })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(appearance, forKey: .appearance)
        try c.encode(behavior, forKey: .behavior)
        let raw = Dictionary(uniqueKeysWithValues: shortcutOverrides.map { ($0.key.rawValue, $0.value.map(\.description)) })
        try c.encode(raw, forKey: .shortcutOverrides)
    }
}

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue
    }
}
