import AppKit
import SwiftUI

struct DownloadListView: View {
    let downloads: [DownloadItem]
    @Binding var selectedDownload: DownloadItem?
    @Binding var itemBeingEdited: DownloadItem?
    let viewMode: ViewMode

    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc
    @AppStorage("bdm.general.confirmRemove") private var confirmRemove = true
    @State private var itemPendingRemoval: DownloadItem?

    var body: some View {
        Group {
            switch viewMode {
            case .detailed, .compact, .minimal:
                listLayout
            case .grid:
                gridLayout
            case .table:
                tableLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Remove \"\(itemPendingRemoval?.fileName ?? "")\"?",
            isPresented: Binding(
                get: { itemPendingRemoval != nil },
                set: { if !$0 { itemPendingRemoval = nil } }
            )
        ) {
            Button("Remove Download", role: .destructive) {
                if let item = itemPendingRemoval {
                    remove(item)
                }
                itemPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { itemPendingRemoval = nil }
        } message: {
            Text("The download will be cancelled and its partial file deleted.")
        }
    }

    // MARK: - Layouts

    private var listLayout: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(downloads) { download in
                    Group {
                        switch viewMode {
                        case .compact:
                            CompactRowView(download: download, isSelected: selectedDownload?.id == download.id)
                        case .minimal:
                            MinimalRowView(download: download, isSelected: selectedDownload?.id == download.id)
                        default:
                            DetailedRowView(download: download, isSelected: selectedDownload?.id == download.id)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDownload = download
                    }
                    .contextMenu {
                        downloadContextMenu(download)
                    }
                }
            }
        }
    }

    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 10)], spacing: 10) {
                ForEach(downloads) { download in
                    GridCardView(download: download, isSelected: selectedDownload?.id == download.id)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            selectedDownload = download
                        }
                        .contextMenu {
                            downloadContextMenu(download)
                        }
                }
            }
            .padding(10)
        }
    }

    private var tableLayout: some View {
        Table(downloads, selection: tableSelection) {
            TableColumn(loc.t("sort.name")) { (download: DownloadItem) in
                Text(download.fileName)
                    .lineLimit(1)
            }
            TableColumn(loc.t("sort.size")) { (download: DownloadItem) in
                Text(ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file))
            }
            .width(min: 60, ideal: 80, max: 110)
            TableColumn(loc.t("table.progress")) { (download: DownloadItem) in
                HStack(spacing: 6) {
                    ProgressView(value: download.progressFraction)
                    Text("\(Int(download.progressFraction * 100))%")
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
            }
            .width(min: 120, ideal: 180)
            TableColumn(loc.t("sort.speed")) { (download: DownloadItem) in
                Text(download.isActive ? (downloadManager.formattedSpeed(for: download.id) ?? "--") : "—")
                    .font(.caption)
            }
            .width(min: 70, ideal: 90, max: 120)
            TableColumn(loc.t("sort.status")) { (download: DownloadItem) in
                Text(loc.t("status.\(download.downloadStatus.rawValue)"))
                    .font(.caption)
            }
            .width(min: 70, ideal: 90, max: 130)
        }
        .contextMenu(forSelectionType: DownloadItem.ID.self) { ids in
            if let id = ids.first, let download = downloads.first(where: { $0.id == id }) {
                downloadContextMenu(download)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var tableSelection: Binding<DownloadItem.ID?> {
        Binding(
            get: { selectedDownload?.id },
            set: { id in
                selectedDownload = downloads.first { $0.id == id }
            }
        )
    }

    private func remove(_ download: DownloadItem) {
        if selectedDownload?.id == download.id {
            selectedDownload = nil
        }
        downloadManager.remove(download)
    }

    @ViewBuilder
    private func downloadContextMenu(_ download: DownloadItem) -> some View {
        if download.isActive {
            Button(loc.t("action.pause")) { downloadManager.pause(download) }
            Button(loc.t("action.stop")) { downloadManager.stop(download) }
        } else if download.isPaused || download.isFailed || download.downloadStatus == .queued {
            Button(loc.t(download.isFailed ? "action.retry" : "action.resume")) { downloadManager.resume(download) }
        }
        Divider()
        Button(loc.t("edit.title") + "…") { itemBeingEdited = download }
        Divider()
        Button(loc.t("action.copy_url")) { copyToPasteboard(download.url) }
        Button(loc.t("action.copy_path")) { copyToPasteboard(download.destinationPath) }
        Button(loc.t("action.reveal")) { revealInFinder(download) }
        Divider()
        if download.isCompleted {
            Button(loc.t("action.quick_look")) { quickLook(download) }
        }
        if download.isCompleted || download.isFailed {
            Button(loc.t("action.redownload")) { downloadManager.redownload(download) }
        }
        Button(loc.t("action.delete"), role: .destructive) {
            if confirmRemove {
                itemPendingRemoval = download
            } else {
                remove(download)
            }
        }
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func revealInFinder(_ download: DownloadItem) {
        let path = download.isCompleted
            ? download.destinationPath
            : download.destinationPath + ".bdm-partial"
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func quickLook(_ download: DownloadItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: download.destinationPath))
    }
}
