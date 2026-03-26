import SwiftUI
import BDMShared

/// Visual grid showing per-segment progress.
struct SegmentMapView: View {
    let segments: [DownloadSegment]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(segments.sorted(by: { $0.segmentIndex < $1.segmentIndex })) { segment in
                RoundedRectangle(cornerRadius: 1)
                    .fill(segmentColor(segment))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 3)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func segmentColor(_ segment: DownloadSegment) -> Color {
        switch segment.segmentStatus {
        case .completed: return BDMColors.green
        case .active: return BDMColors.accent
        case .failed: return BDMColors.red
        case .pending:
            if segment.downloadedBytes > 0 {
                return BDMColors.accent.opacity(0.4)
            }
            return BDMColors.border
        }
    }
}
