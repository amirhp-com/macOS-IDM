import Foundation
import BDMShared

/// Performs HEAD check and splits a file into segments with thread sub-ranges.
struct SegmentPlanner: Sendable {

    /// Performs a HEAD request to determine file size and range support.
    func headCheck(url: URL) async throws -> HeadCheckResult {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SegmentPlannerError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw SegmentPlannerError.httpError(http.statusCode)
        }

        let totalBytes = Int64(http.expectedContentLength)
        let acceptRanges = http.value(forHTTPHeaderField: "Accept-Ranges")
        let supportsRanges = acceptRanges?.lowercased() == "bytes" && totalBytes > 0
        let mimeType = http.value(forHTTPHeaderField: "Content-Type")
        let fileName = Self.extractFileName(from: url, response: http)

        return HeadCheckResult(
            url: url,
            fileName: fileName,
            totalBytes: totalBytes,
            supportsRanges: supportsRanges,
            mimeType: mimeType
        )
    }

    /// Splits a file into N segments. Each segment gets a specified number of threads.
    func plan(totalBytes: Int64, segmentCount: Int, threadsPerSegment: Int) -> [SegmentPlan] {
        guard totalBytes > 0, segmentCount > 0 else { return [] }

        let effectiveSegments = min(segmentCount, Int(totalBytes))
        let segmentSize = totalBytes / Int64(effectiveSegments)
        var segments: [SegmentPlan] = []

        for i in 0..<effectiveSegments {
            let start = Int64(i) * segmentSize
            let end: Int64
            if i == effectiveSegments - 1 {
                end = totalBytes - 1
            } else {
                end = start + segmentSize - 1
            }

            let segBytes = end - start + 1
            let threads = Self.autoThreadCount(segmentBytes: segBytes, requested: threadsPerSegment)

            segments.append(SegmentPlan(
                index: i,
                startByte: start,
                endByte: end,
                threadsPerSegment: threads
            ))
        }

        return segments
    }

    /// Splits a segment into thread sub-ranges.
    func threadRanges(for segment: SegmentPlan) -> [ThreadRangePlan] {
        let total = segment.totalBytes
        let count = segment.threadsPerSegment
        guard total > 0, count > 0 else { return [] }

        let chunkSize = total / Int64(count)
        var ranges: [ThreadRangePlan] = []

        for t in 0..<count {
            let start = segment.startByte + Int64(t) * chunkSize
            let end: Int64
            if t == count - 1 {
                end = segment.endByte
            } else {
                end = start + chunkSize - 1
            }

            ranges.append(ThreadRangePlan(threadIndex: t, startByte: start, endByte: end))
        }

        return ranges
    }

    /// Auto-tune thread count based on segment size.
    /// < 50 MB → 2 threads, 50-200 MB → 3 threads, > 200 MB → 4 threads
    private static func autoThreadCount(segmentBytes: Int64, requested: Int) -> Int {
        if requested > 0 && requested <= 4 { return requested }
        let mb = segmentBytes / (1024 * 1024)
        if mb < 50 { return 2 }
        if mb < 200 { return 3 }
        return 4
    }

    private static func extractFileName(from url: URL, response: HTTPURLResponse) -> String {
        // Try Content-Disposition header first
        if let disposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           let range = disposition.range(of: "filename=") {
            var name = String(disposition[range.upperBound...])
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ;"))
            if !name.isEmpty { return name }
        }
        // Fall back to URL last path component
        let component = url.lastPathComponent
        return component.isEmpty ? "download" : component
    }
}

enum SegmentPlannerError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case noRangeSupport

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "HTTP error \(code)"
        case .noRangeSupport: return "Server does not support range requests"
        }
    }
}
