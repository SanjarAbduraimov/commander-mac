import Foundation
import Testing
@testable import CommanderCore
@testable import CommanderFileSystem

struct TransferQueueTests {
    @Test func sameVolumeJobsRunSequentially() async {
        let queue = TransferQueue()

        let id1 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dest"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let id2 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/b.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dest"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let job1 = await queue.job(id: id1)
        let job2 = await queue.job(id: id2)

        #expect(job1?.isRunning == true)
        #expect(job2?.state == .queued)

        // Complete job 1 -> job 2 should start
        await queue.completeJob(id: id1)

        let updatedJob1 = await queue.job(id: id1)
        let updatedJob2 = await queue.job(id: id2)

        #expect(updatedJob1?.state == .completed)
        #expect(updatedJob2?.isRunning == true)
    }

    @Test func differentVolumeJobsRunConcurrently() async {
        let queue = TransferQueue()

        let id1 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dest"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let id2 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol2/b.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol2/dest"),
            sourceVolume: "vol2",
            targetVolume: "vol2"
        )

        let job1 = await queue.job(id: id1)
        let job2 = await queue.job(id: id2)

        #expect(job1?.isRunning == true)
        #expect(job2?.isRunning == true)
    }

    @Test func pauseAndResumeJob() async {
        let queue = TransferQueue()

        let id = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/src/file.dat")],
            destinationDirectory: URL(fileURLWithPath: "/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let progress = TransferProgress(
            bytesTransferred: 50,
            totalBytes: 100,
            filesTransferred: 1,
            totalFiles: 2,
            currentFileName: "file.dat",
            bytesPerSecond: 25,
            estimatedSecondsRemaining: 2
        )
        await queue.updateProgress(id: id, progress: progress)

        await queue.pause(id: id)
        let paused = await queue.job(id: id)
        #expect(paused?.isPaused == true)

        await queue.resume(id: id)
        let resumed = await queue.job(id: id)
        #expect(resumed?.isRunning == true)
    }

    @Test func cancelJobStartsNextInQueue() async {
        let queue = TransferQueue()

        let id1 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/1.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let id2 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/2.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        await queue.cancel(id: id1)

        let job1 = await queue.job(id: id1)
        let job2 = await queue.job(id: id2)

        #expect(job1?.state == .cancelled)
        #expect(job2?.isRunning == true)
    }

    @Test func startImmediatelyOverridesVolumeLock() async {
        let queue = TransferQueue()

        let id1 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/1.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let id2 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/2.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        #expect(await queue.job(id: id2)?.state == .queued)

        await queue.startImmediately(id: id2)

        let job1 = await queue.job(id: id1)
        let job2 = await queue.job(id: id2)

        #expect(job1?.isRunning == true)
        #expect(job2?.isRunning == true)
    }

    @Test func reorderQueuedJobs() async {
        let queue = TransferQueue()

        let id1 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/1.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let id2 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/2.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        let id3 = await queue.enqueue(
            kind: .copy,
            sources: [URL(fileURLWithPath: "/vol1/3.txt")],
            destinationDirectory: URL(fileURLWithPath: "/vol1/dst"),
            sourceVolume: "vol1",
            targetVolume: "vol1"
        )

        // Queue order currently: id1 (running), id2 (queued), id3 (queued)
        // Move id3 before id2
        await queue.moveJob(id: id3, toIndex: 1)

        await queue.completeJob(id: id1)

        let job2 = await queue.job(id: id2)
        let job3 = await queue.job(id: id3)

        #expect(job3?.isRunning == true)
        #expect(job2?.state == .queued)
    }
}
