public enum UniqueName {
    public static func keepBoth(_ name: String, exists: (String) -> Bool) -> String {
        let (stem, ext) = split(name)
        return firstFree(exists) { "\(stem) \($0 + 2)\(ext)" }
    }

    public static func duplicate(_ name: String, exists: (String) -> Bool) -> String {
        let (stem, ext) = split(name)
        return firstFree(exists) { $0 == 0 ? "\(stem) copy\(ext)" : "\(stem) copy \($0 + 1)\(ext)" }
    }

    public static func newFolder(exists: (String) -> Bool) -> String {
        firstFree(exists) { $0 == 0 ? "untitled folder" : "untitled folder \($0 + 1)" }
    }

    private static func firstFree(_ exists: (String) -> Bool, _ candidate: (Int) -> String) -> String {
        var attempt = 0
        while exists(candidate(attempt)) { attempt += 1 }
        return candidate(attempt)
    }

    /// A leading dot (".bashrc") is part of the name, not an extension.
    private static func split(_ name: String) -> (stem: String, ext: String) {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return (name, "") }
        return (String(name[..<dot]), String(name[dot...]))
    }
}
