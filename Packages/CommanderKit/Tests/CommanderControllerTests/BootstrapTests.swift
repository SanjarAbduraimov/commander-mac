import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct BootstrapTests {
    @Test func parsesLaunchOptions() {
        let options = LaunchOptions(arguments: ["/App", "-CKSettingsDirectory", "/tmp/s", "-CKLeftPath", "/tmp/l", "-CKRightPath", "/tmp/r", "-NSDocumentRevisionsDebugMode", "YES"])

        #expect(options.settingsDirectory?.path == "/tmp/s")
        #expect(options.leftPath?.path == "/tmp/l")
        #expect(options.rightPath?.path == "/tmp/r")
        #expect(LaunchOptions(arguments: ["/App", "-CKLeftPath"]) == LaunchOptions(arguments: []))
    }

    @Test func launchPathsOverrideSession() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let settingsDirectory = try tmp.dir("settings")
        let (saved, forced) = (try tmp.dir("saved"), try tmp.dir("forced"))
        var session = Session()
        session.left = PaneSession(tabPaths: [saved, saved], activeTab: 1)
        session.right = PaneSession(tabPaths: [saved])
        try SettingsStore(directory: settingsDirectory).save(session)

        let result = AppBootstrap.load(
            LaunchOptions(arguments: ["-CKSettingsDirectory", settingsDirectory.path, "-CKLeftPath", forced.path]),
            lister: DirectoryReader()
        )

        #expect(result.state.left.tabs.map(\.path.path) == [forced.path])
        #expect(result.state.right.tabs.map(\.path.path) == [saved.path])
        #expect(result.warnings.isEmpty)
        #expect(result.session == session)
    }

    @Test func corruptSettingsProduceOneWarning() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        try Data("{not json".utf8).write(to: tmp.url.appendingPathComponent("settings.json"))

        let result = AppBootstrap.load(LaunchOptions(arguments: ["-CKSettingsDirectory", tmp.url.path]), lister: DirectoryReader())

        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.title == "Settings were reset")
        #expect(result.warnings.first?.detail?.contains("settings.broken-") == true)
        #expect(result.settings == AppSettings())
    }

    @Test func updateSettingsRebuildsBindings() async {
        let harness = await startedHarness()
        var published: [AppSettings] = []
        harness.model.onSettingsChange = { published.append($0) }
        var settings = AppSettings()
        settings.shortcutOverrides = [.newTab: [KeyChord(string: "cmd+n")!]]

        harness.model.updateSettings(settings)

        #expect(harness.model.handleKey(KeyChord(string: "cmd+n")!, context: .table))
        #expect(harness.model.state.left.tabs.count == 2)
        #expect(published == [settings])
        #expect(harness.effects.changes.contains(.settings))
    }
}
