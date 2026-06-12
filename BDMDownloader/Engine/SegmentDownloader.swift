import Foundation
import BDMShared

/// Limits concurrent connections per host (0 = unlimited).
actor HostGate {
    private var limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        if limit <= 0 || active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
        // `active` was incremented by the waker on our behalf
    }

    func release() {
        active -= 1
        wake()
    }

    func setLimit(_ newLimit: Int) {
        limit = newLimit
        wake()
    }

    private func wake() {
        while !waiters.isEmpty, limit <= 0 || active < limit {
            active += 1
            waiters.removeFirst().resume()
        }
    }
}

/// Downloads a single segment using multiple threads (sub-range tasks).
/// Each thread downloads a portion of the segment and writes directly to the
/// sparse file. Supports resuming: pass the bytes already completed per thread.
actor SegmentDownloader {
    let segment: SegmentPlan
    let url: URL
    let fileWriter: SparseFileWriter
    let bandwidthLimiter: BandwidthLimiter
    let hostGate: HostGate?
    let authorization: String?

    private(set) var downloadedBytes: Int64 = 0
    private(set) var status: SegmentStatus = .pending
    private(set) var activeThreadCount: Int = 0

    /// Contiguous bytes completed per thread index (writes are sequential
    /// within a thread range, so a single offset fully describes progress).
    private var threadDone: [Int: Int64] = [:]

    init(
        segment: SegmentPlan,
        url: URL,
        fileWriter: SparseFileWriter,
        bandwidthLimiter: BandwidthLimiter,
        hostGate: HostGate? = nil,
        authorization: String? = nil,
        resumedProgress: [Int: Int64] = [:]
    ) {
        self.segment = segment
        self.url = url
        self.fileWriter = fileWriter
        self.bandwidthLimiter = bandwidthLimiter
        self.hostGate = hostGate
        self.authorization = authorization
        self.threadDone = resumedProgress
        self.downloadedBytes = resumedProgress.values.reduce(0, +)
    }

    /// Snapshot of per-thread progress, for resume-state persistence.
    func progressSnapshot() -> [Int: Int64] {
        threadDone
    }

    /// Start downloading all thread sub-ranges in parallel.
    func download() async throws {
        status = .active
        let planner = SegmentPlanner()
        let ranges = planner.threadRanges(for: segment)

        // downloadedBytes/threadDone update live as chunks land
        try await withThrowingTaskGroup(of: Void.self) { group in
            for range in ranges {
                group.addTask {
                    try await self.downloadThreadRange(range)
                }
            }
            try await group.waitForAll()
        }

        status = .completed
    }

    /// Download a single thread's sub-range with a Range header, continuing
    /// from any previously completed bytes.
    private func downloadThreadRange(_ range: ThreadRangePlan) async throws {
        let alreadyDone = threadDone[range.threadIndex] ?? 0
        if alreadyDone >= range.totalBytes { return }
        let startAt = range.startByte + alreadyDone

        await hostGate?.acquire()
        defer {
            if let hostGate {
                Task { await hostGate.release() }
            }
        }

        await incrementThreadCount()
        defer { Task { await decrementThreadCount() } }

        var request = URLRequest(url: url)
        request.setValue("bytes=\(startAt)-\(range.endByte)", forHTTPHeaderField: "Range")
        request.timeoutInterval = 30
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw SegmentDownloaderError.httpError
        }

        var currentOffset = startAt
        var buffer = Data()
        let flushThreshold = 256 * 1024 // 256 KB buffer before write

        for try await byte in asyncBytes {
            buffer.append(byte)

            if buffer.count >= flushThreshold {
                // Apply bandwidth limiting
                let granted = await bandwidthLimiter.acquire(Int64(buffer.count))
                if granted < Int64(buffer.count) {
                    // Write only what was granted, keep the rest
                    let grantedCount = Int(granted)
                    try await fileWriter.write(Data(buffer.prefix(grantedCount)), at: currentOffset)
                    currentOffset += Int64(grantedCount)
                    downloadedBytes += Int64(grantedCount)
                    threadDone[range.threadIndex, default: 0] += Int64(grantedCount)
                    buffer = Data(buffer.dropFirst(grantedCount))
                } else {
                    try await fileWriter.write(buffer, at: currentOffset)
                    currentOffset += Int64(buffer.count)
                    downloadedBytes += Int64(buffer.count)
                    threadDone[range.threadIndex, default: 0] += Int64(buffer.count)
                    buffer = Data()
                }
            }
        }

        // Flush remaining buffer
        if !buffer.isEmpty {
            _ = await bandwidthLimiter.acquire(Int64(buffer.count))
            try await fileWriter.write(buffer, at: currentOffset)
            downloadedBytes += Int64(buffer.count)
            threadDone[range.threadIndex, default: 0] += Int64(buffer.count)
        }
    }

    private func incrementThreadCount() {
        activeThreadCount += 1
    }

    private func decrementThreadCount() {
        activeThreadCount -= 1
    }

    func progress() -> SegmentProgress {
        SegmentProgress(
            segmentIndex: segment.index,
            downloadedBytes: downloadedBytes,
            totalBytes: segment.totalBytes,
            status: status,
            activeThreads: activeThreadCount
        )
    }
}

enum SegmentDownloaderError: Error, LocalizedError {
    case httpError
    case cancelled

    var errorDescription: String? {
        switch self {
        case .httpError: return "HTTP error during segment download"
        case .cancelled: return "Segment download was cancelled"
        }
    }
}
