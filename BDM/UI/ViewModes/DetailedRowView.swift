import SwiftUI

struct DetailedRowView: View {
    let download: DownloadItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            // File icon
            Text(fileIcon)
                .font(.title2)

            // Meta
            VStack(alignment: .leading, spacing: 2) {
                Text(download.fileName)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(BDMColors.muted)
                    .lineLimit(1)

                Text(download.destinationPath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(BDMColors.muted2)
                    .lineLimit(1)

                // Segment visualization
                if download.isActive, !download.segments.isEmpty {
                    SegmentMapView(segments: download.segments)
                        .frame(height: 3)
                } else {
                    ProgressView(value: download.progressFraction)
                        .tint(progressColor)
                }
            }

            Spacer(minLength: 8)

            // Speed + size
            VStack(alignment: .trailing, spacing: 2) {
                Text(speedText)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Text(sizeText)
                    .font(.caption2)
                    .foregroundStyle(BDMColors.muted2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? BDMColors.accent.opacity(0.12) : .clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(BDMColors.accent)
                    .frame(width: 2)
            }
        }
    }

    private var subtitle: String {
        let size = ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file)
        let domain = URL(string: download.url)?.host ?? ""
        switch download.downloadStatus {
        case .active:
            return "\(size) · \(domain) · \(download.segmentCount) seg × \(download.threadsPerSegment) threads"
        case .completed:
            let timeStr = download.duration.map { formatDuration($0) } ?? ""
            return "\(size) · \(domain) · \(timeStr)"
        case .failed:
            return download.errorMessage ?? "Download failed"
        case .paused:
            return "\(size) · Paused at \(Int(download.progressFraction * 100))%"
        case .queued:
            return "\(size) · \(domain) · Queued"
        }
    }

    private var speedText: String {
        switch download.downloadStatus {
        case .active: return "↓ --" // Updated by progress polling
        case .completed: return "Complete"
        case .failed: return "Failed"
        case .paused: return "Paused"
        case .queued: return "Queued"
        }
    }

    private var sizeText: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: download.downloadedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file)
        if download.isCompleted { return total }
        return "\(downloaded) / \(total)"
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

    private var progressColor: Color { statusColor }

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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
