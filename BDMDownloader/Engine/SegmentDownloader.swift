import Foundation
import BDMShared

/// Downloads a single segment using multiple threads (sub-range tasks).
/// Each thread downloads a portion of the segment and writes directly to the sparse file.
actor SegmentDownloader {
    let segment: SegmentPlan
    let url: URL
    let fileWriter: SparseFileWriter
    let bandwidthLimiter: BandwidthLimiter

    private(set) var downloadedBytes: Int64 = 0
    private(set) var status: SegmentStatus = .pending
    private(set) var activeThreadCount: Int = 0

    // Per-thread tracking for adaptive rebalancing
    private var threadBytesPerSecond: [Int: Double] = [:]

    init(segment: SegmentPlan, url: URL, fileWriter: SparseFileWriter, bandwidthLimiter: BandwidthLimiter) {
        self.segment = segment
        self.url = url
        self.fileWriter = fileWriter
        self.bandwidthLimiter = bandwidthLimiter
    }

    /// Start downloading all thread sub-ranges in parallel.
    func download() async throws {
        status = .active
        let planner = SegmentPlanner()
        let ranges = planner.threadRanges(for: segment)

        try await withThrowingTaskGroup(of: Int64.self) { group in
            for range in ranges {
                group.addTask {
                    try await self.downloadThreadRange(range)
                }
            }

            for try await bytesFromThread in group {
                downloadedBytes += bytesFromThread
            }
        }

        status = .completed
    }

    /// Download a single thread's sub-range with Range header.
    private func downloadThreadRange(_ range: ThreadRangePlan) async throws -> Int64 {
        await incrementThreadCount()

        defer { Task { await decrementThreadCount() } }

        var request = URLRequest(url: url)
        request.setValue("bytes=\(range.startByte)-\(range.endByte)", forHTTPHeaderField: "Range")
        request.timeoutInterval = 30

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw SegmentDownloaderError.httpError
        }

        var currentOffset = range.startByte
        var totalBytesRead: Int64 = 0
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
                    let toWrite = buffer.prefix(grantedCount)
                    try await fileWriter.write(Data(toWrite), at: currentOffset)
                    currentOffset += Int64(grantedCount)
                    totalBytesRead += Int64(grantedCount)
                    buffer = Data(buffer.dropFirst(grantedCount))
                } else {
                    try await fileWriter.write(buffer, at: currentOffset)
                    currentOffset += Int64(buffer.count)
                    totalBytesRead += Int64(buffer.count)
                    buffer = Data()
                }
            }
        }

        // Flush remaining buffer
        if !buffer.isEmpty {
            _ = await bandwidthLimiter.acquire(Int64(buffer.count))
            try await fileWriter.write(buffer, at: currentOffset)
            totalBytesRead += Int64(buffer.count)
        }

        return totalBytesRead
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
