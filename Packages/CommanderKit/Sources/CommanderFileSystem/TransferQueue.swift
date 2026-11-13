import Foundation
import CommanderCore

public actor TransferQueue {
    public private(set) var jobs: [TransferJob] = []
    private let volumeResolver: VolumeResolver

    public init(volumeResolver: VolumeResolver = VolumeResolver()) {
        self.volumeResolver = volumeResolver
    }

    public func job(id: UUID) -> TransferJob? {
        jobs.first { $0.id == id }
    }

    public func allJobs() -> [TransferJob] {
        jobs
    }

    public func enqueue(
        kind: TransferKind,
        sources: [URL],
        destinationDirectory: URL,
        sourceVolume: String? = nil,
        targetVolume: String? = nil
    ) -> UUID {
        let srcVol = sourceVolume ?? sources.first.flatMap { volumeResolver.volumeIdentifier(for: $0) }
        let dstVol = targetVolume ?? volumeResolver.volumeIdentifier(for: destinationDirectory)

        let initialProgress = TransferProgress(
            bytesTransferred: 0,
            totalBytes: 0,
            filesTransferred: 0,
            totalFiles: sources.count,
            currentFileName: sources.first?.lastPathComponent ?? "",
            bytesPerSecond: 0,
            estimatedSecondsRemaining: nil
        )

        var job = TransferJob(
            kind: kind,
            sources: sources,
            destinationDirectory: destinationDirectory,
            sourceVolumeIdentifier: srcVol,
            targetVolumeIdentifier: dstVol,
            state: .queued
        )

        if canStart(job: job) {
            job.state = .running(initialProgress)
        }

        jobs.append(job)
        return job.id
    }

    public func startImmediately(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        guard case .queued = jobs[index].state else { return }

        let initialProgress = TransferProgress(
            bytesTransferred: 0,
            totalBytes: 0,
            filesTransferred: 0,
            totalFiles: jobs[index].sources.count,
            currentFileName: jobs[index].sources.first?.lastPathComponent ?? "",
            bytesPerSecond: 0,
            estimatedSecondsRemaining: nil
        )
        jobs[index].state = .running(initialProgress)
    }

    public func updateProgress(id: UUID, progress: TransferProgress) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        switch jobs[index].state {
        case .running, .queued:
            jobs[index].state = .running(progress)
        case .paused:
            jobs[index].state = .paused(progress)
        case .resolvingConflict, .completed, .failed, .cancelled:
            break
        }
    }

    public func pause(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if case let .running(progress) = jobs[index].state {
            jobs[index].state = .paused(progress)
            scheduleNextPendingJobs()
        }
    }

    public func resume(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if case let .paused(progress) = jobs[index].state {
            jobs[index].state = .running(progress)
        }
    }

    public func cancel(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .cancelled
        scheduleNextPendingJobs()
    }

    public func completeJob(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .completed
        scheduleNextPendingJobs()
    }

    public func failJob(id: UUID, message: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .failed(message)
        scheduleNextPendingJobs()
    }

    public func moveJob(id: UUID, toIndex: Int) {
        guard let currentIndex = jobs.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = max(0, min(toIndex, jobs.count - 1))
        guard currentIndex != targetIndex else { return }

        let job = jobs.remove(at: currentIndex)
        jobs.insert(job, at: targetIndex)
    }

    private func canStart(job: TransferJob) -> Bool {
        let runningJobs = jobs.filter { $0.isRunning }
        guard !runningJobs.isEmpty else { return true }

        let jobTarget = job.targetVolumeIdentifier
        let jobSource = job.sourceVolumeIdentifier

        for running in runningJobs {
            if let target = jobTarget, (running.targetVolumeIdentifier == target || running.sourceVolumeIdentifier == target) {
                return false
            }
            if let source = jobSource, (running.targetVolumeIdentifier == source || running.sourceVolumeIdentifier == source) {
                return false
            }
        }
        return true
    }

    private func scheduleNextPendingJobs() {
        for index in jobs.indices {
            if case .queued = jobs[index].state {
                if canStart(job: jobs[index]) {
                    let initialProgress = TransferProgress(
                        bytesTransferred: 0,
                        totalBytes: 0,
                        filesTransferred: 0,
                        totalFiles: jobs[index].sources.count,
                        currentFileName: jobs[index].sources.first?.lastPathComponent ?? "",
                        bytesPerSecond: 0,
                        estimatedSecondsRemaining: nil
                    )
                    jobs[index].state = .running(initialProgress)
                }
            }
        }
    }
}
