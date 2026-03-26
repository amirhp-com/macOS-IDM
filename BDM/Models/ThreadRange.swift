import Foundation
import SwiftData
import BDMShared

@Model
final class DownloadThreadRange {
    @Attribute(.unique) var id: UUID
    var threadIndex: Int
    var startByte: Int64
    var endByte: Int64
    var currentByte: Int64 // resume point
    var status: String // ThreadStatus raw value
    var bytesPerSecond: Double

    @Relationship(inverse: \DownloadSegment.threadRanges)
    var segment: DownloadSegment?

    init(
        id: UUID = UUID(),
        threadIndex: Int,
        startByte: Int64,
        endByte: Int64
    ) {
        self.id = id
        self.threadIndex = threadIndex
        self.startByte = startByte
        self.endByte = endByte
        self.currentByte = startByte
        self.status = ThreadStatus.idle.rawValue
        self.bytesPerSecond = 0
    }
}
