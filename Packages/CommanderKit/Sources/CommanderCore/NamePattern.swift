import Darwin

/// Total Commander's "select group" patterns: `*.jpg;*.png`, separated by `;`, `,` or spaces, with `*` and `?`,
/// case-insensitive. An empty pattern matches nothing.
public struct NamePattern: Sendable {
    private let parts: [String]

    public init(_ text: String) {
        parts = text.split(whereSeparator: { $0 == ";" || $0 == "," || $0 == " " }).map(String.init)
    }

    public func matches(_ name: String) -> Bool {
        parts.contains { fnmatch($0, name, FNM_CASEFOLD) == 0 }
    }
}
