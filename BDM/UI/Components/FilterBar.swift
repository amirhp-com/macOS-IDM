import SwiftUI

struct FilterBar: View {
    let downloads: [DownloadItem]
    @Binding var searchText: String
    @Binding var viewMode: ViewMode
    @Binding var statusFilter: StatusFilter
    @Binding var sortKey: SortKey
    @Environment(BDMLocalizer.self) private var loc

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StatusFilter.allCases, id: \.self) { filter in
                        filterChip(filter)
                            .fixedSize()
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Sort button
            Menu {
                Picker(loc.t("sort.title"), selection: $sortKey) {
                    ForEach(SortKey.allCases, id: \.self) { key in
                        Text(loc.t(key.localizationKey)).tag(key)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(loc.t("sort.title"), systemImage: "arrow.up.arrow.down")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(minWidth: 100)

            // Search
            TextField("⌘F  " + loc.t("filter.search_placeholder"), text: $searchText)
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
            statusFilter = filter
        } label: {
            HStack(spacing: 3) {
                Text(filter.prefixSymbol + loc.t(filter.localizationKey))
                if count > 0 {
                    Text("\(count)")
                        .foregroundStyle(statusFilter == filter ? .white.opacity(0.8) : BDMColors.muted)
                }
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .background(statusFilter == filter ? BDMColors.accent : BDMColors.surface2)
        .foregroundStyle(statusFilter == filter ? .white : filter.color)
        .clipShape(Capsule())
    }

    private func countFor(_ filter: StatusFilter) -> Int {
        switch filter {
        case .all: return downloads.count
        case .active: return downloads.filter { $0.downloadStatus == .active }.count
        case .paused: return downloads.filter { $0.downloadStatus == .paused }.count
        case .incomplete: return downloads.filter { $0.downloadStatus != .completed }.count
        case .done: return downloads.filter { $0.downloadStatus == .completed }.count
        case .failed: return downloads.filter { $0.downloadStatus == .failed }.count
        }
    }
}

enum StatusFilter: CaseIterable {
    case all, active, paused, incomplete, done, failed

    var localizationKey: String {
        switch self {
        case .all: return "filter.all"
        case .active: return "filter.active"
        case .paused: return "filter.paused"
        case .incomplete: return "sidebar.incomplete"
        case .done: return "filter.done"
        case .failed: return "filter.failed"
        }
    }

    var prefixSymbol: String {
        switch self {
        case .all: return ""
        case .active: return "▶ "
        case .paused: return "⏸ "
        case .incomplete: return "◌ "
        case .done: return "✓ "
        case .failed: return "✗ "
        }
    }

    var color: Color {
        switch self {
        case .all: return .primary
        case .active: return BDMColors.accent
        case .paused: return BDMColors.yellow
        case .incomplete: return BDMColors.accent2
        case .done: return BDMColors.green
        case .failed: return BDMColors.red
        }
    }
}
