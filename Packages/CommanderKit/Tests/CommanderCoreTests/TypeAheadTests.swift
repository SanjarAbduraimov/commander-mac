import Testing
@testable import CommanderCore

struct TypeAheadTests {
    @Test func jumpsToFirstPrefixMatchCaseInsensitive() {
        var typeAhead = TypeAhead()
        let items = fixtureItems("Alpha", "beta", "Bravo")
        let t0 = ContinuousClock.now
        #expect(typeAhead.input("b", at: t0, in: items) == "beta")
        #expect(typeAhead.input("r", at: t0.advanced(by: .milliseconds(200)), in: items) == "Bravo")
    }

    @Test func diacriticInsensitive() {
        var typeAhead = TypeAhead()
        #expect(typeAhead.input("c", at: .now, in: fixtureItems("Çay")) == "Çay")
    }

    @Test func resetsAfterOneSecond() {
        var typeAhead = TypeAhead()
        let items = fixtureItems("beta", "rho")
        let t0 = ContinuousClock.now
        #expect(typeAhead.input("b", at: t0, in: items) == "beta")
        #expect(typeAhead.input("r", at: t0.advanced(by: .milliseconds(1100)), in: items) == "rho")
    }

    @Test func noMatchReturnsNil() {
        var typeAhead = TypeAhead()
        #expect(typeAhead.input("z", at: .now, in: fixtureItems("a", "b")) == nil)
    }

    @Test func cyclesThroughMatchesOnRepeatedSingleCharacter() {
        var typeAhead = TypeAhead()
        let items = fixtureItems("Documents", "Downloads", "Drafts")
        let t0 = ContinuousClock.now
        #expect(typeAhead.input("d", at: t0, in: items) == "Documents")
        #expect(typeAhead.input("d", at: t0.advanced(by: .milliseconds(200)), in: items) == "Downloads")
        #expect(typeAhead.input("D", at: t0.advanced(by: .milliseconds(400)), in: items) == "Drafts")
        #expect(typeAhead.input("d", at: t0.advanced(by: .milliseconds(600)), in: items) == "Documents")
    }

    @Test func matchesHiddenFilesWithOrWithoutLeadingDot() {
        var typeAhead = TypeAhead()
        let items = fixtureItems(".bashrc", ".env", ".git", ".gitignore", "Archive.zip")
        let t0 = ContinuousClock.now
        // Typing 'g' matches '.git' (hidden file stripped dot)
        #expect(typeAhead.input("g", at: t0, in: items) == ".git")
        // Repeating 'g' cycles to '.gitignore'
        #expect(typeAhead.input("g", at: t0.advanced(by: .milliseconds(200)), in: items) == ".gitignore")

        // Reset after 1 second
        let t1 = t0.advanced(by: .milliseconds(1500))
        // Explicitly typing '.' matches hidden files starting with '.'
        #expect(typeAhead.input(".", at: t1, in: items) == ".bashrc")
        #expect(typeAhead.input("e", at: t1.advanced(by: .milliseconds(200)), in: items) == ".env")
    }

    @Test func switchesFromCyclingToMultiCharPrefix() {
        var typeAhead = TypeAhead()
        let items = fixtureItems("Documents", "Downloads", "Drafts")
        let t0 = ContinuousClock.now
        #expect(typeAhead.input("d", at: t0, in: items) == "Documents")
        // Typing 'o' after 'd' forms prefix "do", matching Documents then Downloads
        #expect(typeAhead.input("o", at: t0.advanced(by: .milliseconds(200)), in: items) == "Documents")
        #expect(typeAhead.input("w", at: t0.advanced(by: .milliseconds(300)), in: items) == "Downloads")
    }
}
