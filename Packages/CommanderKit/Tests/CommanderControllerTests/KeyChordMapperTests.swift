import CommanderCore
import Testing
@testable import CommanderController

struct KeyChordMapperTests {
    @Test func shiftDotStaysDot() {
        #expect(KeyChordMapper.chord(keyCode: 47, baseCharacters: ".", modifiers: [.shift, .command]) == KeyChord(string: "cmd+shift+."))
    }

    @Test func namedKeysUseKeyCode() {
        let cases: [(UInt16, String?, String)] = [
            (126, nil, "up"), (51, "\u{7f}", "backspace"), (117, "\u{f728}", "forwardDelete"),
            (96, "\u{f708}", "f5"), (76, "\u{3}", "return"), (49, " ", "space"), (53, "\u{1b}", "escape"),
        ]
        for (code, characters, expected) in cases {
            #expect(KeyChordMapper.chord(keyCode: code, baseCharacters: characters, modifiers: []) == KeyChord(string: expected))
        }
    }

    @Test func controlShiftTab() {
        #expect(KeyChordMapper.chord(keyCode: 48, baseCharacters: "\t", modifiers: [.control, .shift]) == KeyChord(string: "ctrl+shift+tab"))
    }

    @Test func optionLetterUsesBaseCharacter() {
        #expect(KeyChordMapper.chord(keyCode: 0, baseCharacters: "a", modifiers: [.option]) == KeyChord(string: "opt+a"))
    }

    @Test func uppercaseBaseIsLowered() {
        #expect(KeyChordMapper.chord(keyCode: 17, baseCharacters: "T", modifiers: [.command]) == KeyChord(string: "cmd+t"))
    }

    @Test func emptyOrMultiCharacterGivesNil() {
        #expect(KeyChordMapper.chord(keyCode: 0, baseCharacters: "", modifiers: []) == nil)
        #expect(KeyChordMapper.chord(keyCode: 0, baseCharacters: nil, modifiers: []) == nil)
        #expect(KeyChordMapper.chord(keyCode: 0, baseCharacters: "ab", modifiers: []) == nil)
    }
}
