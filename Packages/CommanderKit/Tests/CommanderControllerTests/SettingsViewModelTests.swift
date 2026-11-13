import CommanderCore
import Testing
@testable import CommanderController

@MainActor
struct SettingsViewModelTests {
    private func chord(_ string: String) -> KeyChord { KeyChord(string: string)! }

    @Test func appearanceChangeCallsOnChangeImmediately() {
        var published: [AppSettings] = []
        let model = SettingsViewModel(settings: AppSettings()) { published.append($0) }

        model.appearance.rowHeight = 30
        model.behavior.spaceAdvances = false

        #expect(published.map(\.appearance.rowHeight) == [30, 30])
        #expect(published.last?.behavior.spaceAdvances == false)
    }

    @Test func recordWithoutConflictAssigns() {
        var published: [AppSettings] = []
        let model = SettingsViewModel(settings: AppSettings()) { published.append($0) }

        model.startRecording(.reload)
        #expect(model.recording == .reload)
        model.record(chord("cmd+j"))

        #expect(model.recording == nil)
        #expect(published.last?.shortcutOverrides[.reload] == [chord("cmd+j")])
        #expect(model.rows.first { $0.command == .reload }?.chords == [chord("cmd+j")])
    }

    @Test func recordWithConflictWaitsForConfirmation() {
        var published: [AppSettings] = []
        let model = SettingsViewModel(settings: AppSettings()) { published.append($0) }

        model.startRecording(.newTab)
        model.record(chord("cmd+d"))
        #expect(model.pendingConflict?.message == "⌘D is already used by Duplicate.")
        #expect(published.isEmpty)

        model.cancelPendingAssignment()
        #expect(model.pendingConflict == nil)
        #expect(published.isEmpty)

        model.startRecording(.newTab)
        model.record(chord("cmd+d"))
        model.confirmPendingAssignment()
        #expect(published.last?.shortcutOverrides[.newTab] == [chord("cmd+d")])
        #expect(model.pendingConflict == nil && model.recording == nil)
    }

    @Test func restoreShortcutDefaultsClearsOverrides() {
        var settings = AppSettings()
        settings.shortcutOverrides = [.reload: [chord("cmd+j")]]
        var published: [AppSettings] = []
        let model = SettingsViewModel(settings: settings) { published.append($0) }

        model.restoreShortcutDefaults()

        #expect(published.last?.shortcutOverrides.isEmpty == true)
        #expect(model.rows.first { $0.command == .reload }?.isCustom == false)
    }

    @Test func queryFiltersRows() {
        let model = SettingsViewModel(settings: AppSettings()) { _ in }

        model.shortcutQuery = "trash"

        #expect(model.rows.map(\.command) == [.moveToTrash])
    }

    @Test func clipboardAndFileAssociationsPublishOnChange() {
        var published: [AppSettings] = []
        let model = SettingsViewModel(settings: AppSettings()) { published.append($0) }

        model.clipboard.confirmPasteImage = false
        #expect(published.last?.clipboard.confirmPasteImage == false)

        model.setFileAssociation(extension: "png", appPath: "/Applications/Preview.app")
        #expect(published.last?.fileAssociations["png"] == "/Applications/Preview.app")

        model.removeFileAssociation(extension: "png")
        #expect(published.last?.fileAssociations["png"] == nil)
    }
}
