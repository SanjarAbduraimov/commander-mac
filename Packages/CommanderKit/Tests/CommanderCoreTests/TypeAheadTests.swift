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
}
