import SwiftUI
import BDMShared

struct SidebarView: View {
    let downloads: [DownloadItem]

    @State private var selectedCategory: SidebarCategory = .all

    var body: some View {
        List(selection: $selectedCategory) {
            Section("Downloads") {
                sidebarRow(.all, icon: "arrow.down.circle", count: downloads.count)
                sidebarRow(.active, icon: "play.circle", count: activeCount)
                sidebarRow(.paused, icon: "pause.circle", count: pausedCount)
                sidebarRow(.completed, icon: "checkmark.circle", count: completedCount)
                sidebarRow(.failed, icon: "xmark.circle", count: failedCount)
            }

            Section("File Types") {
                sidebarRow(.archives, icon: "doc.zipper", count: 0)
                sidebarRow(.documents, icon: "doc", count: 0)
                sidebarRow(.diskImages, icon: "opticaldisc", count: 0)
                sidebarRow(.audio, icon: "music.note", count: 0)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(_ category: SidebarCategory, icon: String, count: Int) -> some View {
        Label {
            HStack {
                Text(category.displayName)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(BDMColors.muted)
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
    private var completedCount: Int { downloads.filter { $0.downloadStatus == .completed }.count }
    private var failedCount: Int { downloads.filter { $0.downloadStatus == .failed }.count }
}

enum SidebarCategory: Hashable {
    case all, active, paused, completed, failed
    case archives, documents, diskImages, audio

    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Done"
        case .failed: return "Failed"
        case .archives: return "Archives"
        case .documents: return "Documents"
        case .diskImages: return "Disk Images"
        case .audio: return "Audio"
        }
    }

    var color: Color {
        switch self {
        case .all: return BDMColors.accent
        case .active: return BDMColors.accent
        case .paused: return BDMColors.yellow
        case .completed: return BDMColors.green
        case .failed: return BDMColors.red
        case .archives, .documents, .diskImages, .audio: return BDMColors.muted
        }
    }
}
