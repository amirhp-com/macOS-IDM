import Foundation
import BDMShared

/// Common interface for per-segment transfer workers (HTTP and FTP).
protocol SegmentDownloading: Actor {
    nonisolated var segment: SegmentPlan { get }
    func download() async throws
    func progress() -> SegmentProgress
    func progressSnapshot() -> [Int: Int64]
}

extension SegmentDownloader: SegmentDownloading {}

/// Single-connection FTP transfer with REST-based resume.
actor FTPSegmentDownloader: SegmentDownloading {
    nonisolated let segment: SegmentPlan
    let url: URL
    let fileWriter: SparseFileWriter
    let bandwidthLimiter: BandwidthLimiter
    let username: String?
    let password: String?

    private(set) var downloadedBytes: Int64 = 0
    private(set) var status: SegmentStatus = .pending
    private var currentOffset: Int64
    private var threadDone: [Int: Int64]

    init(
        segment: SegmentPlan,
        url: URL,
        fileWriter: SparseFileWriter,
        bandwidthLimiter: BandwidthLimiter,
        username: String?,
        password: String?,
        resumedProgress: [Int: Int64] = [:]
    ) {
        self.segment = segment
        self.url = url
        self.fileWriter = fileWriter
        self.bandwidthLimiter = bandwidthLimiter
        // URL userinfo (ftp://user:pass@host/…) wins over explicit credentials
        self.username = url.user ?? username
        self.password = url.password ?? password
        self.threadDone = resumedProgress
        let done = resumedProgress[0] ?? 0
        self.downloadedBytes = done
        self.currentOffset = segment.startByte + done
    }

    func progressSnapshot() -> [Int: Int64] {
        threadDone
    }

    func progress() -> SegmentProgress {
        SegmentProgress(
            segmentIndex: segment.index,
            downloadedBytes: downloadedBytes,
            totalBytes: segment.totalBytes,
            status: status,
            activeThreads: status == .active ? 1 : 0
        )
    }

    func download() async throws {
        let alreadyDone = threadDone[0] ?? 0
        if alreadyDone >= segment.totalBytes {
            status = .completed
            return
        }

        status = .active
        let client = FTPClient(host: url.host ?? "", port: UInt16(url.port ?? 21))
        try await client.connect(
            username: username ?? "anonymous",
            password: password ?? "bdm@example.com"
        )
        defer { Task { await client.disconnect() } }

        try await client.download(url.path, offset: alreadyDone) { [weak self] chunk in
            guard let self else { throw FTPError.cancelled }
            _ = await self.bandwidthLimiter.acquire(Int64(chunk.count))
            try await self.consume(chunk)
        }

        status = .completed
    }

    private func consume(_ chunk: Data) async throws {
        try await fileWriter.write(chunk, at: currentOffset)
        currentOffset += Int64(chunk.count)
        downloadedBytes += Int64(chunk.count)
        threadDone[0, default: 0] += Int64(chunk.count)
    }
}
