import CommanderCore
import CommanderFileSystem
import Foundation
import Synchronization
@testable import CommanderController

/// Answers prompts from queues given up front (skip / delete when a queue runs dry), records every call
/// and the most prompts that were open at once. In `held` mode a conflict waits until the test answers it.
@MainActor
final class FakePrompts: OperationPrompts {
    var conflictAnswers: [ConflictResolution] = []
    var errorAnswers: [ErrorDecision] = []
    var deleteAnswer = true
    var held = false
    var delay: Duration = .zero

    private(set) var conflicts: [Conflict] = []
    private(set) var failures: [OperationFailure] = []
    private(set) var deleteRequests: [[URL]] = []
    private(set) var maxConcurrent = 0
    private var active = 0
    private var heldConflict: CheckedContinuation<ConflictResolution, Never>?

    var isHoldingConflict: Bool { heldConflict != nil }

    func answerHeldConflict(_ resolution: ConflictResolution) {
        heldConflict?.resume(returning: resolution)
        heldConflict = nil
    }

    func resolve(_ conflict: Conflict) async -> ConflictResolution {
        conflicts.append(conflict)
        return await tracked {
            if held { return await withCheckedContinuation { heldConflict = $0 } }
            return conflictAnswers.isEmpty ? ConflictResolution(decision: .skip) : conflictAnswers.removeFirst()
        }
    }

    func decide(_ failure: OperationFailure) async -> ErrorDecision {
        failures.append(failure)
        return await tracked { errorAnswers.isEmpty ? .skip : errorAnswers.removeFirst() }
    }

    func confirmPermanentDelete(_ urls: [URL]) async -> Bool {
        deleteRequests.append(urls)
        return await tracked { deleteAnswer }
    }

    private func tracked<T>(_ body: () async -> T) async -> T {
        active += 1
        maxConcurrent = max(maxConcurrent, active)
        if delay > .zero { try? await Task.sleep(for: delay) }
        let result = await body()
        active -= 1
        return result
    }
}

/// Never touches the real Trash: records what it was asked to trash and on which thread.
final class FakeTrasher: Trasher {
    private let unsupported: Set<URL>
    private let log = Mutex<(trashed: [URL], onMain: [Bool])>(([], []))

    init(unsupported: Set<URL> = []) {
        self.unsupported = unsupported
    }

    func trash(_ url: URL) throws {
        log.withLock { $0.onMain.append(Thread.isMainThread) }
        if unsupported.contains(url) { throw TrashUnsupportedError() }
        log.withLock { $0.trashed.append(url) }
    }

    var trashed: [URL] { log.withLock { $0.trashed } }
    var calledOnMainThread: [Bool] { log.withLock { $0.onMain } }
}

@MainActor
final class RecordingEffects: WindowEffects {
    var destinationAnswer: URL?
    var deleteAnswer = false
    private(set) var deleteRequests: [[URL]] = []
    private(set) var multiRenameRequests: [MultiRenameRequest] = []
    var patternAnswer: String?
    private(set) var patternRequests: [PatternRequest] = []
    private(set) var changes: [StateChange] = []
    private(set) var focusedPathFields: [PaneSide] = []
    private(set) var renames: [(side: PaneSide, name: String)] = []
    var opened: [URL] { openedWithApp.map(\.url) }
    private(set) var openedWithApp: [(url: URL, appURL: URL?)] = []
    private(set) var openWithAppPrompts: [[URL]] = []
    private(set) var quickLooks: [[URL]] = []
    private(set) var newFilePrompts: [PaneSide] = []
    private(set) var pasteImages: [PaneSide] = []
    private(set) var revealed: [[URL]] = []
    private(set) var terminals: [URL] = []
    private(set) var settingsShown = 0
    private(set) var connectShown = 0
    private(set) var destinationRequests: [DestinationRequest] = []
    private(set) var alerts: [AlertMessage] = []
    private(set) var beeps = 0

