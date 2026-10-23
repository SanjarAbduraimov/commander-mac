import CommanderCore
import CommanderFileSystem
import Foundation
import Testing
@testable import CommanderController

private struct MountFailure: LocalizedError {
    var errorDescription: String? { "The server can't be found." }
}

@MainActor
struct PlacesTests {
    private func harness(mounter: any ServerMounting = FakeMounter { $0 }, ejectVolume: @escaping @Sendable (URL) async throws -> Void = { _ in },
                         volumes: @escaping @Sendable () -> [VolumeInfo] = { [] }, left: URL = root) async -> Harness {
        let lister = rootLister()
        let h = Harness(left: [left], environment: .test(lister: lister, volumes: volumes, ejectVolume: ejectVolume, mounter: mounter))
        h.model.start()
        await h.model.waitUntilIdle()
        return h
    }

    @Test func openPlaceNavigatesActiveTab() async {
        let h = await harness()
        h.model.activate(.right)

        h.model.openPlace(root.appendingPathComponent("a"))
        await h.model.waitUntilIdle()

        #expect(h.model.tab(.right).path.path == "/root/a")
        #expect(h.model.tab(.left).path.path == "/root")
    }

    @Test func connectMountsOpensAndRemembers() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let mountPoint = tmp.url
        let shares = [volume("share", at: mountPoint.path)]
        let h = Harness(environment: .test(lister: DirectoryReader(), volumes: { shares }, mounter: FakeMounter { _ in mountPoint }))
        var published: [Session] = []
        h.model.onSessionChange = { published.append($0) }

        await h.model.connect(to: " nas/share ")
        await h.model.waitUntilIdle()

        #expect(h.model.tab(.left).path.standardizedFileURL.path == mountPoint.standardizedFileURL.path)
        #expect(h.model.recentServers.first == "smb://nas/share")
        #expect(published.last?.recentServers.first == "smb://nas/share")
        #expect(h.model.sidebar.volumes == shares)
        #expect(h.effects.alerts.isEmpty)
    }

    @Test func rememberedServerNeverKeepsPassword() async {
        let h = await harness(mounter: FakeMounter { _ in root })

        await h.model.connect(to: "smb://bob:secret@nas/share")

        #expect(h.model.recentServers == ["smb://bob@nas/share"])
        #expect(h.model.sessionSnapshot().recentServers.allSatisfy { !$0.contains("secret") })
    }

    @Test func connectInvalidAddressAlerts() async {
        let h = await harness()

        await h.model.connect(to: "ftp://nas/share")

        #expect(h.effects.alerts == [AlertMessage(title: "Invalid server address", detail: "Enter an address like smb://server/share.")])
        #expect(h.model.recentServers.isEmpty)
    }

    @Test func connectCancelledIsSilent() async {
        let h = await harness(mounter: FakeMounter { _ in throw CancellationError() })

        await h.model.connect(to: "smb://nas/share")

        #expect(h.effects.alerts.isEmpty)
        #expect(h.model.recentServers.isEmpty)
    }

    @Test func connectFailureAlertsWithMessage() async {
        let h = await harness(mounter: FakeMounter { _ in throw MountFailure() })

        await h.model.connect(to: "smb://nas/share")

        #expect(h.effects.alerts == [AlertMessage(title: "Couldn't connect to “nas”", detail: "The server can't be found.")])
    }

    @Test func ejectFailureAlerts() async {
        let h = await harness(ejectVolume: { _ in throw MountFailure() })

        await h.model.eject(volume("Backup", at: "/Volumes/Backup"))

        #expect(h.effects.alerts == [AlertMessage(title: "Couldn't eject “Backup”", detail: "The server can't be found.")])
    }

    @Test func ejectSuccessRefreshesAndLeavesVolume() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let disk = try tmp.dir("disk")
        try tmp.dir("disk/inner")
        let h = Harness(left: [disk.appendingPathComponent("inner")], environment: .test(
            lister: DirectoryReader(), volumes: { [] },
            ejectVolume: { try FileManager.default.removeItem(at: $0) }
        ))
        h.model.start()
        await h.model.waitUntilIdle()

        await h.model.eject(VolumeInfo(name: "disk", url: disk, totalCapacity: nil, availableCapacity: nil, isEjectable: true, isNetwork: false))
        await h.model.waitUntilIdle()

        #expect(h.model.tab(.left).path.standardizedFileURL.path == tmp.url.standardizedFileURL.path)
        #expect(h.effects.alerts.isEmpty)
    }

    @Test func sessionIncludesFavoritesWidthAndServers() async throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let folder = try tmp.dir("fav")
        var session = Session()
        session.favorites = []
        let h = Harness(session: session, environment: .test(lister: rootLister()))
        var published: [Session] = []
        h.model.onSessionChange = { published.append($0) }

        h.model.sidebar.addFavorite(folder)
        h.model.setSidebarWidth(260)

        let snapshot = h.model.sessionSnapshot()
        #expect(snapshot.favorites == [folder])
        #expect(snapshot.sidebarWidth == 260)
        #expect(published.last == snapshot)
    }
}
