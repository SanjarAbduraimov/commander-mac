import Foundation
import Testing
@testable import CommanderFileSystem

struct VolumesTests {
    @Test func rootVolumeListedFirstWithCapacity() throws {
        let root = try #require(Volumes.mounted().first)
        #expect(root.url.path == "/")
        #expect((root.availableCapacity ?? 0) > 0)
        #expect((root.totalCapacity ?? 0) >= (root.availableCapacity ?? 0))
        #expect(root.isNetwork == false)
    }

    @Test func mountedDiskImageAppearsAndEjects() async throws {
        let image = try #require(try? DiskImage(sizeMB: 32, browsable: true), "hdiutil could not create a disk image")
        defer { image.detach() }
        let path = image.mountPoint.standardizedFileURL.path

        let volume = try #require(Volumes.mounted().first { $0.url.standardizedFileURL.path == path })
        #expect(volume.isEjectable)
        #expect(volume.name == image.mountPoint.lastPathComponent)

        try await Volumes.eject(volume.url)
        #expect(!Volumes.mounted().contains { $0.url.standardizedFileURL.path == path })
    }

    @Test func smbNormalization() {
        #expect(SMBAddress.normalize("server/share")?.absoluteString == "smb://server/share")
        #expect(SMBAddress.normalize("  smb://nas.local/media ")?.absoluteString == "smb://nas.local/media")
        #expect(SMBAddress.normalize("smb://user@nas/share")?.absoluteString == "smb://user@nas/share")
        #expect(SMBAddress.normalize("SMB://NAS/share")?.host == "NAS")
        #expect(SMBAddress.normalize("afp://x") == nil)
        #expect(SMBAddress.normalize("") == nil)
        #expect(SMBAddress.normalize("smb://") == nil)
    }
}
