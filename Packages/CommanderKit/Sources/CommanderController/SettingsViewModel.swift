import CommanderCore
import Observation

public struct PendingConflict: Equatable, Sendable {
    public let chord: KeyChord
    public let command: Command
    public let owners: [Command]
    public let message: String
}

@MainActor @Observable
public final class SettingsViewModel {
    public var appearance: AppearanceSettings {
        didSet { publish() }
    }

    public var behavior: BehaviorSettings {
        didSet {
            editor.setBehavior(behavior)
            refreshRows()
            publish()
        }
    }

    public var clipboard: ClipboardSettings {
        didSet { publish() }
    }

    public var fileAssociations: [String: String] {
        didSet { publish() }
    }

    public var shortcutQuery = "" {
        didSet { refreshRows() }
    }

    public private(set) var rows: [ShortcutRow] = []
    public private(set) var recording: Command?
    public private(set) var pendingConflict: PendingConflict?

    @ObservationIgnored private var editor: ShortcutEditor
    @ObservationIgnored private var settings: AppSettings
    @ObservationIgnored private let onChange: (AppSettings) -> Void

    public init(settings: AppSettings, onChange: @escaping (AppSettings) -> Void) {
        self.settings = settings
        self.onChange = onChange
        appearance = settings.appearance
        behavior = settings.behavior
        clipboard = settings.clipboard
        fileAssociations = settings.fileAssociations
        editor = ShortcutEditor(behavior: settings.behavior, overrides: settings.shortcutOverrides)
        rows = editor.rows(matching: "")
    }

    public func startRecording(_ command: Command) {
        recording = command
        pendingConflict = nil
    }

    public func record(_ chord: KeyChord) {
        guard let command = recording else { return }
        let owners = editor.conflicts(assigning: chord, to: command)
        guard owners.isEmpty else {
            let names = owners.map(\.title).joined(separator: ", ")
            pendingConflict = PendingConflict(chord: chord, command: command, owners: owners, message: "\(chord.displayString) is already used by \(names).")
            return
        }
        assign(chord, to: command)
    }

    public func cancelRecording() {
        recording = nil
        pendingConflict = nil
    }

    public func confirmPendingAssignment() {
        guard let conflict = pendingConflict else { return }
        assign(conflict.chord, to: conflict.command)
    }

    public func cancelPendingAssignment() {
        cancelRecording()
    }

    public func restoreShortcutDefaults() {
        editor.restoreAllDefaults()
        refreshRows()
        publish()
    }

    public func setFileAssociation(extension ext: String, appPath: String) {
        settings.setApp(appPath, forExtension: ext)
        fileAssociations = settings.fileAssociations
        publish()
    }

    public func removeFileAssociation(extension ext: String) {
        settings.removeApp(forExtension: ext)
        fileAssociations = settings.fileAssociations
        publish()
    }

    private func assign(_ chord: KeyChord, to command: Command) {
        editor.assign(chord, to: command)
        recording = nil
        pendingConflict = nil
        refreshRows()
        publish()
    }

    private func refreshRows() {
        rows = editor.rows(matching: shortcutQuery)
    }

    private func publish() {
        settings.appearance = appearance
        settings.behavior = behavior
        settings.clipboard = clipboard
        settings.fileAssociations = fileAssociations
        settings.shortcutOverrides = editor.overrides
        onChange(settings)
    }
}
