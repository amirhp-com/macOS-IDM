import SwiftUI
import BDMShared

struct SidebarView: View {
    let downloads: [DownloadItem]
    @Binding var selectedCategory: SidebarCategory
    @Environment(BDMLocalizer.self) private var loc

    var body: some View {
        List(selection: $selectedCategory) {
            Section(loc.t("sidebar.downloads")) {
                sidebarRow(.all, icon: "arrow.down.circle", count: downloads.count)
                sidebarRow(.active, icon: "play.circle", count: activeCount)
                sidebarRow(.paused, icon: "pause.circle", count: pausedCount)
                sidebarRow(.incomplete, icon: "circle.dashed", count: incompleteCount)
                sidebarRow(.completed, icon: "checkmark.circle", count: completedCount)
                sidebarRow(.failed, icon: "xmark.circle", count: failedCount)
            }

            Section(loc.t("sidebar.file_types")) {
                sidebarRow(.archives, icon: "doc.zipper", count: typeCount(.archive))
                sidebarRow(.documents, icon: "doc", count: typeCount(.document))
                sidebarRow(.diskImages, icon: "opticaldisc", count: typeCount(.diskImage))
                sidebarRow(.audio, icon: "music.note", count: typeCount(.audio))
            }
        }
        .listStyle(.sidebar)
    }

    private func typeCount(_ category: FileCategory) -> Int {
        downloads.filter { FileCategory.classify($0.fileName) == category }.count
    }

    private func sidebarRow(_ category: SidebarCategory, icon: String, count: Int) -> some View {
        Label {
            HStack {
                Text(loc.t(category.localizationKey))
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(BDMColors.surface2)
                        .clipShape(Capsule())
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(category.color)
        }
        .tag(category)
    }

    private var activeCount: Int { downloads.filter { $0.downloadStatus == .active }.count }
    private var pausedCount: Int { downloads.filter { $0.downloadStatus == .paused }.count }
    private var incompleteCount: Int { downloads.filter { $0.downloadStatus != .completed }.count }
    private var completedCount: Int { downloads.filter { $0.downloadStatus == .completed }.count }
    private var failedCount: Int { downloads.filter { $0.downloadStatus == .failed }.count }
}

enum SidebarCategory: Hashable {
    case all, active, paused, incomplete, completed, failed
    case archives, documents, diskImages, audio

    var localizationKey: String {
        switch self {
        case .all: return "filter.all"
        case .active: return "filter.active"
        case .paused: return "filter.paused"
        case .incomplete: return "sidebar.incomplete"
        case .completed: return "filter.done"
        case .failed: return "filter.failed"
        case .archives: return "sidebar.archives"
        case .documents: return "sidebar.documents"
        case .diskImages: return "sidebar.disk_images"
        case .audio: return "sidebar.audio"
        }
    }

    var color: Color {
        switch self {
        case .all: return BDMColors.accent
        case .active: return BDMColors.accent
        case .paused: return BDMColors.yellow
        case .incomplete: return BDMColors.accent2
        case .completed: return BDMColors.green
        case .failed: return BDMColors.red
        case .archives, .documents, .diskImages, .audio: return BDMColors.muted
        }
    }

    /// The FileCategory this sidebar entry filters by (nil for status entries).
    var fileCategory: FileCategory? {
        switch self {
        case .archives: return .archive
        case .documents: return .document
        case .diskImages: return .diskImage
        case .audio: return .audio
        default: return nil
        }
    }
}
