import BDMShared
import SwiftUI
import SwiftData

enum SortKey: String, CaseIterable {
    case dateAdded
    case name
    case size
    case speed
    case status

    var localizationKey: String {
        switch self {
        case .dateAdded: return "sort.date_added"
        case .name: return "sort.name"
        case .size: return "sort.size"
        case .speed: return "sort.speed"
        case .status: return "sort.status"
        }
    }
}

struct ContentView: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \DownloadItem.priority, order: .reverse) private var downloads: [DownloadItem]

    @State private var selectedDownload: DownloadItem?
    @State private var showAddURLSheet = false
    @State private var prefillURLText = ""
    @State private var itemBeingEdited: DownloadItem?
    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var selectedCategory: SidebarCategory = .all
    @State private var sortKey: SortKey = .dateAdded
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appearance = appearance
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(downloads: downloads, selectedCategory: $selectedCategory)
                .navigationSplitViewColumnWidth(min: 140, ideal: 168, max: 200)
        } detail: {
            VStack(spacing: 0) {
                FilterBar(
                    downloads: downloads,
                    searchText: $searchText,
                    viewMode: $appearance.viewMode,
                    statusFilter: $statusFilter,
                    sortKey: $sortKey
                )

                HStack(spacing: 0) {
                    DownloadListView(
                        downloads: filteredDownloads,
                        selectedDownload: $selectedDownload,
                        itemBeingEdited: $itemBeingEdited,
                        viewMode: appearance.viewMode
                    )

                    if appearance.showPreview {
                        Divider()
                        Group {
                            if let download = selectedDownload {
                                DetailPanelView(download: download)
                            } else {
                                emptyDetail
                            }
                        }
                        .frame(width: 280)
                        .transition(.move(edge: .trailing))
                    }
                }

                statusBar
            }
            .bdmGlassBackground()
        }
        .onChange(of: appearance.showSidebar) { _, newValue in
            columnVisibility = newValue ? .all : .detailOnly
        }
        .onChange(of: columnVisibility) { _, newValue in
            appearance.showSidebar = (newValue != .detailOnly)
        }
        .toolbar {
            // Transport controls for the selected download
            ToolbarItemGroup(placement: .secondaryAction) {
                ControlGroup {
                    Button {
                        if let selectedDownload { downloadManager.resume(selectedDownload) }
                    } label: {
                        Label(loc.t("action.start"), systemImage: "play.fill")
                    }
                    .disabled(!canStartSelected)

                    Button {
                        if let selectedDownload { downloadManager.pause(selectedDownload) }
                    } label: {
                        Label(loc.t("action.pause"), systemImage: "pause.fill")
                    }
                    .disabled(!(selectedDownload?.isActive ?? false))

                    Button {
                        if let selectedDownload { downloadManager.stop(selectedDownload) }
                    } label: {
                        Label(loc.t("action.stop"), systemImage: "stop.fill")
                    }
                    .disabled(!(selectedDownload?.isActive ?? false) && !(selectedDownload?.isPaused ?? false))
                }
                .help(loc.t("action.start") + " / " + loc.t("action.pause") + " / " + loc.t("action.stop"))

                ControlGroup {
                    Button {
                        downloadManager.resumeAll()
                    } label: {
                        Label(loc.t("action.start_all"), systemImage: "play.circle")
                    }

                    Button {
                        downloadManager.pauseAll()
                    } label: {
                        Label(loc.t("menu.pause_all"), systemImage: "pause.circle")
                    }

                    Button {
                        downloadManager.stopAll()
                    } label: {
                        Label(loc.t("action.stop_all"), systemImage: "stop.circle")
                    }
                }
                .help(loc.t("action.start_all") + " / " + loc.t("menu.pause_all") + " / " + loc.t("action.stop_all"))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                ViewModeToggle(viewMode: Bindable(appearance).viewMode)

                Button {
                    popOutMiniWindow()
                } label: {
                    Label(loc.t("toolbar.pop_out"), systemImage: "pip.swap")
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .help(loc.t("toolbar.pop_out"))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appearance.showPreview.toggle()
                    }
                } label: {
                    Label(loc.t("toolbar.toggle_preview"), systemImage: "sidebar.trailing")
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .help(loc.t("toolbar.toggle_preview"))

                Button {
                    showAddURLSheet = true
                } label: {
                    Label(loc.t("menu.add_urls"), systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help(loc.t("menu.add_urls"))

                Button {
                    openSettings()
                } label: {
                    Label(loc.t("menu.settings"), systemImage: "gearshape")
                }
                .help(loc.t("menu.settings"))
            }
        }
        .background(TransparentWindowFinder(isGlassEnabled: appearance.glassEnabled))
        .sheet(isPresented: $showAddURLSheet) {
            AddURLsSheet(prefillText: prefillURLText)
                .onDisappear { prefillURLText = "" }
        }
        .sheet(item: $itemBeingEdited) { item in
            EditDownloadSheet(download: item)
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarAddURLs)) { _ in
            showAddURLSheet = true
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
        .task {
            await UpdateChecker.shared.checkIfDue()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPasteboardForLinks()
        }
    }

    /// Minimizes the main window and shows the floating mini progress widget.
    private func popOutMiniWindow() {
        openWindow(id: "mini")
        for window in NSApp.windows where window.canBecomeMain && window.title.contains("BlackSwan") {
            window.miniaturize(nil)
        }
    }

    // MARK: - Paste detection

    @AppStorage("bdm.pasteboard.lastChangeCount") private var lastPasteboardChange = 0

    /// When the app becomes active with fresh URLs on the clipboard,
    /// open the Add Downloads sheet prefilled with them.
    private func checkPasteboardForLinks() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChange else { return }
        lastPasteboardChange = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string) else { return }
        let links = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.lowercased().hasPrefix("http://") || $0.lowercased().hasPrefix("https://") }
            .filter { URL(string: $0) != nil }
        guard !links.isEmpty, !showAddURLSheet else { return }

        // Skip links that are already in the library
        let known = Set(downloads.map(\.url))
        let fresh = links.filter { !known.contains($0) }
        guard !fresh.isEmpty else { return }

        prefillURLText = fresh.joined(separator: "\n")
        showAddURLSheet = true
    }

    private var filteredDownloads: [DownloadItem] {
        var result = downloads

        switch selectedCategory {
        case .all: break
        case .active: result = result.filter { $0.downloadStatus == .active }
        case .paused: result = result.filter { $0.downloadStatus == .paused }
        case .incomplete: result = result.filter { $0.downloadStatus != .completed }
        case .completed: result = result.filter { $0.downloadStatus == .completed }
        case .failed: result = result.filter { $0.downloadStatus == .failed }
        case .archives, .documents, .diskImages, .audio:
            result = result.filter { FileCategory.classify($0.fileName) == selectedCategory.fileCategory }
        }

        switch statusFilter {
        case .all: break
        case .active: result = result.filter { $0.downloadStatus == .active }
        case .paused: result = result.filter { $0.downloadStatus == .paused }
        case .incomplete: result = result.filter { $0.downloadStatus != .completed }
        case .done: result = result.filter { $0.downloadStatus == .completed }
        case .failed: result = result.filter { $0.downloadStatus == .failed }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortKey {
        case .dateAdded:
            result.sort { $0.createdAt > $1.createdAt }
        case .name:
            result.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        case .size:
            result.sort { $0.totalBytes > $1.totalBytes }
        case .speed:
            result.sort { (downloadManager.speeds[$0.id] ?? 0) > (downloadManager.speeds[$1.id] ?? 0) }
        case .status:
            result.sort { $0.status < $1.status }
        }

        return result
    }

    /// Bottom status bar: transient event message on the left, live summary on the right.
    private var statusBar: some View {
        HStack(spacing: 10) {
            if let message = downloadManager.statusMessage {
                Text(message)
                    .font(.caption)
                    .lineLimit(1)
                    .transition(.opacity)
            }
            Spacer()
            HStack(spacing: 12) {
                statusChip(icon: "play.circle", count: count(.active), color: BDMColors.accent)
                statusChip(icon: "pause.circle", count: count(.paused), color: BDMColors.yellow)
                statusChip(icon: "clock", count: count(.queued), color: BDMColors.muted)
                statusChip(icon: "xmark.circle", count: count(.failed), color: BDMColors.red)
                Text(totalSpeedText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeInOut(duration: 0.2), value: downloadManager.statusMessage)
    }

    @ViewBuilder
    private func statusChip(icon: String, count: Int, color: Color) -> some View {
        if count > 0 {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text("\(count)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(color)
        }
    }

    private func count(_ status: DownloadStatus) -> Int {
        downloads.filter { $0.downloadStatus == status }.count
    }

    private var totalSpeedText: String {
        let speed = downloadManager.totalBytesPerSecond
        guard speed > 0 else { return "—" }
        return "↓ " + ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }

    private var canStartSelected: Bool {
        guard let selectedDownload else { return false }
        return selectedDownload.isPaused || selectedDownload.isFailed
            || selectedDownload.downloadStatus == .queued
    }

    private var emptyDetail: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(loc.t("empty.select_download"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(loc.t("empty.press_cmd_n"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bdmGlassBackground()
    }

    /// Handles bdm:// deep links, e.g. from the browser extensions:
    /// bdm://add?url=<encoded-url>[&url=...][&path=<folder>][&user=…&pass=…]
    /// bdm://mini — pop out the floating progress widget
    private func handleURLScheme(_ url: URL) {
        guard url.scheme == "bdm" else { return }
        if url.host == "mini" {
            popOutMiniWindow()
            return
        }
        guard url.host == "add",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = components.queryItems ?? []
        let urls = items.filter { $0.name == "url" }.compactMap { $0.value.flatMap(URL.init(string:)) }
        guard !urls.isEmpty else { return }
        let path = items.first(where: { $0.name == "path" })?.value ?? "~/Downloads/"
        downloadManager.addDownloads(
            urls: urls,
            savePath: path,
            segments: UserDefaults.standard.object(forKey: "bdm.engine.defaultSegments") as? Int ?? 16,
            threadsPerSegment: UserDefaults.standard.object(forKey: "bdm.engine.threadsPerSegment") as? Int ?? 4,
            behavior: .immediately,
            username: items.first(where: { $0.name == "user" })?.value,
            password: items.first(where: { $0.name == "pass" })?.value
        )
    }
}

/// File-type classification shared by the sidebar and filtering.
enum FileCategory {
    case archive, document, diskImage, audio, other

    static func classify(_ fileName: String) -> FileCategory {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "zip", "xip", "tar", "gz", "tgz", "bz2", "rar", "7z": return .archive
        case "pdf", "doc", "docx", "txt", "epub", "rtf", "pages", "key", "numbers": return .document
        case "dmg", "iso", "ipsw", "img", "pkg": return .diskImage
        case "mp3", "flac", "aac", "wav", "m4a", "ogg", "aiff": return .audio
        default: return .other
        }
    }
}
