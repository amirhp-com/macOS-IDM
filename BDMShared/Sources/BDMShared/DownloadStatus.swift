import Foundation

/// Download lifecycle states
public enum DownloadStatus: String, Codable, Sendable {
    case queued
    case active
    case paused
    case completed
    case failed
}

/// Per-segment states
public enum SegmentStatus: String, Codable, Sendable {
    case pending
    case active
    case completed
    case failed
}

/// Per-thread states
public enum ThreadStatus: String, Codable, Sendable {
    case idle
    case downloading
    case completed
    case failed
    case cancelled
}

/// Checksum algorithms supported
public enum ChecksumAlgorithm: String, Codable, Sendable {
    case sha256
    case sha512
    case md5
}

/// Progress snapshot sent from XPC service to app
public struct DownloadProgress: Codable, Sendable {
    public let downloadId: UUID
    public let downloadedBytes: Int64
    public let totalBytes: Int64
    public let bytesPerSecond: Double
    public let segmentProgress: [SegmentProgress]

    public init(downloadId: UUID, downloadedBytes: Int64, totalBytes: Int64, bytesPerSecond: Double, segmentProgress: [SegmentProgress]) {
        self.downloadId = downloadId
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
        self.segmentProgress = segmentProgress
    }
}

public struct SegmentProgress: Codable, Sendable {
    public let segmentIndex: Int
    public let downloadedBytes: Int64
    public let totalBytes: Int64
    public let status: SegmentStatus
    public let activeThreads: Int

    public init(segmentIndex: Int, downloadedBytes: Int64, totalBytes: Int64, status: SegmentStatus, activeThreads: Int) {
        self.segmentIndex = segmentIndex
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.status = status
        self.activeThreads = activeThreads
    }
}

/// Result of a HEAD pre-check
public struct HeadCheckResult: Codable, Sendable {
    public let url: URL
    public let fileName: String
    public let totalBytes: Int64
    public let supportsRanges: Bool
    public let mimeType: String?

    public init(url: URL, fileName: String, totalBytes: Int64, supportsRanges: Bool, mimeType: String?) {
        self.url = url
        self.fileName = fileName
        self.totalBytes = totalBytes
        self.supportsRanges = supportsRanges
        self.mimeType = mimeType
    }
}
