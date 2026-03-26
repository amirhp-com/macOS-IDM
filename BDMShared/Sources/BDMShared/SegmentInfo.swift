import Foundation

/// Describes one segment's byte range within a file
public struct SegmentPlan: Codable, Sendable {
    public let index: Int
    public let startByte: Int64
    public let endByte: Int64
    public let threadsPerSegment: Int

    public var totalBytes: Int64 { endByte - startByte + 1 }

    public init(index: Int, startByte: Int64, endByte: Int64, threadsPerSegment: Int) {
        self.index = index
        self.startByte = startByte
        self.endByte = endByte
        self.threadsPerSegment = threadsPerSegment
    }
}

/// Describes one thread's sub-range within a segment
public struct ThreadRangePlan: Codable, Sendable {
    public let threadIndex: Int
    public let startByte: Int64
    public let endByte: Int64

    public var totalBytes: Int64 { endByte - startByte + 1 }

    public init(threadIndex: Int, startByte: Int64, endByte: Int64) {
        self.threadIndex = threadIndex
        self.startByte = startByte
        self.endByte = endByte
    }
}
