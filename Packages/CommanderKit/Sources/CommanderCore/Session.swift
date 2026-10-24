import Foundation

public struct PaneSession: Codable, Equatable, Sendable {
    public var tabPaths: [URL]
    public var activeTab: Int

    public init(tabPaths: [URL], activeTab: Int = 0) {
        self.tabPaths = tabPaths
        self.activeTab = activeTab
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let paths = c.value(.tabPaths, default: [URL]())
        // A pane always has a tab (PaneState traps otherwise), so an empty list would crash every launch.
        tabPaths = paths.isEmpty ? [FileManager.default.homeDirectoryForCurrentUser] : paths
        activeTab = c.value(.activeTab, default: 0)
    }
}

public struct Session: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    static let recentServerLimit = 10
    static let recentDestinationLimit = 10
    static let recentPatternLimit = 10

    public var version = currentVersion
    public var left: PaneSession
    public var right: PaneSession
    public var activeSide: PaneSide = .left
    public var sidebarWidth: Double = 200
    public var favorites: [URL]
    public var recentServers: [String] = []
    public var recentDestinations: [URL] = []
    public var singlePane = false
    public var recentPatterns: [String] = []

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        left = PaneSession(tabPaths: [home])
        right = PaneSession(tabPaths: [home])
        favorites = [
            home,
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Downloads", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true),
        ]
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Session()
        version = c.value(.version, default: Self.currentVersion)
        left = c.value(.left, default: d.left)
        right = c.value(.right, default: d.right)
        activeSide = c.value(.activeSide, default: d.activeSide)
        sidebarWidth = c.value(.sidebarWidth, default: d.sidebarWidth)
        favorites = c.value(.favorites, default: d.favorites)
        recentServers = c.value(.recentServers, default: d.recentServers)
        recentDestinations = c.value(.recentDestinations, default: d.recentDestinations)
        singlePane = c.value(.singlePane, default: d.singlePane)
        recentPatterns = c.value(.recentPatterns, default: d.recentPatterns)
    }

    public mutating func addRecentServer(_ address: String) {
        recentServers.removeAll { $0 == address }
        recentServers.insert(address, at: 0)
        recentServers = Array(recentServers.prefix(Self.recentServerLimit))
    }

    public mutating func addRecentDestination(_ url: URL) {
        let url = url.standardizedFileURL
        recentDestinations.removeAll { $0.standardizedFileURL.path == url.path }
        recentDestinations.insert(url, at: 0)
        recentDestinations = Array(recentDestinations.prefix(Self.recentDestinationLimit))
    }

    public mutating func addRecentPattern(_ text: String) {
        recentPatterns.removeAll { $0 == text }
        recentPatterns.insert(text, at: 0)
        recentPatterns = Array(recentPatterns.prefix(Self.recentPatternLimit))
    }
}
