import CommanderCore
import Foundation

func byteText(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
}

public enum PaneText {
    /// "12 items · 3 marked · 4.8 MB" — the size is the marked files', or every listed file's when none is marked.
    /// Folders count once their size has been calculated (`folderSizes` is keyed by standardized path).
    public static func status(_ tab: TabState, folderSizes: [String: Int64] = [:]) -> String {
        let count = tab.items.count
        var text = count == 1 ? "1 item" : "\(count) items"
        let sized = tab.marked.isEmpty ? tab.items : tab.items.filter { tab.marked.contains($0.name) }
        if !tab.marked.isEmpty { text += " · \(tab.marked.count) marked" }
        let bytes = sized.reduce(Int64(0)) { $0 + ($1.size ?? folderSizes[$1.url.standardizedFileURL.path] ?? 0) }
        return text + " · " + byteText(bytes)
    }

    public static func selectionSummary(_ tab: TabState, side: PaneSide) -> String? {
        tab.marked.isEmpty ? nil : "\(tab.marked.count) marked in \(side.rawValue) pane"
    }
}

public struct FooterHint: Equatable, Sendable {
    public let keys: String
    public let title: String

    public init(keys: String, title: String) {
        self.keys = keys
        self.title = title
    }
}

public enum FooterHints {
    public static func items(bindings: KeyBindings, behavior: BehaviorSettings) -> [FooterHint] {
        func hint(_ command: Command, _ title: String) -> FooterHint? {
            bindings.chords(for: command).first.map { FooterHint(keys: $0.displayString, title: title) }
        }
        let backspace: FooterHint? = switch bindings.command(for: KeyChord("backspace"), in: .table) {
        case .goUp: FooterHint(keys: "⌫", title: "Parent folder")
        case .goBack: FooterHint(keys: "⌫", title: "Back")
        default: nil
        }
        return [
            hint(.toggleMark, behavior.spaceAdvances ? "Mark & next" : "Mark"),
            hint(.switchPane, "Switch pane"),
            backspace,
            hint(.copyToOtherPane, "Copy"),
            hint(.moveToOtherPane, "Move"),
            hint(.newFolder, "New folder"),
            hint(.rename, "Rename"),
            hint(.moveToTrash, "Trash"),
        ].compactMap { $0 }
    }
}

public enum OperationText {
    public static func summary(_ state: OperationState) -> String {
        let verb = switch state.kind {
        case .copy: "Copying"
        case .move: "Moving"
        case .trash: "Moving to Trash"
        case .delete: "Deleting"
        }
        if state.status == .waitingForUser { return "\(verb) — waiting for your decision" }
        let p = state.progress
        switch state.kind {
        case .copy, .move:
            return "\(verb) \(p.completedFiles) of \(p.totalFiles) files · \(byteText(p.completedBytes)) of \(byteText(p.totalBytes))"
        case .trash, .delete:
            return "\(verb) \(p.completedFiles) of \(p.totalFiles) items"
        }
    }
}

public enum FailureText {
    public static func message(_ failure: OperationFailure) -> String {
        let name = failure.url.lastPathComponent
        return switch failure.reason {
        case .permissionDenied: "You don't have permission to access “\(name)”."
        case .fileBusy: "“\(name)” is in use."
        case .diskFull: "There isn't enough space for “\(name)”."
        case .destinationInsideSource: "“\(name)” can't be copied into itself."
        case .targetContainsSource: "“\(name)” can't be replaced because it contains the item being copied."
        case let .other(message): "Couldn't process “\(name)”: \(message)"
        }
    }
}
