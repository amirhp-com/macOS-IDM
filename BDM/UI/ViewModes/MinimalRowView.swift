import SwiftUI

struct MinimalRowView: View {
    let download: DownloadItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            // File name
            Text(download.fileName)
                .font(.system(.caption))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Mini progress bar
            ProgressView(value: download.progressFraction)
                .tint(statusColor)
                .frame(width: 80)

            // Percentage
            Text("\(Int(download.progressFraction * 100))%")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? BDMColors.accent.opacity(0.12) : .clear)
    }

    private var statusColor: Color {
        switch download.downloadStatus {
        case .active: return BDMColors.accent
        case .completed: return BDMColors.green
        case .failed: return BDMColors.red
        case .paused: return BDMColors.yellow
        case .queued: return BDMColors.muted2
        }
    }
}
