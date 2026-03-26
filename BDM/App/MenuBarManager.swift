import SwiftUI

struct MenuBarView: View {
    var body: some View {
        // Active download count and total speed
        Text("0 Active Downloads — 0 B/s")
            .font(.caption)

        Divider()

        Button("Show BDM") {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
        }

        Button("Add URLs...") {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
            // Post notification to trigger the Add URLs sheet
            NotificationCenter.default.post(name: .menuBarAddURLs, object: nil)
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("Pause All") {
            NotificationCenter.default.post(name: .menuBarPauseAll, object: nil)
        }

        Button("Resume All") {
            NotificationCenter.default.post(name: .menuBarResumeAll, object: nil)
        }

        Divider()

        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit BDM") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarAddURLs = Notification.Name("menuBarAddURLs")
    static let menuBarPauseAll = Notification.Name("menuBarPauseAll")
    static let menuBarResumeAll = Notification.Name("menuBarResumeAll")
}
