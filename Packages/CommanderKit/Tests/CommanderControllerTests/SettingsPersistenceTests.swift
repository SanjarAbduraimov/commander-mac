import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct SettingsPersistenceTests {
    private func settings(fontSize: Double) -> AppSettings {
        var settings = AppSettings()
        settings.appearance.fontSize = fontSize
        return settings
    }

    @Test func flushWritesSynchronously() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let store = SettingsStore(directory: tmp.url)
        let persistence = SettingsPersistence(store: store, interval: .seconds(60))
        var session = Session()
        session.sidebarWidth = 321

        persistence.update(settings(fontSize: 15))
        persistence.update(session)
        persistence.flushSynchronously()

        #expect(store.loadSettings().value == settings(fontSize: 15))
        #expect(store.loadSession().value.sidebarWidth == 321)
    }

    @Test func debouncedUpdateWritesAfterInterval() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let persistence = SettingsPersistence(store: SettingsStore(directory: tmp.url), interval: .milliseconds(50))

        persistence.update(settings(fontSize: 14))

        #expect(await eventually(timeout: .seconds(1)) {
            FileManager.default.fileExists(atPath: tmp.url.appendingPathComponent("settings.json").path)
        })
    }

    @Test func latestSnapshotWins() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let store = SettingsStore(directory: tmp.url)
        let persistence = SettingsPersistence(store: store, interval: .seconds(60))

        persistence.update(settings(fontSize: 11))
        persistence.update(settings(fontSize: 17))
        persistence.flushSynchronously()

        #expect(store.loadSettings().value == settings(fontSize: 17))
    }

    @Test func flushAfterDebouncedWriteNeverRegresses() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let store = SettingsStore(directory: tmp.url)
        let persistence = SettingsPersistence(store: store, interval: .milliseconds(50))

        persistence.update(settings(fontSize: 11))
        #expect(await eventually(timeout: .seconds(1)) { store.loadSettings().value == settings(fontSize: 11) })
        persistence.update(settings(fontSize: 17))
        persistence.flushSynchronously()
        try await Task.sleep(for: .milliseconds(200))

        #expect(store.loadSettings().value == settings(fontSize: 17))
    }
}
