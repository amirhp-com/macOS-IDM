import SwiftUI

struct CompactRowView: View {
    let download: DownloadItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            // File icon (small)
            Text(fileIcon)
                .font(.callout)

            // File name
            Text(download.fileName)
                .font(.system(.caption, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            ProgressView(value: download.progressFraction)
                .tint(statusColor)
                .frame(width: 120)

            // Percentage
            Text("\(Int(download.progressFraction * 100))%")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 40, alignment: .trailing)

            // Speed
            Text(speedText)
                .font(.caption)
                .foregroundStyle(statusColor)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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

    private var speedText: String {
        switch download.downloadStatus {
        case .active: return "-- MB/s"
        case .completed: return "Done"
        case .failed: return "Retry…"
        case .paused: return "Paused"
        case .queued: return "Queued"
        }
    }

    private var fileIcon: String {
        let ext = (download.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "dmg", "iso", "ipsw", "img": return "💿"
        case "zip", "xip", "tar", "gz", "rar", "7z": return "📦"
        case "pkg", "app": return "🖥"
        case "mp3", "flac", "aac", "wav": return "🎵"
        default: return "📄"
        }
    }
}
