import Foundation
import Testing
@testable import CommanderCore

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

struct SettingsCodingTests {
    @Test func emptyObjectDecodesToDefaults() throws {
        #expect(try decode(AppSettings.self, "{}") == AppSettings())
        #expect(try decode(Session.self, "{}") == Session())
    }

    @Test func partialObjectKeepsGivenValues() throws {
        let settings = try decode(AppSettings.self, #"{"appearance":{"fontSize":15},"behavior":{"spaceAdvances":false}}"#)
        #expect(settings.appearance.fontSize == 15)
        #expect(settings.appearance.rowHeight == AppearanceSettings().rowHeight)
        #expect(settings.behavior.spaceAdvances == false)
        #expect(settings.behavior.forwardDeleteTrashes == true)
    }

    @Test func unknownKeysIgnored() throws {
        let settings = try decode(AppSettings.self, #"{"futureFeature":true,"appearance":{"glow":3}}"#)
        #expect(settings == AppSettings())
    }

    @Test func overridesEncodeAsCommandNameToStrings() throws {
        var settings = AppSettings()
        settings.shortcutOverrides = [.newTab: [KeyChord("n", [.command])]]
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
        let overrides = object?["shortcutOverrides"] as? [String: [String]]
        #expect(overrides == ["newTab": ["cmd+n"]])
    }

    @Test func unknownCommandInOverridesIsDropped() throws {
        let settings = try decode(AppSettings.self, #"{"shortcutOverrides":{"removedCmd":["cmd+q"],"reload":["cmd+e"]}}"#)
        #expect(settings.shortcutOverrides == [.reload: [KeyChord("e", [.command])]])
    }

    @Test func newerFileKeepsEverythingStillReadable() throws {
        // A later build may add a theme; that one unknown value must not wipe the font size or shortcuts.
        let settings = try decode(AppSettings.self, #"{"version":2,"appearance":{"theme":"sepia","fontSize":17},"shortcutOverrides":{"newTab":["cmd+n"]}}"#)
        #expect(settings.appearance.theme == .system)
        #expect(settings.appearance.fontSize == 17)
        #expect(settings.shortcutOverrides == [.newTab: [KeyChord("n", [.command])]])
    }

    @Test func paneSessionMissingActiveTabKeepsTabs() throws {
        let session = try decode(Session.self, #"{"left":{"tabPaths":["file:///tmp/"]}}"#)
        #expect(session.left.tabPaths.map(\.path) == ["/tmp"])
        #expect(session.left.activeTab == 0)
    }

    @Test func emptyTabPathsFallBackToHome() throws {
        let session = try decode(Session.self, #"{"left":{"tabPaths":[],"activeTab":0}}"#)
        #expect(session.left == Session().left)
    }

    @Test func recentServersCappedAtTenNewestFirst() {
        var session = Session()
        for i in 1...12 { session.addRecentServer("smb://host\(i)/share") }
        #expect(session.recentServers.count == 10)
        #expect(session.recentServers.first == "smb://host12/share")
        session.addRecentServer("smb://host5/share")
        #expect(session.recentServers.first == "smb://host5/share")
        #expect(session.recentServers.filter { $0 == "smb://host5/share" }.count == 1)
    }
}
