import Foundation
import BDMShared

/// Events pushed from the engine to the XPC layer (and on to the app).
enum EngineEvent: Sendable {
    case completed(id: UUID, path: String)
    case failed(id: UUID, error: String)
}

/// Sidecar state persisted next to the partial file so a paused or
/// interrupted download can resume where it left off.
struct DownloadResumeState: Codable {
    let url: String
    let totalBytes: Int64
    let segments: [SegmentPlan]
    /// segmentIndex → (threadIndex → contiguous bytes done)
    var threadProgress: [Int: [Int: Int64]]
}

/// The main download engine actor. Orchestrates all downloads, manages the queue,
/// and coordinates segment downloaders.
actor DownloadEngine {
    private var activeDownloads: [UUID: ActiveDownload] = [:]
    private var queue: [QueuedDownload] = []
    private let bandwidthLimiter = BandwidthLimiter()
    private var eventHandler: (@Sendable (EngineEvent) -> Void)?
    private var hostGates: [String: HostGate] = [:]
    private var perDomainLimit: Int = 4

    var maxConcurrentDownloads: Int = 3

    func setEventHandler(_ handler: @escaping @Sendable (EngineEvent) -> Void) {
        eventHandler = handler
    }

    func setMaxConcurrent(_ count: Int) async {
        maxConcurrentDownloads = max(1, count)
        await processQueue()
    }

    func setPerDomainLimit(_ limit: Int) async {
        perDomainLimit = limit
        for gate in hostGates.values {
            await gate.setLimit(limit)
        }
    }

    private func gate(for url: URL) -> HostGate {
        let host = url.host ?? ""
        if let existing = hostGates[host] { return existing }
        let gate = HostGate(limit: perDomainLimit)
        hostGates[host] = gate
        return gate
    }

    struct QueuedDownload: Sendable {
        let id: UUID
        let url: URL
        let destinationPath: String
        let segmentCount: Int
        let threadsPerSegment: Int
        let username: String?
        let password: String?

        var isFTP: Bool { url.scheme?.lowercased() == "ftp" }
        var authorization: String? { HTTPAuth.basicHeader(username: username, password: password) }
    }

    struct ActiveDownload {
        let id: UUID
        let url: URL
        let destinationPath: String
        let partialPath: String
        let statePath: String
        let fileWriter: SparseFileWriter
        let segmentDownloaders: [any SegmentDownloading]
        let segments: [SegmentPlan]
        let task: Task<Void, Error>
        let stateSaver: Task<Void, Never>
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
        threadsPerSegment: Int,
        username: String? = nil,
        password: String? = nil
    ) async {
        guard activeDownloads[id] == nil, !queue.contains(where: { $0.id == id }) else { return }
        let queued = QueuedDownload(
            id: id,
            url: url,
            destinationPath: destinationPath,
            segmentCount: segmentCount,
            threadsPerSegment: threadsPerSegment,
            username: username,
            password: password
        )
        queue.append(queued)
        await processQueue()
    }

    /// Pause a download, persisting resume state.
    func pause(id: UUID) async {
        guard let active = activeDownloads[id] else {
            queue.removeAll { $0.id == id }
            return
        }
        active.stateSaver.cancel()
        active.task.cancel()
        _ = try? await active.task.value
        await saveState(for: active)
        await active.fileWriter.closeFile()
        activeDownloads.removeValue(forKey: id)
        await processQueue()
    }

    /// Cancel a download and optionally delete the partial file and state.
    func cancel(id: UUID, deleteFile: Bool) async {
        if let active = activeDownloads[id] {
            active.stateSaver.cancel()
            active.task.cancel()
            _ = try? await active.task.value
            if deleteFile {
                try? FileManager.default.removeItem(atPath: active.partialPath)
                try? FileManager.default.removeItem(atPath: active.statePath)
            } else {
                await saveState(for: active)
            }
            await active.fileWriter.closeFile()
            if deleteFile {
                // Remove again in case a final flush re-created it
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
            bytesPerSecond: 0, // measured app-side from polling deltas
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

            // Determine size and resumability per protocol
            let totalBytes: Int64
            let supportsResume: Bool
            if queued.isFTP {
                let client = FTPClient(host: queued.url.host ?? "", port: UInt16(queued.url.port ?? 21))
                try await client.connect(
                    username: queued.url.user ?? queued.username ?? "anonymous",
                    password: queued.url.password ?? queued.password ?? "bdm@example.com"
                )
                totalBytes = try await client.size(of: queued.url.path)
                await client.disconnect()
                supportsResume = true // REST
            } else {
                let headResult = try await planner.headCheck(url: queued.url, authorization: queued.authorization)
                totalBytes = headResult.totalBytes
                supportsResume = headResult.supportsRanges
            }

            let partialPath = queued.destinationPath + ".bdm-partial"
            let statePath = queued.destinationPath + ".bdm-state"

            var segments: [SegmentPlan]
            var resumedProgress: [Int: [Int: Int64]] = [:]

            // Resume if a matching partial + state pair exists
            if supportsResume,
               FileManager.default.fileExists(atPath: partialPath),
               let data = FileManager.default.contents(atPath: statePath),
               let state = try? JSONDecoder().decode(DownloadResumeState.self, from: data),
               state.url == queued.url.absoluteString,
               state.totalBytes == totalBytes {
                segments = state.segments
                resumedProgress = state.threadProgress
            } else if queued.isFTP || !supportsResume {
                // FTP: one connection. HTTP without ranges: one segment/thread.
                segments = planner.plan(totalBytes: totalBytes, segmentCount: 1, threadsPerSegment: 1)
            } else {
                segments = planner.plan(
                    totalBytes: totalBytes,
                    segmentCount: queued.segmentCount,
                    threadsPerSegment: queued.threadsPerSegment
                )
            }

            let fileWriter = try SparseFileWriter(path: partialPath, totalBytes: totalBytes)
            let hostGate = gate(for: queued.url)

            let segmentDownloaders: [any SegmentDownloading] = segments.map { seg in
                if queued.isFTP {
                    return FTPSegmentDownloader(
                        segment: seg,
                        url: queued.url,
                        fileWriter: fileWriter,
                        bandwidthLimiter: bandwidthLimiter,
                        username: queued.username,
                        password: queued.password,
                        resumedProgress: resumedProgress[seg.index] ?? [:]
                    )
                }
                return SegmentDownloader(
                    segment: seg,
                    url: queued.url,
                    fileWriter: fileWriter,
                    bandwidthLimiter: bandwidthLimiter,
                    hostGate: hostGate,
                    authorization: queued.authorization,
                    resumedProgress: resumedProgress[seg.index] ?? [:]
                )
            }

            let task = Task {
                do {
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
                    try? FileManager.default.removeItem(atPath: statePath)
                    await self.downloadCompleted(id: queued.id, path: queued.destinationPath)
                } catch {
                    // Pause/cancel cancels this task — only report real failures
                    if !(error is CancellationError) && !Task.isCancelled {
                        await self.saveStateIfActive(id: queued.id)
                        await fileWriter.closeFile()
                        await self.downloadFailed(id: queued.id, error: error)
                    }
                    throw error
                }
            }

            // Persist resume state every 2 seconds while downloading
            let stateSaver = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    if Task.isCancelled { break }
                    await self?.saveStateIfActive(id: queued.id)
                }
            }

            activeDownloads[queued.id] = ActiveDownload(
                id: queued.id,
                url: queued.url,
                destinationPath: queued.destinationPath,
                partialPath: partialPath,
                statePath: statePath,
                fileWriter: fileWriter,
                segmentDownloaders: segmentDownloaders,
                segments: segments,
                task: task,
                stateSaver: stateSaver,
                totalBytes: totalBytes
            )
        } catch {
            // HEAD check or file allocation failed
            await downloadFailed(id: queued.id, error: error)
        }
    }

    private func saveStateIfActive(id: UUID) async {
        guard let active = activeDownloads[id] else { return }
        await saveState(for: active)
    }

    private func saveState(for active: ActiveDownload) async {
        var threadProgress: [Int: [Int: Int64]] = [:]
        for downloader in active.segmentDownloaders {
            let snapshot = await downloader.progressSnapshot()
            threadProgress[downloader.segment.index] = snapshot
        }
        let state = DownloadResumeState(
            url: active.url.absoluteString,
            totalBytes: active.totalBytes,
            segments: active.segments,
            threadProgress: threadProgress
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: URL(fileURLWithPath: active.statePath), options: .atomic)
        }
    }

    private func downloadCompleted(id: UUID, path: String) async {
        activeDownloads[id]?.stateSaver.cancel()
        activeDownloads.removeValue(forKey: id)
        eventHandler?(.completed(id: id, path: path))
        await processQueue()
    }

    private func downloadFailed(id: UUID, error: Error) async {
        activeDownloads[id]?.stateSaver.cancel()
        activeDownloads.removeValue(forKey: id)
        eventHandler?(.failed(id: id, error: error.localizedDescription))
        await processQueue()
    }
}

// Extension for bandwidth limiter to support setLimit
extension BandwidthLimiter {
    func setLimit(_ bps: Int64) {
        self.bytesPerSecond = bps
    }
}
