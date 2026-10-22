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
}
