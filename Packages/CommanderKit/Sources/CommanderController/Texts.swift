import CommanderCore
import Foundation

func byteText(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
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
