import Foundation
import Testing
@testable import CommanderCore

private func item(_ name: String, _ kind: FileItem.Kind = .file, size: Int64? = 0, modified: TimeInterval = 0) -> FileItem {
    FileItem(
        name: name,
        url: URL(fileURLWithPath: "/tmp/\(name)"),
        kind: kind,
        size: kind == .directory ? nil : size,
        modified: Date(timeIntervalSince1970: modified),
        isHidden: name.hasPrefix(".")
    )
}

private func names(_ items: [FileItem]) -> [String] { items.map(\.name) }

struct FileSortTests {
    @Test func navigableItemsAlwaysFirst() {
        let sort = FileSort(column: .name, ascending: false)
        let result = sort.sorted([item("b.txt"), item("aDir", .directory), item("c.txt")])
        #expect(names(result) == ["aDir", "c.txt", "b.txt"])
    }

    @Test func nameUsesFinderOrder() {
        let result = FileSort().sorted([item("file10"), item("file2"), item("File1")])
        #expect(names(result) == ["File1", "file2", "file10"])
    }

    @Test func sizeSortKeepsDirectoriesByName() {
        let sort = FileSort(column: .size, ascending: true)
        let result = sort.sorted([
            item("b", .directory), item("x", size: 5), item("a", .directory), item("y", size: 1), item("z", size: 3),
        ])
        #expect(names(result) == ["a", "b", "y", "z", "x"])
    }

    @Test func sizeSortIsDeterministicWithSizelessPackages() {
        let items = [item("P.app", .package, size: nil), item("a", size: 5), item("z", size: 1),
                     item("m", size: 3), item("Q.app", .package, size: nil), item("b", size: 9)]
        let sort = FileSort(column: .size, ascending: true)
        let expected = ["P.app", "Q.app", "z", "m", "a", "b"]
        for _ in 0..<50 {
            #expect(names(sort.sorted(items.shuffled())) == expected)
        }
    }

    @Test func modifiedDescending() {
        let sort = FileSort(column: .modified, ascending: false)
        let result = sort.sorted([item("old", modified: 1), item("new", modified: 3), item("mid", modified: 2)])
        #expect(names(result) == ["new", "mid", "old"])
    }

    @Test func symlinkToDirectoryCountsAsFolder_packageCountsAsFile() {
        let result = FileSort().sorted([
            item("a.app", .package),
            item("b-link", .symlink(toDirectory: true)),
            item("c-link", .symlink(toDirectory: false)),
            item("d", .directory),
        ])
        #expect(names(result) == ["b-link", "d", "a.app", "c-link"])
    }

    @Test func extensionParts() {
        #expect(item("archive.tar.gz").ext == "gz")
        #expect(item("archive.tar.gz").baseName == "archive.tar")
        #expect(item(".env").ext == "")
        #expect(item(".env").baseName == ".env")
        #expect(item("file.").ext == "")
        #expect(item("file.").baseName == "file.")
        #expect(item("a.b", .directory).ext == "")
        #expect(item("Safari.app", .package).ext == "app")
        #expect(item("Report.PDF").ext == "PDF")
    }

    @Test func sortsByExtensionThenName() {
        let result = FileSort(column: .ext).sorted([item("b.txt"), item("c.pdf"), item("dir", .directory), item("a.PDF"), item("noext")])
        #expect(names(result) == ["dir", "noext", "a.PDF", "c.pdf", "b.txt"])
    }

    @Test func sortsByKindAndCreated() {
        func dated(_ name: String, created: TimeInterval?) -> FileItem {
            FileItem(name: name, url: URL(fileURLWithPath: "/tmp/\(name)"), kind: .file, size: 0,
                     modified: Date(timeIntervalSince1970: 0), isHidden: false,
                     created: created.map { Date(timeIntervalSince1970: $0) })
        }
        let items = [dated("x.txt", created: 5), dated("y.pdf", created: nil), dated("z.txt", created: 1), dated("w", created: 2)]
        #expect(items.map(\.kindName).allSatisfy { !$0.isEmpty })
        #expect(items[3].kindName == "Document")
        let byKind = names(FileSort(column: .kind).sorted(items))
        #expect(byKind.firstIndex(of: "x.txt")! + 1 == byKind.firstIndex(of: "z.txt")!)
        #expect(names(FileSort(column: .created).sorted(items)) == ["y.pdf", "z.txt", "w", "x.txt"])
    }
}
