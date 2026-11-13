import Foundation
import Testing
@testable import CommanderFileSystem

struct VolumeResolverTests {
    @Test func localPathsResolveSameVolume() {
        let tempDir1 = FileManager.default.temporaryDirectory.appendingPathComponent("dir1")
        let tempDir2 = FileManager.default.temporaryDirectory.appendingPathComponent("dir2")

        let resolver = VolumeResolver()
        let id1 = resolver.volumeIdentifier(for: tempDir1)
        let id2 = resolver.volumeIdentifier(for: tempDir2)

        #expect(id1 != nil)
        #expect(id1 == id2)
        #expect(resolver.isSameVolume(tempDir1, tempDir2) == true)
    }

    @Test func distinctMountedDiskImagesResolveDifferentVolumes() throws {
        let diskImage = try #require(try? DiskImage(sizeMB: 32, browsable: false))
        defer { diskImage.detach() }

        let localPath = FileManager.default.temporaryDirectory.appendingPathComponent("local.txt")
        let mountedPath = diskImage.mountPoint.appendingPathComponent("mounted.txt")

        let resolver = VolumeResolver()
        let localId = resolver.volumeIdentifier(for: localPath)
        let mountedId = resolver.volumeIdentifier(for: mountedPath)

        #expect(localId != nil)
        #expect(mountedId != nil)
        #expect(localId != mountedId)
        #expect(resolver.isSameVolume(localPath, mountedPath) == false)
    }

    @Test func nonExistentChildResolvesToParentVolume() {
        let resolver = VolumeResolver()
        let parent = FileManager.default.temporaryDirectory
        let deepNonExistent = parent.appendingPathComponent("a/b/c/d/file.txt")

        let parentId = resolver.volumeIdentifier(for: parent)
        let childId = resolver.volumeIdentifier(for: deepNonExistent)

        #expect(childId != nil)
        #expect(parentId == childId)
    }
}
