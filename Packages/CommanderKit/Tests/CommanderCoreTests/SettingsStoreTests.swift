import Foundation
import Testing
@testable import CommanderCore

private func makeDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CommanderSettingsTests-\(UUID().uuidString)", isDirectory: true)
}

private func contents(of directory: URL) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
}

struct SettingsStoreTests {
    @Test func missingFilesGiveDefaultsWithoutBackup() {
        let store = SettingsStore(directory: makeDirectory())
        let settings = store.loadSettings()
        let session = store.loadSession()
        #expect(settings.value == AppSettings())
        #expect(settings.corruptFileBackup == nil)
        #expect(session.value == Session())
        #expect(session.corruptFileBackup == nil)
    }

    @Test func saveThenLoadRoundTrip() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)

        var settings = AppSettings()
        settings.appearance.theme = .dark
        settings.behavior.backspaceAction = .historyBack
        settings.shortcutOverrides = [.reload: [KeyChord("e", [.command])]]
        var session = Session()
        session.left = PaneSession(tabPaths: [URL(fileURLWithPath: "/tmp"), URL(fileURLWithPath: "/usr")], activeTab: 1)
        session.activeSide = .right
        session.addRecentServer("smb://nas/media")

        try store.save(settings)
        try store.save(session)
        #expect(store.loadSettings().value == settings)
        #expect(store.loadSession().value == session)
    }

    @Test func saveCreatesDirectory() throws {
        let directory = makeDirectory().appendingPathComponent("nested", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        try SettingsStore(directory: directory).save(AppSettings())
        #expect(contents(of: directory) == ["settings.json"])
    }

    @Test func corruptFileIsBackedUpAndDefaultsReturned() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: directory.appendingPathComponent("settings.json"))

        let result = SettingsStore(directory: directory).loadSettings()
        #expect(result.value == AppSettings())
        let backup = try #require(result.corruptFileBackup)
        #expect(backup.lastPathComponent.hasPrefix("settings.broken-"))
        #expect(backup.pathExtension == "json")
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{not json")
        #expect(!contents(of: directory).contains("settings.json"))
    }

    @Test func migrationStepsRunInOrder() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"version":0,"appearance":{"fontSize":10}}"#.utf8).write(to: directory.appendingPathComponent("settings.json"))

        let store = SettingsStore(directory: directory, settingsMigrations: [
            0: { object in
                var appearance = object["appearance"] as? [String: Any] ?? [:]
                appearance["fontSize"] = (appearance["fontSize"] as? Double ?? 0) * 2
                object["appearance"] = appearance
            },
        ])
        let result = store.loadSettings()
        #expect(result.corruptFileBackup == nil)
        #expect(result.value.appearance.fontSize == 20)
        #expect(result.value.version == AppSettings.currentVersion)
    }
}
