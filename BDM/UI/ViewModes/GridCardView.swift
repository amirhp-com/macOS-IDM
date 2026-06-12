import SwiftUI

/// Card presentation for the Grid view mode.
struct GridCardView: View {
    let download: DownloadItem
    let isSelected: Bool

    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(fileIcon)
                    .font(.system(size: 28))
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }

            Text(download.fileName)
                .font(.system(.caption, weight: .medium))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            ProgressView(value: download.progressFraction)
                .tint(statusColor)

            HStack {
                Text(sizeText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(trailingText)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(10)
        .background(isSelected ? BDMColors.accent.opacity(0.16) : BDMColors.surface2.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? BDMColors.accent : BDMColors.border, lineWidth: 1)
        )
    }

    private var sizeText: String {
        ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file)
    }

    private var trailingText: String {
        switch download.downloadStatus {
        case .active: return downloadManager.formattedSpeed(for: download.id) ?? "\(Int(download.progressFraction * 100))%"
        case .completed: return loc.t("status.completed")
        case .failed: return loc.t("status.failed")
        case .paused: return loc.t("status.paused")
        case .queued: return loc.t("status.queued")
        }
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

    private var fileIcon: String {
        let ext = (download.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "dmg", "iso", "ipsw", "img": return "💿"
        case "zip", "xip", "tar", "gz", "rar", "7z": return "📦"
        case "pkg", "app": return "🖥"
        case "mp3", "flac", "aac", "wav": return "🎵"
        case "pdf", "doc", "docx", "txt": return "📄"
        default: return "📁"
        }
    }
}
