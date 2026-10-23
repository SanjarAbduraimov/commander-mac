import CommanderCore
import CommanderFileSystem
import Foundation

@MainActor
public final class WindowModel {
    public private(set) var state: WindowState
    public private(set) var settings: AppSettings
    public private(set) var bindings: KeyBindings
    public let operations: OperationCenter
    public let sidebar: SidebarModel
    public var onSessionChange: ((Session) -> Void)?
    public var onSettingsChange: ((AppSettings) -> Void)?

    let environment: WindowEnvironment
    let effects: any WindowEffects
    let pasteboard: any FilePasteboard
    /// Window-level session fields (sidebar width, favorites, recent servers) that `state` does not hold.
    var session: Session

    private struct Watch {
        let path: URL
        let token: UUID
        let watcher: any DirectoryWatching
    }

    private enum ListingOutcome: Sendable {
        case items([FileItem])
        case missing(nearest: URL)
        case failed(ListingError)
    }

    private var generations: [PaneSide: Int] = [:]
    private var banners: [PaneSide: PaneBanner] = [:]
    private var versions: [PaneSide: Int] = [:]
    private var watches: [PaneSide: Watch] = [:]
    private var pending: [UUID: Task<Void, Never>] = [:]
    private var loadTasks: [PaneSide: Task<Void, Never>] = [:]
    private var lastPublishedSession: Session?
    var pageSizes: [PaneSide: Int] = [:]
    var typeAheadInput = TypeAhead()
    /// A name the cursor should land on once the folder's next listing arrives (a file opened by path, a new folder).
    var pendingCursor: [PaneSide: String] = [:]
    var folderSizesBySide: [PaneSide: [String: Int64]] = [:]
    var sizeRun: SizeRun?

    public init(
        state: WindowState, settings: AppSettings, session: Session, environment: WindowEnvironment,
        effects: any WindowEffects, pasteboard: any FilePasteboard, operations: OperationCenter
    ) {
        self.state = state
        self.settings = settings
        self.session = session
        self.environment = environment
        self.effects = effects
        self.pasteboard = pasteboard
        self.operations = operations
        sidebar = SidebarModel(favorites: session.favorites, volumes: environment.volumes, executor: environment.listingExecutor)
        bindings = KeyBindings(defaults: KeyBindings.defaults(for: settings.behavior), overrides: settings.shortcutOverrides)

        operations.onChange = { [weak self] in self?.effects.stateDidChange(.operations) }
        operations.onFinish = { [weak self] directories in self?.reloadPanes(showingAnyOf: directories) }
        sidebar.onChange = { [weak self] in
            self?.effects.stateDidChange(.sidebar)
            self?.publishSession()
        }
    }

    public func start() {
        for side in [PaneSide.left, .right] {
            load(side)
            updateWatch(side)
        }
        track { await self.sidebar.refreshVolumes() }
    }

    public func tab(_ side: PaneSide) -> TabState {
        state[side].activeTab
    }

    public func banner(_ side: PaneSide) -> PaneBanner? {
        banners[side]
    }

    public func listingVersion(_ side: PaneSide) -> Int {
        versions[side, default: 0]
    }

