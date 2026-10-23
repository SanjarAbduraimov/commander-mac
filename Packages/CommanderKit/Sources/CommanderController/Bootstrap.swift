import CommanderCore
import Foundation

/// Launch arguments the UI tests use to run against throwaway folders and settings.
public struct LaunchOptions: Equatable, Sendable {
    public var settingsDirectory: URL?
    public var leftPath: URL?
    public var rightPath: URL?

    public init(arguments: [String]) {
        func value(after flag: String) -> URL? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        settingsDirectory = value(after: "-CKSettingsDirectory")
        leftPath = value(after: "-CKLeftPath")
        rightPath = value(after: "-CKRightPath")
    }
}

public struct BootstrapResult: Sendable {
    public let settings: AppSettings
    public let session: Session
    public let state: WindowState
    public let store: SettingsStore
    public let warnings: [AlertMessage]
}

public enum AppBootstrap {
    public static func load(_ options: LaunchOptions, lister: any DirectoryListing) -> BootstrapResult {
        let store = SettingsStore(directory: options.settingsDirectory ?? SettingsStore.defaultDirectory)
        let settings = store.loadSettings()
        let session = store.loadSession()
        let warnings = [settings.corruptFileBackup, session.corruptFileBackup].compactMap { backup in
            backup.map { AlertMessage(title: "Settings were reset", detail: "The damaged file was saved as \($0.path).") }
        }

        var state = WindowState.restored(from: session.value, behavior: settings.value.behavior, lister: lister)
        let showHidden = settings.value.behavior.showHiddenByDefault
        if let left = options.leftPath { state.left = PaneState(tabs: [TabState(path: left, showHidden: showHidden)]) }
        if let right = options.rightPath { state.right = PaneState(tabs: [TabState(path: right, showHidden: showHidden)]) }

        return BootstrapResult(settings: settings.value, session: session.value, state: state, store: store, warnings: warnings)
    }
}
