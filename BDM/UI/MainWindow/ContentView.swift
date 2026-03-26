import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadItem.priority, order: .reverse) private var downloads: [DownloadItem]

    @State private var selectedDownload: DownloadItem?
    @State private var showAddURLSheet = false
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appearance = appearance
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(downloads: downloads)
                .navigationSplitViewColumnWidth(min: 140, ideal: 168, max: 200)
        } content: {
            VStack(spacing: 0) {
                FilterBar(
                    downloads: downloads,
                    searchText: $searchText,
                    viewMode: $appearance.viewMode
                )

                DownloadListView(
                    downloads: filteredDownloads,
                    selectedDownload: $selectedDownload,
                    viewMode: appearance.viewMode
                )
            }
            .bdmGlassBackground()
            .navigationSplitViewColumnWidth(min: 400, ideal: 500)
        } detail: {
            if let download = selectedDownload {
                DetailPanelView(download: download)
            } else {
                emptyDetail
            }
        }
        .onChange(of: appearance.showSidebar) { _, newValue in
            columnVisibility = newValue ? .all : .doubleColumn
        }
        .onChange(of: columnVisibility) { _, newValue in
            appearance.showSidebar = (newValue != .doubleColumn)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appearance.showSidebar.toggle()
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.leading")
                }
                .bdmGlassButton()
                .keyboardShortcut("s", modifiers: [.command, .option])

                ViewModeToggle(viewMode: Bindable(appearance).viewMode)
                Button {
                    showAddURLSheet = true
                } label: {
                    Label("Add URLs", systemImage: "plus")
                }
                .bdmGlassButton()
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .bdmGlassButton()
            }
        }
        .background(TransparentWindowFinder(isGlassEnabled: appearance.glassEnabled))
        .sheet(isPresented: $showAddURLSheet) {
            AddURLsSheet()
        }
    }

    private var filteredDownloads: [DownloadItem] {
        if searchText.isEmpty { return downloads }
        return downloads.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
    }

    private var emptyDetail: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 40))
                .foregroundStyle(BDMColors.muted2)
            Text("Select a download")
                .font(.headline)
                .foregroundStyle(BDMColors.muted)
            Text("or press ⌘N to add URLs")
                .font(.caption)
                .foregroundStyle(BDMColors.muted2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bdmGlassBackground()
    }
}
