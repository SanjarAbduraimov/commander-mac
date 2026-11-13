import Foundation

public enum UndoAction: Equatable, Sendable {
    case rename(from: URL, to: URL)
    case move(items: [(source: URL, destination: URL)])
    case copy(createdItems: [URL])
    case trash(items: [(originalURL: URL, trashedURL: URL)])

    public static func == (lhs: UndoAction, rhs: UndoAction) -> Bool {
        switch (lhs, rhs) {
        case let (.rename(f1, t1), .rename(f2, t2)):
            return f1 == f2 && t1 == t2
        case let (.move(items1), .move(items2)):
            guard items1.count == items2.count else { return false }
            return zip(items1, items2).allSatisfy { $0.source == $1.source && $0.destination == $1.destination }
        case let (.copy(items1), .copy(items2)):
            return items1 == items2
        case let (.trash(items1), .trash(items2)):
            guard items1.count == items2.count else { return false }
            return zip(items1, items2).allSatisfy { $0.originalURL == $1.originalURL && $0.trashedURL == $1.trashedURL }
        default:
            return false
        }
    }
}

public struct UndoEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let description: String
    public let action: UndoAction
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        description: String,
        action: UndoAction,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.description = description
        self.action = action
        self.timestamp = timestamp
    }
}

public struct UndoStack: Sendable {
    public let maxCapacity: Int
    private var undoHistory: [UndoEntry] = []
    private var redoHistory: [UndoEntry] = []

    public init(maxCapacity: Int = 50) {
        self.maxCapacity = max(1, maxCapacity)
    }

    public var canUndo: Bool {
        !undoHistory.isEmpty
    }

    public var canRedo: Bool {
        !redoHistory.isEmpty
    }

    public var undoEntriesCount: Int {
        undoHistory.count
    }

    public var undoTitle: String? {
        guard let last = undoHistory.last else { return nil }
        return "Undo \(last.description)"
    }

    public var redoTitle: String? {
        guard let last = redoHistory.last else { return nil }
        return "Redo \(last.description)"
    }

    public mutating func push(action: UndoAction, description: String) {
        let entry = UndoEntry(description: description, action: action)
        push(entry)
    }

    public mutating func push(_ entry: UndoEntry) {
        undoHistory.append(entry)
        redoHistory.removeAll()
        if undoHistory.count > maxCapacity {
            undoHistory.removeFirst(undoHistory.count - maxCapacity)
        }
    }

    public mutating func popUndo() -> UndoEntry? {
        guard let entry = undoHistory.popLast() else { return nil }
        redoHistory.append(entry)
        return entry
    }

    public mutating func popRedo() -> UndoEntry? {
        guard let entry = redoHistory.popLast() else { return nil }
        undoHistory.append(entry)
        return entry
    }

    public mutating func clear() {
        undoHistory.removeAll()
        redoHistory.removeAll()
    }
}
