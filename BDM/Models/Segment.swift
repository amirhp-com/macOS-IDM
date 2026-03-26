import Foundation
import SwiftData
import BDMShared

@Model
final class DownloadSegment {
    @Attribute(.unique) var id: UUID
    var segmentIndex: Int
    var startByte: Int64
    var endByte: Int64
    var downloadedBytes: Int64
    var status: String // SegmentStatus raw value

    @Relationship(deleteRule: .cascade)
    var threadRanges: [DownloadThreadRange] = []

    @Relationship(inverse: \DownloadItem.segments)
    var download: DownloadItem?

    init(
        id: UUID = UUID(),
        segmentIndex: Int,
        startByte: Int64,
        endByte: Int64
    ) {
        self.id = id
        self.segmentIndex = segmentIndex
        self.startByte = startByte
        self.endByte = endByte
        self.downloadedBytes = 0
        self.status = SegmentStatus.pending.rawValue
    }

    var segmentStatus: SegmentStatus {
        get { SegmentStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var totalBytes: Int64 { endByte - startByte + 1 }

    var progressFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }
}
