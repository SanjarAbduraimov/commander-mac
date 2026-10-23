import CommanderCore
import Foundation
import Testing
@testable import CommanderController

struct OperationTextTests {
    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    @Test func summaries() {
        let progress = OperationProgress(totalFiles: 10, completedFiles: 3, totalBytes: 40_000_000, completedBytes: 12_000_000)
        let items = OperationProgress(totalFiles: 4, completedFiles: 1)

        #expect(OperationText.summary(OperationState(kind: .copy, progress: progress))
            == "Copying 3 of 10 files · \(bytes(12_000_000)) of \(bytes(40_000_000))")
        #expect(OperationText.summary(OperationState(kind: .move, progress: progress))
            == "Moving 3 of 10 files · \(bytes(12_000_000)) of \(bytes(40_000_000))")
        #expect(OperationText.summary(OperationState(kind: .trash, progress: items)) == "Moving to Trash 1 of 4 items")
        #expect(OperationText.summary(OperationState(kind: .delete, progress: items)) == "Deleting 1 of 4 items")
        #expect(OperationText.summary(OperationState(kind: .copy, progress: progress, status: .waitingForUser))
            == "Copying — waiting for your decision")
        #expect(OperationText.summary(OperationState(kind: .trash, progress: items, status: .waitingForUser))
            == "Moving to Trash — waiting for your decision")
    }

    @Test func failureMessages() {
        let url = URL(fileURLWithPath: "/x/N.txt")
        let cases: [(OperationFailure.Reason, String)] = [
            (.permissionDenied, "You don't have permission to access “N.txt”."),
            (.fileBusy, "“N.txt” is in use."),
            (.diskFull, "There isn't enough space for “N.txt”."),
            (.destinationInsideSource, "“N.txt” can't be copied into itself."),
            (.targetContainsSource, "“N.txt” can't be replaced because it contains the item being copied."),
            (.other("boom"), "Couldn't process “N.txt”: boom"),
        ]
        for (reason, expected) in cases {
            #expect(FailureText.message(OperationFailure(url: url, reason: reason)) == expected)
        }
    }
}