    /// `showHiddenByDefault` only affects tabs opened from now on.
    public func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        bindings = KeyBindings(defaults: KeyBindings.defaults(for: settings.behavior), overrides: settings.shortcutOverrides)
        effects.stateDidChange(.settings)
        effects.stateDidChange(.window)
        onSettingsChange?(settings)
    }

    public func reload(_ side: PaneSide) {
        load(side)
    }

    public func activate(_ side: PaneSide) {
        guard state.activeSide != side else { return }
        state.activeSide = side
        effects.stateDidChange(.window)
        publishSession()
        if environment.isNetworkPath(tab(side).path) { reload(side) }
    }

    public func appDidBecomeActive() {
        for side in [PaneSide.left, .right] where environment.isNetworkPath(tab(side).path) {
            reload(side)
        }
    }

    public func sessionSnapshot() -> Session {
        var snapshot = session
        snapshot.left = PaneSession(tabPaths: state.left.tabs.map(\.path), activeTab: state.left.activeTabIndex)
        snapshot.right = PaneSession(tabPaths: state.right.tabs.map(\.path), activeTab: state.right.activeTabIndex)
        snapshot.activeSide = state.activeSide
        snapshot.favorites = sidebar.favorites
        return snapshot
    }

    public func waitUntilIdle() async {
        repeat {
            while let task = pending.values.first { await task.value }
            await operations.waitUntilIdle()
        } while !pending.isEmpty || !operations.isIdle
    }

    // MARK: - Internal building blocks for commands

    func mutateTab(_ side: PaneSide, _ body: (inout TabState) -> Void) {
        body(&state[side].activeTab)
        changed(side)
    }

    func mutatePane(_ side: PaneSide, _ body: (inout PaneState) -> Void) {
        let previousPath = tab(side).path
        let previousIndex = state[side].activeTabIndex
        body(&state[side])
        if previousIndex != state[side].activeTabIndex || !samePath(previousPath, tab(side).path) {
            locationChanged(side)
        } else {
            changed(side)
        }
    }

    func navigate(_ side: PaneSide, to url: URL) {
        state[side].activeTab.navigate(to: url)
        locationChanged(side)
    }

    /// The active tab now shows a different folder (navigation, tab switch): list it and watch it.
    func locationChanged(_ side: PaneSide) {
        banners[side] = nil
        pendingCursor[side] = nil
        clearSizes(side)
        load(side)
        updateWatch(side)
        changed(side)
    }

    func changed(_ side: PaneSide) {
        effects.stateDidChange(.pane(side))
        publishSession()
    }

    func publishSession() {
        let snapshot = sessionSnapshot()
        guard snapshot != lastPublishedSession else { return }
        lastPublishedSession = snapshot
        onSessionChange?(snapshot)
    }

    /// Keeps `waitUntilIdle` aware of work started from synchronous command handlers.
    @discardableResult
    func track(_ body: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let id = UUID()
        let task = Task {
            await body()
            self.pending[id] = nil
        }
        pending[id] = task
        return task
    }

    /// Re-lists the folder and returns once the latest listing of that pane is applied; a watcher reload that
    /// starts meanwhile supersedes this one, so it is awaited too.
    func reloadAndWait(_ side: PaneSide) async {
        var task = load(side)
        await task.value
        while let latest = loadTasks[side], latest != task {
            task = latest
            await task.value
        }
    }

    // MARK: - Loading and watching

    @discardableResult
    private func load(_ side: PaneSide) -> Task<Void, Never> {
        generations[side, default: 0] += 1
        let generation = generations[side]!
        let path = tab(side).path
        let lister = environment.lister
        let executor = environment.listingExecutor
        let task = track {
            let outcome = (try? await executor.run { () -> ListingOutcome in
                do {
                    return .items(try lister.list(path))
                } catch let error as ListingError {
                    switch error {
                    case .notFound, .notADirectory: return .missing(nearest: lister.nearestExistingDirectory(from: path))
                    default: return .failed(error)
                    }
                }
            }) ?? .failed(.other("Reading the folder was interrupted."))
            // A slow listing (an SMB folder the user already left) must not overwrite the current one.
            guard self.generations[side] == generation, samePath(self.tab(side).path, path) else { return }
            self.apply(outcome, to: side, path: path)
        }
        loadTasks[side] = task
        return task
    }

    private func apply(_ outcome: ListingOutcome, to side: PaneSide, path: URL) {
        switch outcome {
        case let .items(items):
            banners[side] = nil
            show(items, on: side)
        case let .missing(nearest) where !samePath(nearest, path):
            navigate(side, to: nearest)
        case .missing:
            banners[side] = .unreadable("The folder no longer exists.")
            show([], on: side)
        case .failed(.permissionDenied):
            banners[side] = .noAccess
            show([], on: side)
        case let .failed(.other(message)):
            banners[side] = .unreadable(message)
            show([], on: side)
        case .failed:
            banners[side] = .unreadable("The folder can't be read.")
            show([], on: side)
        }
    }

    private func show(_ items: [FileItem], on side: PaneSide) {
        state[side].activeTab.apply(listing: items)
        if let name = pendingCursor.removeValue(forKey: side) { state[side].activeTab.setCursor(name: name) }
        versions[side, default: 0] += 1
        changed(side)
    }

    private func updateWatch(_ side: PaneSide) {
        let path = tab(side).path
        if let current = watches[side], samePath(current.path, path) { return }
        watches[side]?.watcher.stop()
        let token = UUID()
        let watcher = environment.makeWatcher(path) { [weak self] in
            Task { @MainActor in self?.watcherFired(side, token: token) }
        }
        watches[side] = Watch(path: path, token: token, watcher: watcher)
        watcher.start()
    }

    /// FSEvents can deliver one more callback after `stop()`; only the current watcher's token reloads.
    private func watcherFired(_ side: PaneSide, token: UUID) {
        guard watches[side]?.token == token else { return }
        reload(side)
    }

    private func reloadPanes(showingAnyOf directories: [URL]) {
        for side in [PaneSide.left, .right] where directories.contains(where: { samePath($0, tab(side).path) }) {
            reload(side)
        }
    }
}
