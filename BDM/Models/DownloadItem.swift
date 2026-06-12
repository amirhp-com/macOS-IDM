import Foundation
import SwiftData
import BDMShared

@Model
final class DownloadItem {
    @Attribute(.unique) var id: UUID
    var url: String
    var fileName: String
    var destinationPath: String
    var totalBytes: Int64
    var downloadedBytes: Int64
    var status: String // DownloadStatus raw value
    var segmentCount: Int
    var threadsPerSegment: Int
    var createdAt: Date
    var completedAt: Date?
    var duration: TimeInterval?
    var expectedChecksum: String?
    var checksumAlgorithm: String? // ChecksumAlgorithm raw value
    var checksumVerified: Bool?
    var errorMessage: String?
    var retryCount: Int
    var maxRetries: Int
    var priority: Int
    var batchId: UUID?
    var note: String?
    var sourceDomain: String?
    /// JSON-encoded [FinishTask] to run when this download completes.
    var finishTasksData: String?
    /// Optional HTTP Basic auth credentials for protected sources.
    var username: String?
    var password: String?

    @Relationship(deleteRule: .cascade)
    var segments: [DownloadSegment] = []

    init(
        id: UUID = UUID(),
        url: String,
        fileName: String,
        destinationPath: String,
        totalBytes: Int64 = 0,
        segmentCount: Int = 16,
        threadsPerSegment: Int = 4,
        priority: Int = 0
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.destinationPath = destinationPath
        self.totalBytes = totalBytes
        self.downloadedBytes = 0
        self.status = DownloadStatus.queued.rawValue
        self.segmentCount = segmentCount
        self.threadsPerSegment = threadsPerSegment
        self.createdAt = Date()
        self.retryCount = 0
        self.maxRetries = 5
        self.priority = priority
    }

    var downloadStatus: DownloadStatus {
        get { DownloadStatus(rawValue: status) ?? .queued }
        set { status = newValue.rawValue }
    }

    var progressFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }

    var speedFormatted: String {
        "" // Updated by progress polling
    }

    var finishTasks: [FinishTask] {
        get { FinishTask.decode(finishTasksData) }
        set { finishTasksData = FinishTask.encode(newValue) }
    }

    var isActive: Bool { downloadStatus == .active }
    var isCompleted: Bool { downloadStatus == .completed }
    var isFailed: Bool { downloadStatus == .failed }
    var isPaused: Bool { downloadStatus == .paused }
}
