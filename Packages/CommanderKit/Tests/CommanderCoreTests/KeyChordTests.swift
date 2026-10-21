import Foundation
import Testing
@testable import CommanderCore

struct KeyChordTests {
    @Test func parsesAndPrintsRoundTrip() {
        #expect(KeyChord(string: "cmd+shift+.") == KeyChord(".", [.command, .shift]))
        #expect(KeyChord(".", [.command, .shift]).description == "shift+cmd+.")
        #expect(KeyChord(string: "ctrl+shift+tab") == KeyChord("tab", [.control, .shift]))
        #expect(KeyChord(string: "f5") == KeyChord("f5"))
        #expect(KeyChord(string: "cmd+T") == KeyChord("t", [.command]))
        for chord in [KeyChord("tab", [.control, .shift]), KeyChord("backspace", [.command]), KeyChord(",", [.command])] {
            #expect(KeyChord(string: chord.description) == chord)
        }
    }

    @Test func rejectsUnknownModifierOrEmptyKey() {
        #expect(KeyChord(string: "hyper+a") == nil)
        #expect(KeyChord(string: "cmd+") == nil)
        #expect(KeyChord(string: "") == nil)
        #expect(KeyChord(string: "cmd+banana") == nil)
    }

    @Test func codableAsString() throws {
        let data = try JSONEncoder().encode(KeyChord("t", [.command]))
        #expect(String(decoding: data, as: UTF8.self) == "\"cmd+t\"")
        #expect(try JSONDecoder().decode(KeyChord.self, from: Data("\"ctrl+tab\"".utf8)) == KeyChord("tab", [.control]))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(KeyChord.self, from: Data("\"hyper+x\"".utf8)) }
    }
}
