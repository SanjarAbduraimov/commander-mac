import CommanderCore
import CommanderFileSystem
import Foundation

public protocol DirectoryListing: Sendable {
    func list(_ directory: URL) throws(ListingError) -> [FileItem]
    func nearestExistingDirectory(from url: URL) -> URL
}

extension DirectoryReader: DirectoryListing {}

public protocol DirectoryWatching: AnyObject, Sendable {
    func start()
    func stop()
}

extension DirectoryWatcher: DirectoryWatching {}

public protocol ServerMounting: Sendable {
    /// Throws `CancellationError` when the user dismisses the macOS login dialog.
    func mount(_ url: URL) async throws -> URL
}

@MainActor
public protocol FilePasteboard: AnyObject {
    func writeFiles(_ urls: [URL], cut: Bool)
    func writeString(_ string: String)
    func readFiles() -> (urls: [URL], isCut: Bool)?
    func clearCut()
}

public enum PaneBanner: Equatable, Sendable {
    case noAccess
    case unreadable(String)
}

public struct AlertMessage: Equatable, Sendable {
    public let title: String
    public let detail: String?

    public init(title: String, detail: String?) {
        self.title = title
        self.detail = detail
    }
}

public enum StateChange: Equatable, Sendable {
    case pane(PaneSide), window, sidebar, operations, settings
}

@MainActor
public protocol WindowEffects: AnyObject {
    func stateDidChange(_ change: StateChange)
    func focusPathField(_ side: PaneSide)
    func beginRename(_ side: PaneSide, name: String)
    func open(_ url: URL)
    func revealInFinder(_ urls: [URL])
    func openInTerminal(_ directory: URL)
    func showSettings()
    func showConnectToServer()
    func chooseDestination(_ request: DestinationRequest) async -> URL?
    func confirmDeleteImmediately(_ urls: [URL]) async -> Bool
    func showAlert(_ alert: AlertMessage)
    func beep()
}

public struct WindowEnvironment: Sendable {
    public var lister: any DirectoryListing
    public var makeWatcher: @Sendable (URL, @escaping @Sendable () -> Void) -> any DirectoryWatching
    public var listingExecutor: OperationExecutor
    public var isNetworkPath: @Sendable (URL) -> Bool
    public var sameVolume: @Sendable (URL, URL) -> Bool
    public var volumes: @Sendable () -> [VolumeInfo]
    public var ejectVolume: @Sendable (URL) async throws -> Void
    public var mounter: any ServerMounting
    public var now: @Sendable () -> ContinuousClock.Instant

    public init(
        lister: any DirectoryListing,
        makeWatcher: @escaping @Sendable (URL, @escaping @Sendable () -> Void) -> any DirectoryWatching,
        listingExecutor: OperationExecutor,
        isNetworkPath: @escaping @Sendable (URL) -> Bool,
        sameVolume: @escaping @Sendable (URL, URL) -> Bool,
        volumes: @escaping @Sendable () -> [VolumeInfo],
        ejectVolume: @escaping @Sendable (URL) async throws -> Void,
        mounter: any ServerMounting,
        now: @escaping @Sendable () -> ContinuousClock.Instant
    ) {
        self.lister = lister
        self.makeWatcher = makeWatcher
        self.listingExecutor = listingExecutor
        self.isNetworkPath = isNetworkPath
        self.sameVolume = sameVolume
        self.volumes = volumes
        self.ejectVolume = ejectVolume
        self.mounter = mounter
        self.now = now
    }

    public static func live(mounter: any ServerMounting) -> WindowEnvironment {
        WindowEnvironment(
            lister: DirectoryReader(),
            makeWatcher: { DirectoryWatcher(directory: $0, onChange: $1) },
            listingExecutor: .listing,
            isNetworkPath: { url in
                (try? url.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal) == false
            },
            sameVolume: { a, b in
                let key: Set<URLResourceKey> = [.volumeIdentifierKey]
                guard let first = try? a.resourceValues(forKeys: key).volumeIdentifier,
                      let second = try? b.resourceValues(forKeys: key).volumeIdentifier
                else { return false }
                return first.isEqual(second)
            },
            volumes: { Volumes.mounted() },
            ejectVolume: { try await Volumes.eject($0) },
            mounter: mounter,
            now: { .now }
        )
    }
}

extension WindowState {
    public static func restored(from session: Session, behavior: BehaviorSettings, lister: any DirectoryListing) -> WindowState {
        func tab(_ url: URL) -> TabState { TabState(path: url, showHidden: behavior.showHiddenByDefault) }

        guard behavior.restoreTabsOnLaunch else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            func launch(_ folder: URL?) -> PaneState {
                PaneState(tabs: [tab(folder.map(lister.nearestExistingDirectory(from:)) ?? home)])
            }
            return WindowState(left: launch(behavior.launchLeftFolder), right: launch(behavior.launchRightFolder))
        }
        func pane(_ saved: PaneSession) -> PaneState {
            PaneState(tabs: saved.tabPaths.map { tab(lister.nearestExistingDirectory(from: $0)) }, activeTabIndex: saved.activeTab)
        }
        return WindowState(left: pane(session.left), right: pane(session.right), activeSide: session.singlePane ? .left : session.activeSide)
    }

    subscript(side: PaneSide) -> PaneState {
        get { side == .left ? left : right }
        set { if side == .left { left = newValue } else { right = newValue } }
    }
}

func samePath(_ a: URL, _ b: URL) -> Bool {
    a.standardizedFileURL.path == b.standardizedFileURL.path
}
