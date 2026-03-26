import SwiftUI

struct DownloadListView: View {
    let downloads: [DownloadItem]
    @Binding var selectedDownload: DownloadItem?
    let viewMode: ViewMode

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(downloads) { download in
                    Group {
                        switch viewMode {
                        case .detailed:
                            DetailedRowView(download: download, isSelected: selectedDownload?.id == download.id)
                        case .compact:
                            CompactRowView(download: download, isSelected: selectedDownload?.id == download.id)
                        case .minimal:
                            MinimalRowView(download: download, isSelected: selectedDownload?.id == download.id)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func downloadContextMenu(_ download: DownloadItem) -> some View {
        if download.isActive {
            Button("Pause") { /* TODO */ }
        } else if download.isPaused {
            Button("Resume") { /* TODO */ }
        }
        Divider()
        Button("Copy Download URL") { /* TODO */ }
        Button("Copy File Path") { /* TODO */ }
        Button("Reveal in Finder") { /* TODO */ }
        Divider()
        if download.isCompleted {
            Button("Quick Look") { /* TODO */ }
        }
        Button("Delete", role: .destructive) { /* TODO */ }
    }
}
