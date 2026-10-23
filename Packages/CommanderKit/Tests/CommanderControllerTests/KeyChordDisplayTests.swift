import CommanderCore
import Testing
@testable import CommanderController

struct KeyChordDisplayTests {
    @Test func displayStrings() {
        let cases = [
            ("cmd+shift+.", "⇧⌘."), ("ctrl+shift+tab", "⌃⇧Tab"), ("f5", "F5"), ("cmd+backspace", "⌘⌫"),
            ("space", "Space"), ("up", "↑"), ("cmd+,", "⌘,"), ("opt+a", "⌥A"),
        ]
        for (chord, expected) in cases {
            #expect(KeyChord(string: chord)!.displayString == expected)
        }
    }

    @Test func everyCommandHasTitle() {
        let titles = Command.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }
}
