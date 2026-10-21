import Foundation

public struct PaneSession: Codable, Equatable, Sendable {
    public var tabPaths: [URL]
    public var activeTab: Int

    public init(tabPaths: [URL], activeTab: Int = 0) {
        self.tabPaths = tabPaths
        self.activeTab = activeTab
    }
}

public struct Session: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    static let recentServerLimit = 10

    public var version = currentVersion
    public var left: PaneSession
    public var right: PaneSession
    public var activeSide: PaneSide = .left
    public var sidebarWidth: Double = 200
    public var favorites: [URL]
    public var recentServers: [String] = []

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
        version = try c.value(.version, default: Self.currentVersion)
        left = try c.value(.left, default: d.left)
        right = try c.value(.right, default: d.right)
        activeSide = try c.value(.activeSide, default: d.activeSide)
        sidebarWidth = try c.value(.sidebarWidth, default: d.sidebarWidth)
        favorites = try c.value(.favorites, default: d.favorites)
        recentServers = try c.value(.recentServers, default: d.recentServers)
    }

    public mutating func addRecentServer(_ address: String) {
        recentServers.removeAll { $0 == address }
        recentServers.insert(address, at: 0)
        recentServers = Array(recentServers.prefix(Self.recentServerLimit))
    }
}