    func stateDidChange(_ change: StateChange) { changes.append(change) }
    func focusPathField(_ side: PaneSide) { focusedPathFields.append(side) }
    func beginRename(_ side: PaneSide, name: String) { renames.append((side, name)) }
    func open(_ url: URL, withApp appURL: URL?) { openedWithApp.append((url, appURL)) }
    func openWithAppPrompt(_ urls: [URL]) { openWithAppPrompts.append(urls) }
    func quickLook(_ urls: [URL]) { quickLooks.append(urls) }
    func showNewFilePrompt(_ side: PaneSide) { newFilePrompts.append(side) }
    func pasteImage(_ side: PaneSide) { pasteImages.append(side) }
    func revealInFinder(_ urls: [URL]) { revealed.append(urls) }
    func openInTerminal(_ directory: URL) { terminals.append(directory) }
    func showSettings() { settingsShown += 1 }
    func showConnectToServer() { connectShown += 1 }
    func chooseDestination(_ request: DestinationRequest) async -> URL? {
        destinationRequests.append(request)
        return destinationAnswer
    }
    func showMultiRename(_ request: MultiRenameRequest) { multiRenameRequests.append(request) }
    func askPattern(_ request: PatternRequest) async -> String? {
        patternRequests.append(request)
        return patternAnswer
    }
    func confirmDeleteImmediately(_ urls: [URL]) async -> Bool {
        deleteRequests.append(urls)
        return deleteAnswer
    }
    func showAlert(_ alert: AlertMessage) { alerts.append(alert) }
    func beep() { beeps += 1 }
}

@MainActor
final class FakePasteboard: FilePasteboard {
    private(set) var files: (urls: [URL], isCut: Bool)?
    private(set) var strings: [String] = []

    func writeFiles(_ urls: [URL], cut: Bool) { files = (urls, cut) }
    func writeString(_ string: String) { strings.append(string) }
    func readFiles() -> (urls: [URL], isCut: Bool)? { files }
    func clearCut() { files = files.map { ($0.urls, false) } }
}

/// Serves listings from a table keyed by path; unknown paths are "not found". Records every call.
final class FakeLister: DirectoryListing {
    private let state: Mutex<(listings: [String: Result<[FileItem], ListingError>], calls: [String])>

    init(_ listings: [String: [FileItem]] = [:]) {
        state = Mutex((listings.mapValues { .success($0) }, []))
    }

    func set(_ path: String, _ items: [FileItem]) {
        state.withLock { $0.listings[path] = .success(items) }
    }

    func fail(_ path: String, _ error: ListingError) {
        state.withLock { $0.listings[path] = .failure(error) }
    }

    var calls: [String] { state.withLock { $0.calls } }

    func list(_ directory: URL) throws(ListingError) -> [FileItem] {
        let path = directory.standardizedFileURL.path
        let result = state.withLock { s in
            s.calls.append(path)
            return s.listings[path] ?? .failure(.notFound)
        }
        return try result.get()
    }

    func nearestExistingDirectory(from url: URL) -> URL {
        var candidate = url.standardizedFileURL
        while candidate.path != "/" {
            let known = state.withLock { s in
                if case .success = s.listings[candidate.path] { return true }
                return false
            }
            if known { return candidate }
            candidate = candidate.deletingLastPathComponent().standardizedFileURL
        }
        return candidate
    }
}

/// A FakeLister whose listing of chosen paths blocks until the test opens the gate.
final class GatedLister: DirectoryListing {
    let inner: FakeLister
    private let gatedPaths: Set<String>
    private let gate = DispatchSemaphore(value: 0)

    init(_ inner: FakeLister, gating paths: Set<String>) {
        self.inner = inner
        gatedPaths = paths
    }

    func open() { gate.signal() }

    func list(_ directory: URL) throws(ListingError) -> [FileItem] {
        if gatedPaths.contains(directory.standardizedFileURL.path) { gate.wait() }
        return try inner.list(directory)
    }

    func nearestExistingDirectory(from url: URL) -> URL {
        inner.nearestExistingDirectory(from: url)
    }
}

