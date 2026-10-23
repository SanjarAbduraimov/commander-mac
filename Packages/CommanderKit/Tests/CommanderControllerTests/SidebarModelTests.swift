import CommanderCore
import CommanderFileSystem
import Foundation
import Synchronization
import Testing
@testable import CommanderController

func volume(_ name: String, at path: String, total: Int64? = 500_000_000_000, available: Int64? = 182_000_000_000, ejectable: Bool = true) -> VolumeInfo {
    VolumeInfo(
        name: name, url: URL(fileURLWithPath: path, isDirectory: true), totalCapacity: total,
        availableCapacity: available, isEjectable: ejectable, isNetwork: false
    )
}

@MainActor
struct SidebarModelTests {
    private func sidebar(_ favorites: [URL] = [], volumes: [VolumeInfo] = []) -> SidebarModel {
        SidebarModel(favorites: favorites, volumes: { volumes }, executor: OperationExecutor(label: "test.sidebar"))
    }

    @Test func addFavoriteOnlyFoldersNoDuplicates() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let folder = try tmp.dir("x")
        let file = try tmp.file("f.txt")
        let model = sidebar()

        #expect(model.addFavorite(folder))
        #expect(!model.addFavorite(file))
        #expect(!model.addFavorite(folder.appendingPathComponent("../x")))
        #expect(model.favorites == [folder])
    }

    @Test func addFavoriteAtIndexAndRemove() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let (a, b, c) = (try tmp.dir("a"), try tmp.dir("b"), try tmp.dir("c"))
        let model = sidebar([a, b])
        var changes = 0
        model.onChange = { changes += 1 }

        #expect(model.addFavorite(c, at: 1))
        #expect(model.favorites == [a, c, b])
        model.removeFavorite(at: 0)
        #expect(model.favorites == [c, b])
        #expect(changes == 2)
    }

    @Test func refreshVolumesPublishes() async {
        let disks = [volume("Macintosh HD", at: "/"), volume("Backup", at: "/Volumes/Backup")]
        let model = sidebar(volumes: disks)
        var changes = 0
        model.onChange = { changes += 1 }

        await model.refreshVolumes()

        #expect(model.volumes == disks)
        #expect(changes == 1)
    }

    @Test func capacityText() {
        let bytes = { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        #expect(SidebarModel.capacityText(volume("D", at: "/")) == "\(bytes(182_000_000_000)) available of \(bytes(500_000_000_000))")
        #expect(SidebarModel.capacityText(volume("D", at: "/", total: nil)) == nil)
        #expect(SidebarModel.capacityText(volume("D", at: "/", available: nil)) == nil)
    }
}
