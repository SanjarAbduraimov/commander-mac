import Testing
@testable import CommanderCore

struct NamePatternTests {
    @Test func wildcardsAndSeparators() {
        let images = NamePattern("*.jpg; *.PNG")
        #expect(images.matches("a.JPG"))
        #expect(images.matches("b.png"))
        #expect(!images.matches("c.gif"))
        #expect(NamePattern("a?c").matches("abc"))
        #expect(!NamePattern("a?c").matches("ac"))
        #expect(NamePattern("x*,y*").matches("yes"))
        #expect(!NamePattern("").matches("anything"))
        #expect(!NamePattern("  ;  ").matches("anything"))
    }
}
