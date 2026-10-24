import CommanderCore
import Foundation

public enum NameCase: String, CaseIterable, Sendable {
    case unchanged, lower, upper, firstLetter, title

    public var title: String {
        switch self {
        case .unchanged: "Unchanged"
        case .lower: "lowercase"
        case .upper: "UPPERCASE"
        case .firstLetter: "First letter"
        case .title: "Title Case"
        }
    }
}

public struct MultiRenameOptions: Equatable, Sendable {
    public var nameMask = "[N]"
    public var extMask = "[E]"
    public var search = ""
    public var replace = ""
    public var useRegex = false
    public var caseSensitive = false
    public var nameCase = NameCase.unchanged
    public var counterStart = 1
    public var counterStep = 1
    public var counterDigits = 1

    public init() {}
}

public enum RenameProblem: Equatable, Sendable {
    case empty, invalidCharacter, exists, duplicate, invalidRegex
}

public struct MultiRenameRow: Equatable, Sendable {
    public let item: FileItem
    public let newName: String
    public let problem: RenameProblem?

    public var isChanged: Bool { newName != item.name }
}

/// Total Commander's Multi-Rename: masks, then search & replace, then case, applied to each item in order.
public enum MultiRename {
    public static func preview(_ items: [FileItem], folderName: String, existing: Set<String>, options: MultiRenameOptions) -> [MultiRenameRow] {
        var regex: NSRegularExpression?
        if options.useRegex, !options.search.isEmpty {
            regex = try? NSRegularExpression(pattern: options.search, options: options.caseSensitive ? [] : .caseInsensitive)
            if regex == nil {
                return items.map { MultiRenameRow(item: $0, newName: $0.name, problem: .invalidRegex) }
            }
        }
        let names = items.enumerated().map { index, item in
            newName(for: item, index: index, folderName: folderName, options: options, regex: regex)
        }
        // A batch member's old name is free once it moves, so only names outside the batch count as taken.
        let freed = Set(items.map { $0.name.lowercased() })
        let taken = Set(existing.map { $0.lowercased() }).subtracting(freed)
        var counts: [String: Int] = [:]
        for name in names { counts[name.lowercased(), default: 0] += 1 }

        return zip(items, names).map { item, name in
            let key = name.lowercased()
            let problem: RenameProblem? =
                name.isEmpty ? .empty
                : name.contains("/") || name.contains(":") ? .invalidCharacter
                : counts[key, default: 0] > 1 ? .duplicate
                : taken.contains(key) ? .exists
                : nil
            return MultiRenameRow(item: item, newName: name, problem: problem)
        }
    }

    private static func newName(
        for item: FileItem, index: Int, folderName: String, options: MultiRenameOptions, regex: NSRegularExpression?
    ) -> String {
        let counter = options.counterStart + index * options.counterStep
        let expand = { (mask: String) in expandMask(mask, item: item, counter: counter, options: options, folderName: folderName) }
        let base = expand(options.nameMask)
        let ext = expand(options.extMask)
        var name = ext.isEmpty ? base : base + "." + ext

        if let regex {
            name = regex.stringByReplacingMatches(in: name, range: NSRange(name.startIndex..., in: name), withTemplate: options.replace)
        } else if !options.search.isEmpty {
            name = name.replacingOccurrences(of: options.search, with: options.replace, options: options.caseSensitive ? [] : .caseInsensitive)
        }
        return applyCase(options.nameCase, to: name)
    }

    private static func expandMask(_ mask: String, item: FileItem, counter: Int, options: MultiRenameOptions, folderName: String) -> String {
        var result = ""
        var rest = Substring(mask)
        while let open = rest.firstIndex(of: "["), let close = rest[open...].firstIndex(of: "]") {
            result += rest[..<open]
            let tag = String(rest[rest.index(after: open)..<close])
            result += value(of: tag, item: item, counter: counter, options: options, folderName: folderName) ?? "[\(tag)]"
            rest = rest[rest.index(after: close)...]
        }
        return result + rest
    }

    /// nil for an unknown tag, which then stays in the name as typed.
    private static func value(of tag: String, item: FileItem, counter: Int, options: MultiRenameOptions, folderName: String) -> String? {
        switch tag {
        case "N": return item.baseName
        case "E": return item.ext
        case "P": return folderName
        case "C":
            let digits = String(counter)
            return String(repeating: "0", count: max(options.counterDigits - digits.count, 0)) + digits
        case "YMD", "Y", "M", "D", "hms":
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.modified)
            let two = { (value: Int?) in String(format: "%02d", value ?? 0) }
            let year = String(format: "%04d", parts.year ?? 0)
            switch tag {
            case "YMD": return year + two(parts.month) + two(parts.day)
            case "Y": return year
            case "M": return two(parts.month)
            case "D": return two(parts.day)
            default: return two(parts.hour) + two(parts.minute) + two(parts.second)
            }
        default:
            return nameRange(tag, in: item.baseName)
        }
    }

    /// "N3" (one character), "N2-5" and "N3-" (to the end), counted from 1; out-of-range parts are empty.
    private static func nameRange(_ tag: String, in name: String) -> String? {
        guard tag.first == "N" else { return nil }
        let spec = tag.dropFirst()
        let bounds = spec.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(bounds.count), let start = Int(bounds[0]), start >= 1 else { return nil }
        let characters = Array(name)
        let end: Int
        if bounds.count == 1 {
            end = start
        } else if bounds[1].isEmpty {
            end = characters.count
        } else if let value = Int(bounds[1]) {
            end = value
        } else {
            return nil
        }
        guard start <= characters.count, start <= end else { return "" }
        return String(characters[(start - 1)..<min(end, characters.count)])
    }

    private static func applyCase(_ nameCase: NameCase, to name: String) -> String {
        switch nameCase {
        case .unchanged: name
        case .lower: name.lowercased()
        case .upper: name.uppercased()
        case .firstLetter: name.prefix(1).uppercased() + name.dropFirst()
        case .title: name.capitalized
        }
    }
}