final class FakeWatcher: DirectoryWatching {
    let path: URL
    private let onChange: @Sendable () -> Void
    private let flags = Mutex<(started: Bool, stopped: Bool)>((false, false))

    init(path: URL, onChange: @escaping @Sendable () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() { flags.withLock { $0.started = true } }
    func stop() { flags.withLock { $0.stopped = true } }
    /// Delivers a change even after `stop()`, like a late FSEvents callback.
    func fire() { onChange() }

    var isStarted: Bool { flags.withLock { $0.started } }
    var isStopped: Bool { flags.withLock { $0.stopped } }
}

final class FakeWatcherFactory: Sendable {
    private let made = Mutex<[FakeWatcher]>([])

    var watchers: [FakeWatcher] { made.withLock { $0 } }
    var active: [FakeWatcher] { watchers.filter { $0.isStarted && !$0.isStopped } }

    func make(_ path: URL, _ onChange: @escaping @Sendable () -> Void) -> any DirectoryWatching {
        let watcher = FakeWatcher(path: path, onChange: onChange)
        made.withLock { $0.append(watcher) }
        return watcher
    }
}

struct FakeMounter: ServerMounting {
    let result: @Sendable (URL) throws -> URL

    func mount(_ url: URL) async throws -> URL {
        try result(url)
    }
}

/// A test clock the model reads through `WindowEnvironment.now`.
final class FakeClock: Sendable {
    private let instant = Mutex(ContinuousClock.now)

    var now: ContinuousClock.Instant { instant.withLock { $0 } }
    func advance(by duration: Duration) { instant.withLock { $0 += duration } }
}

extension WindowEnvironment {
    static func test(
        lister: any DirectoryListing = FakeLister(),
        watchers: FakeWatcherFactory = FakeWatcherFactory(),
        isNetworkPath: @escaping @Sendable (URL) -> Bool = { _ in false },
        sameVolume: @escaping @Sendable (URL, URL) -> Bool = { _, _ in true },
        volumes: @escaping @Sendable () -> [VolumeInfo] = { [] },
        ejectVolume: @escaping @Sendable (URL) async throws -> Void = { _ in },
        mounter: any ServerMounting = FakeMounter { $0 },
        clock: FakeClock = FakeClock()
    ) -> WindowEnvironment {
        WindowEnvironment(
            lister: lister,
            makeWatcher: { watchers.make($0, $1) },
            listingExecutor: OperationExecutor(label: "test.listing"),
            isNetworkPath: isNetworkPath,
            sameVolume: sameVolume,
            volumes: volumes,
            ejectVolume: ejectVolume,
            mounter: mounter,
            now: { clock.now }
        )
    }
}

/// A WindowModel with recording fakes around it.
@MainActor
struct Harness {
    let model: WindowModel
    let effects: RecordingEffects
    let pasteboard: FakePasteboard
    let prompts: FakePrompts
    let trasher: FakeTrasher

    init(
        left: [URL] = [URL(fileURLWithPath: "/root")],
        right: [URL] = [URL(fileURLWithPath: "/root")],
        settings: AppSettings = AppSettings(),
        session: Session = Session(),
        environment: WindowEnvironment = .test(),
        trasher: FakeTrasher = FakeTrasher()
    ) {
        effects = RecordingEffects()
        pasteboard = FakePasteboard()
        prompts = FakePrompts()
        self.trasher = trasher
        let tabs = { (paths: [URL]) in
            PaneState(tabs: paths.map { TabState(path: $0, showHidden: settings.behavior.showHiddenByDefault) })
        }
        model = WindowModel(
            state: WindowState(left: tabs(left), right: tabs(right)),
            settings: settings,
            session: session,
            environment: environment,
            effects: effects,
            pasteboard: pasteboard,
            operations: OperationCenter(prompts: prompts, trasher: trasher)
        )
    }
}

let root = URL(fileURLWithPath: "/root")

func rootLister() -> FakeLister {
    FakeLister([
        "/root": [item("a", .directory), item("b.txt"), item("c.txt")],
        "/root/a": [item("inner.txt", in: root.appendingPathComponent("a"))],
    ])
}
