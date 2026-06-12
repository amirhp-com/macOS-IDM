import SwiftUI
import SwiftData

/// Where the app icon is shown. At least one location is always active.
enum AppIconMode: String, CaseIterable {
    case both
    case dockOnly
    case menuBarOnly

    var displayName: String {
        switch self {
        case .both: return "Dock & Menu Bar"
        case .dockOnly: return "Dock only"
        case .menuBarOnly: return "Menu Bar only"
        }
    }

    var showsDock: Bool { self != .menuBarOnly }
    var showsMenuBar: Bool { self != .dockOnly }

    static func apply(_ mode: AppIconMode) {
        let target: NSApplication.ActivationPolicy = mode.showsDock ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return }
        NSApp.setActivationPolicy(target)
        if !mode.showsDock {
            // Keep the app usable after losing Dock presence
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct BDMApp: App {
    @State private var appearance = AppearanceManager()
    @State private var downloadManager: DownloadManager
    @State private var localizer: BDMLocalizer
    @AppStorage("bdm.general.startMinimized") private var startMinimized = false

    private var layoutDirection: LayoutDirection {
        localizer.isRTL ? .rightToLeft : .leftToRight
    }

    /// MenuBarExtra writes its isInserted binding on every evaluation; a plain
    /// AppStorage binding loops forever because UserDefaults KVO fires even for
    /// equal values. This binding drops no-op writes.
    private var menuBarIconInserted: Binding<Bool> {
        Binding(
            get: { appearance.showMenuBarIcon },
            set: { newValue in
                if appearance.showMenuBarIcon != newValue {
                    appearance.showMenuBarIcon = newValue
                }
            }
        )
    }

    private let container: ModelContainer

    init() {
        // Single-instance guard. LSMultipleInstancesProhibited covers Finder/open
        // launches; an exclusive file lock makes it airtight for any launch path
        // (atomic — two racing processes can never both win).
        let lockPath = NSTemporaryDirectory() + "com.amirhpcom.bdm.instance.lock"
        let lockFD = Darwin.open(lockPath, O_CREAT | O_RDWR, 0o600)
        if lockFD < 0 || flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.amirhpcom.bdm"
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                .activate()
            exit(0)
        }
        // The lock fd stays open (and held) for the app's lifetime.

        NSWindow.allowsAutomaticWindowTabbing = false
        let container = try! ModelContainer(for:
            DownloadItem.self,
            DownloadSegment.self,
            DownloadThreadRange.self,
            RoutingRule.self
        )
        self.container = container
        _downloadManager = State(initialValue: DownloadManager(modelContext: container.mainContext))

        let localizer = BDMLocalizer.shared
        let savedLocale = UserDefaults.standard.string(forKey: "bdm.language") ?? "en"
        if savedLocale != "en" {
            localizer.load(locale: savedLocale)
        }
        _localizer = State(initialValue: localizer)

        let mode = AppIconMode(rawValue: UserDefaults.standard.string(forKey: "bdm.general.iconMode") ?? "") ?? .both
        DispatchQueue.main.async {
            AppIconMode.apply(mode)
        }
    }

    var body: some Scene {
        // Single Window (not WindowGroup): the app is strictly one-window —
        // deep links and reopens must never spawn additional main windows.
        Window("BlackSwan Download Manager", id: "main") {
            ContentView()
                .environment(appearance)
                .environment(downloadManager)
                .environment(localizer)
                .environment(\.layoutDirection, layoutDirection)
                .preferredColorScheme(appearance.theme.colorScheme)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.automatic)
        .defaultLaunchBehavior(startMinimized ? .suppressed : .automatic)
        .modelContainer(container)

        Settings {
            SettingsView()
                .environment(appearance)
                .environment(downloadManager)
                .environment(localizer)
                .environment(\.layoutDirection, layoutDirection)
                .preferredColorScheme(appearance.theme.colorScheme)
                .frame(minWidth: 600, minHeight: 450)
        }
        .modelContainer(container)

        MenuBarExtra("BDM", systemImage: "arrow.down.circle.fill", isInserted: menuBarIconInserted) {
            MenuBarView()
                .environment(downloadManager)
                .environment(localizer)
        }
        .menuBarExtraStyle(.menu)

        // Floating mini progress widget (pop-out)
        Window("BDM Mini", id: "mini") {
            MiniProgressView()
                .environment(downloadManager)
                .environment(localizer)
                .preferredColorScheme(appearance.theme.colorScheme)
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}
