import Foundation

public struct TypeAhead: Sendable {
    private let resetAfter: Duration
    private var prefix = ""
    private var lastInput: ContinuousClock.Instant?

    public init(resetAfter: Duration = .seconds(1)) {
        self.resetAfter = resetAfter
    }

    public mutating func input(_ character: Character, at time: ContinuousClock.Instant, in items: [FileItem]) -> String? {
        if let lastInput, lastInput.duration(to: time) > resetAfter { prefix = "" }
        lastInput = time
        prefix.append(character)
        return items.first { item in
            item.name.range(of: prefix, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
        }?.name
    }
}
