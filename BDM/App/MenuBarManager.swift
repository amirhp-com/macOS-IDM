import SwiftUI

struct MenuBarView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Active download count and total speed
        Text(statusLine)
            .font(.caption)

        Divider()

        Button(loc.t("app.short") + " — " + loc.t("app.name")) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
        }

        Button(loc.t("menu.add_urls") + "…") {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
            // Post notification to trigger the Add URLs sheet
            NotificationCenter.default.post(name: .menuBarAddURLs, object: nil)
        }
        .keyboardShortcut("n", modifiers: .command)

        Button(loc.t("menu.pause_all")) {
            NotificationCenter.default.post(name: .menuBarPauseAll, object: nil)
        }

        Button(loc.t("menu.resume_all")) {
            NotificationCenter.default.post(name: .menuBarResumeAll, object: nil)
        }

        Divider()

        Button(loc.t("menu.settings") + "…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(loc.t("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var statusLine: String {
        let count = downloadManager.activeCount
        let speed = ByteCountFormatter.string(
            fromByteCount: Int64(downloadManager.totalBytesPerSecond),
            countStyle: .file
        )
        return "\(loc.tp("menubar.active_count", count: count)) — \(speed)/s"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarAddURLs = Notification.Name("menuBarAddURLs")
    static let menuBarPauseAll = Notification.Name("menuBarPauseAll")
    static let menuBarResumeAll = Notification.Name("menuBarResumeAll")
}
