import AppKit
import SwiftUI

struct DetailPanelView: View {
    let download: DownloadItem

    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc
    @AppStorage("bdm.general.confirmRemove") private var confirmRemove = true
    @State private var showRemoveConfirm = false
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(download.fileName)
                    .font(.headline)
                    .lineLimit(2)

                // Info rows
                detailRow(loc.t("detail.size"), value: formatBytes(download.totalBytes))
                detailRow(loc.t("detail.source"), value: sourceDomain)
                detailRow(loc.t("detail.save_to"), value: download.destinationPath)
                detailRow(loc.t("add.segments"), value: loc.t("detail.segments", [
                    "n": "\(download.segmentCount)",
                    "t": "\(download.threadsPerSegment)",
                ]))
                detailRow(loc.t("detail.status"), value: loc.t("status.\(download.downloadStatus.rawValue)"))

                // Segment map
                if !download.segments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc.t("add.segments").uppercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        SegmentMapView(segments: download.segments)
                    }
                }

                // Checksum
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.t("detail.verify_hash").uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField(loc.t("detail.paste_hash"), text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                Divider()

                // Actions
                VStack(spacing: 4) {
                    actionButton(loc.t("edit.title"), icon: "pencil") {
                        showEditSheet = true
                    }
                    actionButton(loc.t("action.copy_url"), icon: "doc.on.doc") {
                        copyToPasteboard(download.url)
                    }
                    actionButton(loc.t("action.copy_path"), icon: "folder") {
                        copyToPasteboard(download.destinationPath)
                    }
                    actionButton(loc.t("action.reveal"), icon: "magnifyingglass") {
                        revealInFinder()
                    }
                    if download.isCompleted {
                        actionButton(loc.t("action.quick_look"), icon: "eye") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: download.destinationPath))
                        }
                    }
                    if download.isActive {
                        actionButton(loc.t("action.pause"), icon: "pause.fill") {
                            downloadManager.pause(download)
                        }
                    }
                    if download.isPaused || download.isFailed {
                        actionButton(loc.t(download.isFailed ? "action.retry" : "action.resume"), icon: "play.fill") {
                            downloadManager.resume(download)
                        }
                    }
                    if download.isCompleted || download.isFailed {
                        actionButton(loc.t("action.redownload"), icon: "arrow.clockwise") {
                            downloadManager.redownload(download)
                        }
                    }
                    actionButton(loc.t("action.cancel_delete"), icon: "xmark", destructive: true) {
                        if confirmRemove {
                            showRemoveConfirm = true
                        } else {
                            downloadManager.remove(download)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bdmGlassBackground()
        .sheet(isPresented: $showEditSheet) {
            EditDownloadSheet(download: download)
        }
        .confirmationDialog("Remove \"\(download.fileName)\"?", isPresented: $showRemoveConfirm) {
            Button("Remove Download", role: .destructive) {
                downloadManager.remove(download)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The download will be cancelled and its partial file deleted.")
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func actionButton(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(destructive ? BDMColors.red : .primary)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func revealInFinder() {
        let path = download.isCompleted
            ? download.destinationPath
            : download.destinationPath + ".bdm-partial"
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private var sourceDomain: String {
        URL(string: download.url)?.host ?? download.url
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
