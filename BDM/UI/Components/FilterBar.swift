import SwiftUI

struct FilterBar: View {
    let downloads: [DownloadItem]
    @Binding var searchText: String
    @Binding var viewMode: ViewMode

    @State private var activeFilter: StatusFilter = .all

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StatusFilter.allCases, id: \.self) { filter in
                filterChip(filter)
            }

            Spacer()

            // Sort button
            Menu {
                Button("Name") {}
                Button("Size") {}
                Button("Speed") {}
                Button("Date Added") {}
                Button("Status") {}
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 60)

            // Search
            TextField("⌘F  Search…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 150)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func filterChip(_ filter: StatusFilter) -> some View {
        let count = countFor(filter)
        return Button {
            activeFilter = filter
        } label: {
            HStack(spacing: 3) {
                Text(filter.displayName)
                if count > 0 {
                    Text("\(count)")
                        .foregroundStyle(BDMColors.muted)
                }
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(activeFilter == filter ? BDMColors.accent : BDMColors.surface2)
        .foregroundStyle(activeFilter == filter ? .white : filter.color)
        .clipShape(Capsule())
    }

    private func countFor(_ filter: StatusFilter) -> Int {
        switch filter {
        case .all: return downloads.count
        case .active: return downloads.filter { $0.downloadStatus == .active }.count
        case .paused: return downloads.filter { $0.downloadStatus == .paused }.count
        case .done: return downloads.filter { $0.downloadStatus == .completed }.count
        case .failed: return downloads.filter { $0.downloadStatus == .failed }.count
        }
    }
}

enum StatusFilter: CaseIterable {
    case all, active, paused, done, failed

    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "▶ Active"
        case .paused: return "⏸ Paused"
        case .done: return "✓ Done"
        case .failed: return "✗ Failed"
        }
    }

    var color: Color {
        switch self {
        case .all: return .primary
        case .active: return BDMColors.accent
        case .paused: return BDMColors.yellow
        case .done: return BDMColors.green
        case .failed: return BDMColors.red
        }
    }
}
