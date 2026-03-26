import Foundation
import BDMShared

/// The main download engine actor. Orchestrates all downloads, manages the queue,
/// and coordinates segment downloaders.
actor DownloadEngine {
    private var activeDownloads: [UUID: ActiveDownload] = [:]
    private var queue: [QueuedDownload] = []
    private let bandwidthLimiter = BandwidthLimiter()

    var maxConcurrentDownloads: Int = 3

    struct QueuedDownload: Sendable {
        let id: UUID
        let url: URL
        let destinationPath: String
        let segmentCount: Int
        let threadsPerSegment: Int
    }

    struct ActiveDownload {
        let id: UUID
        let url: URL
        let destinationPath: String
        let partialPath: String
        let fileWriter: SparseFileWriter
        let segmentDownloaders: [SegmentDownloader]
        let task: Task<Void, Error>
        let totalBytes: Int64
    }

    /// Perform HEAD check on a URL.
    func headCheck(url: URL) async throws -> HeadCheckResult {
        try await SegmentPlanner().headCheck(url: url)
    }

    /// Add a download to the queue and start if slots are available.
    func addDownload(
        id: UUID,
        url: URL,
        destinationPath: String,
        segmentCount: Int,
        threadsPerSegment: Int
    ) async {
        let queued = QueuedDownload(
            id: id,
            url: url,
            destinationPath: destinationPath,
            segmentCount: segmentCount,
            threadsPerSegment: threadsPerSegment
        )
        queue.append(queued)
        await processQueue()
    }

    /// Pause a download.
    func pause(id: UUID) {
        guard let active = activeDownloads[id] else { return }
        active.task.cancel()
        activeDownloads.removeValue(forKey: id)
    }

    /// Cancel a download and optionally delete the partial file.
    func cancel(id: UUID, deleteFile: Bool) async {
        if let active = activeDownloads[id] {
            active.task.cancel()
            await active.fileWriter.closeFile()
            if deleteFile {
                try? FileManager.default.removeItem(atPath: active.partialPath)
            }
            activeDownloads.removeValue(forKey: id)
        }
        queue.removeAll { $0.id == id }
        await processQueue()
    }

    /// Get progress for a specific download.
    func progress(for id: UUID) async -> DownloadProgress? {
        guard let active = activeDownloads[id] else { return nil }

        var segmentProgress: [SegmentProgress] = []
        var totalDownloaded: Int64 = 0

        for downloader in active.segmentDownloaders {
            let sp = await downloader.progress()
            segmentProgress.append(sp)
            totalDownloaded += sp.downloadedBytes
        }

        return DownloadProgress(
            downloadId: id,
            downloadedBytes: totalDownloaded,
            totalBytes: active.totalBytes,
            bytesPerSecond: 0, // TODO: measure over time
            segmentProgress: segmentProgress
        )
    }

    /// Set global speed limit (0 = unlimited).
    func setSpeedLimit(bytesPerSecond: Int64) async {
        await bandwidthLimiter.setLimit(bytesPerSecond)
    }

    // MARK: - Private

    private func processQueue() async {
        while activeDownloads.count < maxConcurrentDownloads, !queue.isEmpty {
            let queued = queue.removeFirst()
            await startDownload(queued)
        }
    }

    private func startDownload(_ queued: QueuedDownload) async {
        do {
            let planner = SegmentPlanner()
            let headResult = try await planner.headCheck(url: queued.url)

            let partialPath = queued.destinationPath + ".bdm-partial"
            let segments: [SegmentPlan]

            if headResult.supportsRanges {
                segments = planner.plan(
                    totalBytes: headResult.totalBytes,
                    segmentCount: queued.segmentCount,
                    threadsPerSegment: queued.threadsPerSegment
                )
            } else {
                // No range support: single segment, single thread
                segments = planner.plan(
                    totalBytes: headResult.totalBytes,
                    segmentCount: 1,
                    threadsPerSegment: 1
                )
            }

            let fileWriter = try SparseFileWriter(path: partialPath, totalBytes: headResult.totalBytes)

            let segmentDownloaders = segments.map { seg in
                SegmentDownloader(
                    segment: seg,
                    url: queued.url,
                    fileWriter: fileWriter,
                    bandwidthLimiter: bandwidthLimiter
                )
            }

            let task = Task {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for downloader in segmentDownloaders {
                        group.addTask {
                            try await downloader.download()
                        }
                    }
                    try await group.waitForAll()
                }

                // All segments complete — finalize
                try await fileWriter.finalize(as: queued.destinationPath)
                await self.downloadCompleted(id: queued.id)
            }

            activeDownloads[queued.id] = ActiveDownload(
                id: queued.id,
                url: queued.url,
                destinationPath: queued.destinationPath,
                partialPath: partialPath,
                fileWriter: fileWriter,
                segmentDownloaders: segmentDownloaders,
                task: task,
                totalBytes: headResult.totalBytes
            )
        } catch {
            // HEAD check or file allocation failed
            await downloadFailed(id: queued.id, error: error)
        }
    }

    private func downloadCompleted(id: UUID) async {
        activeDownloads.removeValue(forKey: id)
        await processQueue()
    }

    private func downloadFailed(id: UUID, error: Error) async {
        activeDownloads.removeValue(forKey: id)
        await processQueue()
    }
}

// Extension for bandwidth limiter to support setLimit
extension BandwidthLimiter {
    func setLimit(_ bps: Int64) {
        self.bytesPerSecond = bps
    }
}
