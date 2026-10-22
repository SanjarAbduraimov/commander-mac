import Testing
@testable import CommanderCore

private func taken(_ names: String...) -> (String) -> Bool {
    let set = Set(names)
    return { set.contains($0) }
}

struct UniqueNameTests {
    @Test func keepBothAddsNumberBeforeExtension() {
        #expect(UniqueName.keepBoth("a.txt", exists: taken("a.txt")) == "a 2.txt")
        #expect(UniqueName.keepBoth("a.txt", exists: taken("a.txt", "a 2.txt")) == "a 3.txt")
    }

    @Test func keepBothForFolderAndPackage() {
        #expect(UniqueName.keepBoth("dir", exists: taken("dir")) == "dir 2")
        #expect(UniqueName.keepBoth("X.app", exists: taken("X.app")) == "X 2.app")
        #expect(UniqueName.keepBoth("archive.tar.gz", exists: taken("archive.tar.gz")) == "archive.tar 2.gz")
    }

    @Test func dotfileHasNoExtension() {
        #expect(UniqueName.keepBoth(".bashrc", exists: taken(".bashrc")) == ".bashrc 2")
        #expect(UniqueName.duplicate(".env", exists: taken(".env")) == ".env copy")
    }

    @Test func duplicateUsesCopySuffix() {
        #expect(UniqueName.duplicate("a.txt", exists: taken("a.txt")) == "a copy.txt")
        #expect(UniqueName.duplicate("a.txt", exists: taken("a.txt", "a copy.txt")) == "a copy 2.txt")
        #expect(UniqueName.duplicate("a.txt", exists: taken("a.txt", "a copy.txt", "a copy 2.txt")) == "a copy 3.txt")
    }

    @Test func newFolderName() {
        #expect(UniqueName.newFolder(exists: taken()) == "untitled folder")
        #expect(UniqueName.newFolder(exists: taken("untitled folder")) == "untitled folder 2")
        #expect(UniqueName.newFolder(exists: taken("untitled folder", "untitled folder 2")) == "untitled folder 3")
    }
}
