import Foundation

public struct TypeAhead: Sendable {
    private let resetAfter: Duration
    private var prefix = ""
    private var lastInput: ContinuousClock.Instant?
    private var cycleIndex: Int = 0
    private var lastMatchedNames: [String] = []

    public init(resetAfter: Duration = .seconds(1)) {
        self.resetAfter = resetAfter
    }

    public mutating func input(_ character: Character, at time: ContinuousClock.Instant, in items: [FileItem]) -> String? {
        if let lastInput, lastInput.duration(to: time) >= resetAfter {
            prefix = ""
            cycleIndex = 0
            lastMatchedNames = []
        }
        lastInput = time

        let isSingleRepeatedChar = (prefix.count == 1 && prefix.first?.lowercased() == character.lowercased())

        if isSingleRepeatedChar && !lastMatchedNames.isEmpty {
            cycleIndex = (cycleIndex + 1) % lastMatchedNames.count
            return lastMatchedNames[cycleIndex]
        }

        prefix.append(character)

        let matches = items.compactMap { item -> String? in
            matchesPrefix(item.name, prefix: prefix) ? item.name : nil
        }

        lastMatchedNames = matches
        cycleIndex = 0
        return matches.first
    }

    private func matchesPrefix(_ name: String, prefix: String) -> Bool {
        let lowerName = name.lowercased()
        let lowerPrefix = prefix.lowercased()
        if lowerName.hasPrefix(lowerPrefix) {
            return true
        }
        if name.range(of: prefix, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil {
            return true
        }
        if !prefix.hasPrefix(".") && name.hasPrefix(".") {
            let stripped = String(name.dropFirst())
            let lowerStripped = stripped.lowercased()
            if lowerStripped.hasPrefix(lowerPrefix) {
                return true
            }
            if stripped.range(of: prefix, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil {
                return true
            }
        }
        return false
    }
}
