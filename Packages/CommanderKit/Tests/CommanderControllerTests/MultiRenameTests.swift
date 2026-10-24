import CommanderCore
import Foundation
import Testing
@testable import CommanderController

struct MultiRenameTests {
    private func names(_ items: [FileItem], existing: Set<String> = [], _ configure: (inout MultiRenameOptions) -> Void) -> [String] {
        rows(items, existing: existing, configure).map(\.newName)
    }

    private func rows(_ items: [FileItem], existing: Set<String> = [], _ configure: (inout MultiRenameOptions) -> Void) -> [MultiRenameRow] {
        var options = MultiRenameOptions()
        configure(&options)
        let all = existing.union(items.map(\.name))
        return MultiRename.preview(items, folderName: "Holiday", existing: all, options: options)
    }

    @Test func defaultMasksKeepNames() {
        let result = rows([item("a.txt"), item("noext"), item("dir", .directory)]) { _ in }
        #expect(result.map(\.newName) == ["a.txt", "noext", "dir"])
        #expect(result.allSatisfy { !$0.isChanged && $0.problem == nil })
    }

    @Test func nameRangesAndCounter() {
        let result = names([item("photo.jpg"), item("x.png")]) {
            $0.nameMask = "[N1-3]_[C]"
            $0.counterStart = 5
            $0.counterStep = 2
            $0.counterDigits = 3
        }
        #expect(result == ["pho_005.jpg", "x_007.png"])
    }

    @Test func openRangeAndSingleChar() {
        #expect(names([item("abcdef")]) { $0.nameMask = "[N3-]" } == ["cdef"])
        #expect(names([item("abcdef")]) { $0.nameMask = "[N2]" } == ["b"])
        let empty = rows([item("abcdef")]) { $0.nameMask = "[N9-]" }
        #expect(empty[0].newName == "")
        #expect(empty[0].problem == .empty)
    }

    @Test func parentAndDateTags() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 15, minute: 30, second: 12))!
        let photo = FileItem(name: "img.jpg", url: URL(fileURLWithPath: "/root/img.jpg"), kind: .file, size: 1, modified: date, isHidden: false)
        #expect(names([photo]) { $0.nameMask = "[P]-[YMD]-[hms]" } == ["Holiday-20261024-153012.jpg"])
        #expect(names([photo]) { $0.nameMask = "[Y].[M].[D]" } == ["2026.10.24.jpg"])
    }

    @Test func unknownTagStaysText() {
        #expect(names([item("name.txt")]) { $0.nameMask = "[X][N]" } == ["[X]name.txt"])
    }

    @Test func plainAndRegexReplace() {
        #expect(names([item("IMG_1.jpg"), item("img_2.jpg")]) { $0.search = "IMG"; $0.replace = "Photo" } == ["Photo_1.jpg", "Photo_2.jpg"])
        #expect(names([item("IMG_1.jpg"), item("img_2.jpg")]) { $0.search = "IMG"; $0.replace = "Photo"; $0.caseSensitive = true }
            == ["Photo_1.jpg", "img_2.jpg"])
        #expect(names([item("a12.txt")]) { $0.search = "(\\d+)"; $0.replace = "n$1"; $0.useRegex = true } == ["an12.txt"])
    }

    @Test func invalidRegexMarksAllRows() {
        let result = rows([item("a.txt"), item("b.txt")]) { $0.search = "("; $0.useRegex = true }
        #expect(result.allSatisfy { $0.problem == .invalidRegex })
    }

    @Test func caseModes() {
        let file = [item("my FILE name.TXT")]
        #expect(names(file) { $0.nameCase = .lower } == ["my file name.txt"])
        #expect(names(file) { $0.nameCase = .upper } == ["MY FILE NAME.TXT"])
        #expect(names(file) { $0.nameCase = .firstLetter } == ["My FILE name.TXT"])
        #expect(names(file) { $0.nameCase = .title } == ["My File Name.Txt"])
        #expect(NameCase.allCases.map(\.title) == ["Unchanged", "lowercase", "UPPERCASE", "First letter", "Title Case"])
    }

    @Test func conflictsAreReported() {
        let exists = rows([item("a.txt")], existing: ["B.txt"]) { $0.nameMask = "b" }
        #expect(exists[0].problem == .exists)
        let duplicates = rows([item("a.txt"), item("c.txt")]) { $0.nameMask = "same" }
        #expect(duplicates.map(\.problem) == [.duplicate, .duplicate])
        let slash = rows([item("a.txt")]) { $0.nameMask = "a/b" }
        #expect(slash[0].problem == .invalidCharacter)
    }

    @Test func renamingIntoAnotherBatchMembersOldNameIsFine() {
        // "1.txt" may become "2.txt" because the current "2.txt" moves on to "3.txt".
        let result = rows([item("1.txt"), item("2.txt")], existing: ["9.txt"]) { $0.nameMask = "[C]"; $0.counterStart = 2 }
        #expect(result.map(\.newName) == ["2.txt", "3.txt"])
        #expect(result.allSatisfy { $0.problem == nil })
    }

    @Test func caseOnlyChangeIsNotAConflict() {
        let result = rows([item("a.txt")]) { $0.nameMask = "A" }
        #expect(result[0].newName == "A.txt")
        #expect(result[0].problem == nil)
        #expect(result[0].isChanged)
    }

    @Test func folderHasNoExtension() {
        #expect(names([item("My.Folder", .directory)]) { $0.nameMask = "[N]_x" } == ["My.Folder_x"])
    }
}
