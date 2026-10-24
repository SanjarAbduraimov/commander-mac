import Foundation

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
    /// Used when `restoreTabsOnLaunch` is off; nil opens Home.
    public var launchLeftFolder: URL? = nil
    public var launchRightFolder: URL? = nil

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BehaviorSettings()
        backspaceAction = c.value(.backspaceAction, default: d.backspaceAction)
        spaceAdvances = c.value(.spaceAdvances, default: d.spaceAdvances)
        askDestinationForCopyMove = c.value(.askDestinationForCopyMove, default: d.askDestinationForCopyMove)
        forwardDeleteTrashes = c.value(.forwardDeleteTrashes, default: d.forwardDeleteTrashes)
        showHiddenByDefault = c.value(.showHiddenByDefault, default: d.showHiddenByDefault)
        restoreTabsOnLaunch = c.value(.restoreTabsOnLaunch, default: d.restoreTabsOnLaunch)
        launchLeftFolder = c.value(.launchLeftFolder, default: URL?.none)
        launchRightFolder = c.value(.launchRightFolder, default: URL?.none)
    }
}

/// Table columns besides Name, which is always shown first.
public enum ColumnID: String, Codable, CaseIterable, Sendable {
    case ext, size, modified, created, kind
}

public struct ColumnSetting: Codable, Equatable, Sendable {
    public var id: ColumnID
    public var width: Double

    public init(id: ColumnID, width: Double) {
        self.id = id
        self.width = width
    }
}

public struct AppearanceSettings: Codable, Equatable, Sendable {
    public static let defaultColumnWidths: [ColumnID: Double] = [.ext: 60, .size: 72, .modified: 135, .created: 135, .kind: 120]

    public var theme: Theme = .system
    public var fontName: String? = nil
    public var fontSize: Double = 13
    public var iconSize: Double = 16
    public var rowHeight: Double = 22
    public var columns: [ColumnSetting] = [.ext, .size, .modified].map {
        ColumnSetting(id: $0, width: AppearanceSettings.defaultColumnWidths[$0]!)
    }

    public init() {}

    /// Read entry by entry: unknown or repeated columns (and "name", which is not configurable) are dropped.
    private struct StoredColumn: Decodable {
        let id: String
        let width: Double?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppearanceSettings()
        theme = c.value(.theme, default: d.theme)
        fontName = (try? c.decodeIfPresent(String.self, forKey: .fontName)) ?? nil
        fontSize = c.value(.fontSize, default: d.fontSize)
        iconSize = c.value(.iconSize, default: d.iconSize)
        rowHeight = c.value(.rowHeight, default: d.rowHeight)
        if let stored = c.value(.columns, default: [StoredColumn]?.none) {
            var seen = Set<ColumnID>()
            columns = stored.compactMap { entry in
                guard let id = ColumnID(rawValue: entry.id), seen.insert(id).inserted else { return nil }
                return ColumnSetting(id: id, width: entry.width ?? Self.defaultColumnWidths[id]!)
            }
        }
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
        version = c.value(.version, default: Self.currentVersion)
        appearance = c.value(.appearance, default: AppearanceSettings())
        behavior = c.value(.behavior, default: BehaviorSettings())
        // Stored by command name so overrides for commands removed in a later version are dropped, not fatal.
        let raw = c.value(.shortcutOverrides, default: [String: [String]]())
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
    /// Field-level leniency: a missing or unreadable value (say, an enum case from a newer build)
    /// falls back to its default instead of failing the whole file.
    func value<T: Decodable>(_ key: Key, default defaultValue: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? defaultValue
    }
}
