import Foundation
import Testing
@testable import CommanderCore

struct TransferModelTests {
    @Test func progressCalculationAndFormatting() {
        let progress = TransferProgress(
            bytesTransferred: 50_000_000,
            totalBytes: 100_000_000,
            filesTransferred: 5,
            totalFiles: 10,
            currentFileName: "video.mp4",
            bytesPerSecond: 25_000_000,
            estimatedSecondsRemaining: 2.0
        )

        #expect(progress.fractionCompleted == 0.5)
        #expect(progress.formattedSpeed.contains("MB/s"))
        #expect(progress.formattedETA == "00:02")
    }

    @Test func progressZeroTotalBytesHandlesSafely() {
        let progress = TransferProgress(
            bytesTransferred: 0,
            totalBytes: 0,
            filesTransferred: 0,
            totalFiles: 0,
            currentFileName: "",
            bytesPerSecond: 0,
            estimatedSecondsRemaining: nil
        )

        #expect(progress.fractionCompleted == 0.0)
        #expect(progress.formattedETA == "--:--")
    }

    @Test func conflictDetailsComparesDatesCorrectly() {
        let now = Date()
        let older = now.addingTimeInterval(-3600)
        let newer = now

        let conflict = ConflictDetails(
            sourceURL: URL(fileURLWithPath: "/source/file.txt"),
            targetURL: URL(fileURLWithPath: "/dest/file.txt"),
            sourceSize: 2048,
            targetSize: 1024,
            sourceModified: newer,
            targetModified: older
        )

        #expect(conflict.isSourceNewer == true)
        #expect(conflict.hasSizeDifference == true)
    }

    @Test func transferJobStateTransitions() {
        let job = TransferJob(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/src/a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/dst"),
            sourceVolumeIdentifier: "vol-1",
            targetVolumeIdentifier: "vol-1"
        )

        #expect(job.state == .queued)
        #expect(job.isSameVolume == true)

        var runningJob = job
        let p = TransferProgress(
            bytesTransferred: 100,
            totalBytes: 200,
            filesTransferred: 1,
            totalFiles: 2,
            currentFileName: "a.txt",
            bytesPerSecond: 50,
            estimatedSecondsRemaining: 2
        )
        runningJob.state = .running(p)
        #expect(runningJob.isRunning == true)
        #expect(runningJob.isTerminal == false)

        runningJob.state = .paused(p)
        #expect(runningJob.isPaused == true)

        runningJob.state = .completed
        #expect(runningJob.isTerminal == true)
    }
}
