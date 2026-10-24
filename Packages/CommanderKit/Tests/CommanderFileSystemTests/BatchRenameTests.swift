import Foundation
import Testing
@testable import CommanderFileSystem

struct BatchRenameTests {
    private func contents(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func write(_ tmp: TempDir, _ name: String, _ text: String) throws -> URL {
        let url = tmp.url.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    private func listing(_ tmp: TempDir) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: tmp.url.path).sorted()
    }

    @Test func renamesAll() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try write(tmp, "a.txt", "A"), b = try write(tmp, "b.txt", "B")

        try BatchRename.run([RenamePair(from: a, to: tmp.url.appendingPathComponent("x.txt")),
                             RenamePair(from: b, to: tmp.url.appendingPathComponent("y.txt"))])

        #expect(try listing(tmp) == ["x.txt", "y.txt"])
        #expect(try contents(tmp.url.appendingPathComponent("y.txt")) == "B")
    }

    @Test func swapsNames() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try write(tmp, "a", "A"), b = try write(tmp, "b", "B")

        try BatchRename.run([RenamePair(from: a, to: b), RenamePair(from: b, to: a)])

        #expect(try contents(a) == "B")
        #expect(try contents(b) == "A")
        #expect(try listing(tmp) == ["a", "b"])
    }

    @Test func caseOnlyRename() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try write(tmp, "a.txt", "A")

        try BatchRename.run([RenamePair(from: a, to: tmp.url.appendingPathComponent("A.txt"))])

        #expect(try listing(tmp) == ["A.txt"])
    }

    @Test func refusesExistingTarget() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try write(tmp, "a", "A"), c = try write(tmp, "c", "C")

        #expect(throws: BatchRenameError.self) { try BatchRename.run([RenamePair(from: a, to: c)]) }
        #expect(try contents(a) == "A")
        #expect(try contents(c) == "C")
    }

    @Test func rollsBackOnFailure() throws {
        let tmp = try TempDir()
        defer { tmp.remove() }
        let a = try write(tmp, "a", "A")
        let missing = tmp.url.appendingPathComponent("missing")

        #expect(throws: BatchRenameError.self) {
            try BatchRename.run([RenamePair(from: a, to: tmp.url.appendingPathComponent("x")),
                                 RenamePair(from: missing, to: tmp.url.appendingPathComponent("y"))])
        }
        #expect(try listing(tmp) == ["a"])
        #expect(try contents(a) == "A")
    }
}
