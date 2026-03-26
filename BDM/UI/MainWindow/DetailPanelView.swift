import SwiftUI

struct DetailPanelView: View {
    let download: DownloadItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(download.fileName)
                    .font(.headline)
                    .lineLimit(2)

                // Info rows
                detailRow("Size", value: formatBytes(download.totalBytes))
                detailRow("Source", value: sourceDomain)
                detailRow("Save to", value: download.destinationPath)
                detailRow("Segments", value: "\(download.segmentCount) × \(download.threadsPerSegment) threads")
                detailRow("Status", value: download.downloadStatus.rawValue.capitalized)

                // Segment map
                if !download.segments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SEGMENT MAP")
                            .font(.caption2)
                            .foregroundStyle(BDMColors.muted)
                        SegmentMapView(segments: download.segments)
                    }
                }

                // Checksum
                VStack(alignment: .leading, spacing: 4) {
                    Text("VERIFY HASH")
                        .font(.caption2)
                        .foregroundStyle(BDMColors.muted)
                    TextField("Paste SHA-256…", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                Divider()

                // Actions
                VStack(spacing: 4) {
                    actionButton("Copy Download URL", icon: "doc.on.doc")
                    actionButton("Copy File Path", icon: "folder")
                    actionButton("Reveal in Finder", icon: "magnifyingglass")
                    if download.isCompleted {
                        actionButton("Quick Look Preview", icon: "eye")
                    }
                    if download.isActive {
                        actionButton("Pause", icon: "pause.fill")
                    }
                    actionButton("Cancel & Delete", icon: "xmark", destructive: true)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bdmGlassBackground()
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(BDMColors.muted)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func actionButton(_ title: String, icon: String, destructive: Bool = false) -> some View {
        Button {
            // TODO: implement actions
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(destructive ? BDMColors.red : .primary)
    }

    private var sourceDomain: String {
        URL(string: download.url)?.host ?? download.url
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
