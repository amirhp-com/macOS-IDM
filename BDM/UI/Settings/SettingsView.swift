import ServiceManagement
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(BDMLocalizer.self) private var loc

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label(loc.t("settings.general"), systemImage: "gearshape") }
            DownloadsSettingsTab()
                .tabItem { Label(loc.t("settings.downloads"), systemImage: "arrow.down.circle") }
            FoldersSettingsTab()
                .tabItem { Label(loc.t("settings.folders"), systemImage: "folder") }
            NetworkSettingsTab()
                .tabItem { Label(loc.t("settings.network"), systemImage: "network") }
            BrowserSettingsTab()
                .tabItem { Label(loc.t("settings.browser"), systemImage: "globe") }
            NotificationsSettingsTab()
                .tabItem { Label(loc.t("settings.notifications"), systemImage: "bell") }
            LanguageSettingsTab()
                .tabItem { Label(loc.t("settings.language"), systemImage: "globe.americas") }
            AdvancedSettingsTab()
                .tabItem { Label(loc.t("settings.advanced"), systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Environment(AppearanceManager.self) private var appearance
    @AppStorage("bdm.general.launchAtLogin") private var launchAtLogin = false
    @AppStorage("bdm.general.startMinimized") private var startMinimized = false
    @AppStorage("bdm.general.iconMode") private var iconModeRaw = AppIconMode.both.rawValue
    @AppStorage("bdm.general.checkUpdates") private var checkUpdates = true
    @AppStorage("bdm.general.confirmRemove") private var confirmRemove = true

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("[BDM] Launch at login: \(error)")
                        }
                    }
                Toggle("Start minimized to menu bar", isOn: $startMinimized)
                Picker("Show app icon in", selection: $iconModeRaw) {
                    ForEach(AppIconMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .onChange(of: iconModeRaw) { _, raw in
                    let mode = AppIconMode(rawValue: raw) ?? .both
                    appearance.showMenuBarIcon = mode.showsMenuBar
                    AppIconMode.apply(mode)
                }
                Toggle("Check for updates automatically", isOn: $checkUpdates)
                HStack {
                    Button("Check for Updates Now") {
                        Task { await UpdateChecker.shared.check() }
                    }
                    if UpdateChecker.shared.updateAvailable {
                        Button("Open Releases Page") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/amirhp-com/macOS-IDM/releases")!)
                        }
                    }
                }
                if let updateStatus = UpdateChecker.shared.statusMessage {
                    Text(updateStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                @Bindable var app = appearance
                Picker("Theme", selection: $app.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                Picker("Default view mode", selection: $app.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle("Show sidebar on launch", isOn: $app.showSidebar)
                Toggle("Show preview panel", isOn: $app.showPreview)
                Toggle("Liquid Glass background", isOn: $app.glassEnabled)
                Text("Semi-transparent window with vibrancy. Disable for solid background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Confirm before removing downloads", isOn: $confirmRemove)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Downloads Tab

struct DownloadsSettingsTab: View {
    @AppStorage("bdm.engine.defaultSegments") private var defaultSegments = 16
    @AppStorage("bdm.engine.threadsPerSegment") private var threadsPerSegment = 4
    @AppStorage("bdm.engine.maxConcurrent") private var maxConcurrent = 3
    @AppStorage("bdm.engine.maxRetries") private var maxRetries = 5
    @AppStorage("bdm.engine.autoRetry") private var autoRetry = true
    @AppStorage("bdm.completion.playSound") private var playSound = true
    @AppStorage("bdm.completion.autoOpen") private var autoOpen = false
    @AppStorage("bdm.completion.autoUnarchive") private var autoUnarchive = false
    @AppStorage("bdm.completion.autoMount") private var autoMount = false
    @AppStorage("bdm.completion.cleanPartial") private var cleanPartial = true

    var body: some View {
        Form {
            Section("Engine") {
                Picker("Default segments per file", selection: $defaultSegments) {
                    Text("Auto").tag(0)
                    Text("4").tag(4)
                    Text("8").tag(8)
                    Text("16").tag(16)
                    Text("32").tag(32)
                }
                Picker("Threads per segment", selection: $threadsPerSegment) {
                    Text("Auto").tag(0)
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("4").tag(4)
                }
                Picker("Max concurrent downloads", selection: $maxConcurrent) {
                    ForEach([1, 2, 3, 5, 8], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                Stepper("Max retries: \(maxRetries)", value: $maxRetries, in: 0...20)
                Toggle("Auto-retry on network reconnect", isOn: $autoRetry)
            }

            Section("On Completion") {
                Toggle("Play sound on complete", isOn: $playSound)
                Toggle("Auto-open file after download", isOn: $autoOpen)
                Toggle("Auto-unarchive .zip, .tar.gz, .rar", isOn: $autoUnarchive)
                Toggle("Auto-mount .dmg files", isOn: $autoMount)
                Toggle("Remove .bdm-partial on complete", isOn: $cleanPartial)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Folders & Routing Tab

struct FoldersSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutingRule.order) private var rules: [RoutingRule]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files added to the default location (~/Downloads) are matched top-to-bottom; the first matching rule picks the folder. Folders must stay inside ~/Downloads — the sandbox blocks writes elsewhere.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top)

            List {
                ForEach(rules) { rule in
                    RoutingRuleRow(rule: rule)
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(rules[index])
                    }
                    try? modelContext.save()
                }
            }

            HStack {
                Button("+ Add Rule") { addRule() }
                if rules.isEmpty {
                    Button("Add Default Rules") { seedDefaults() }
                }
                Spacer()
                Text("Swipe or ⌫ to delete a rule")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func addRule() {
        let rule = RoutingRule(
            order: (rules.map(\.order).max() ?? -1) + 1,
            ruleType: .fileExtension,
            pattern: ".ext",
            destinationFolder: "~/Downloads/"
        )
        modelContext.insert(rule)
        try? modelContext.save()
    }

    private func seedDefaults() {
        let defaults: [(String, String, Int?)] = [
            (".dmg,.pkg,.app", "~/Downloads/Apps/", nil),
            (".xip,.zip,.tar.gz,.rar,.7z", "~/Downloads/Archives/", 16),
            (".iso,.ipsw,.img", "~/Downloads/Disk Images/", 32),
            (".pdf,.epub,.docx,.txt", "~/Downloads/Documents/", 4),
            (".mp3,.flac,.aac,.wav", "~/Downloads/Music/", nil),
        ]
        for (index, rule) in defaults.enumerated() {
            modelContext.insert(RoutingRule(
                order: index,
                ruleType: .fileExtension,
                pattern: rule.0,
                destinationFolder: rule.1,
                segmentOverride: rule.2
            ))
        }
        try? modelContext.save()
    }
}

private struct RoutingRuleRow: View {
    @Bindable var rule: RoutingRule

    var body: some View {
        HStack(spacing: 8) {
            TextField("Extensions", text: $rule.pattern)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .help("Comma-separated extensions like .zip,.rar — or a domain when type is Domain")
            Picker("", selection: $rule.ruleType) {
                Text("Extension").tag(RoutingRuleType.fileExtension.rawValue)
                Text("Domain").tag(RoutingRuleType.domain.rawValue)
            }
            .frame(width: 100)
            TextField("Folder", text: $rule.destinationFolder)
                .font(.system(.caption2, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)
            Picker("", selection: Binding(
                get: { rule.segmentOverride ?? 0 },
                set: { rule.segmentOverride = $0 == 0 ? nil : $0 }
            )) {
                Text("Auto").tag(0)
                Text("4").tag(4)
                Text("8").tag(8)
                Text("16").tag(16)
                Text("32").tag(32)
            }
            .frame(width: 70)
        }
    }
}

// MARK: - Network Tab

struct NetworkSettingsTab: View {
    @Environment(DownloadManager.self) private var downloadManager
    @AppStorage("bdm.network.speedLimit") private var speedLimit = 0
    @AppStorage("bdm.network.throttleOnBattery") private var throttleOnBattery = true
    @AppStorage("bdm.network.batteryLimit") private var batteryLimit = 5
    @AppStorage("bdm.network.domainLimit") private var domainLimit = 4
    @AppStorage("bdm.scheduler.enabled") private var schedulerEnabled = false
    @AppStorage("bdm.scheduler.scheduleType") private var scheduleType = "daily"
    @AppStorage("bdm.scheduler.startTime") private var startTimeInterval: Double = 32400 // 09:00
    @AppStorage("bdm.scheduler.stopTime") private var stopTimeInterval: Double = 79200 // 22:00
    @AppStorage("bdm.scheduler.pauseOutside") private var pauseOutside = true
    @AppStorage("bdm.scheduler.autoResume") private var autoResume = true

    private var startTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(startTimeInterval) },
            set: { startTimeInterval = $0.timeIntervalSince(Calendar.current.startOfDay(for: $0)) }
        )
    }

    private var stopTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(stopTimeInterval) },
            set: { stopTimeInterval = $0.timeIntervalSince(Calendar.current.startOfDay(for: $0)) }
        )
    }

    var body: some View {
        Form {
            Section("Bandwidth") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Global speed limit")
                        Spacer()
                        TextField("0", value: $speedLimit, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text("MB/s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Set to 0 for unlimited bandwidth.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Throttle on battery", isOn: $throttleOnBattery)
                if throttleOnBattery {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Battery throttle limit")
                            Spacer()
                            TextField("5", value: $batteryLimit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("MB/s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Speed limit applied when running on battery power.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Per-domain connection limit", selection: $domainLimit) {
                    Text("2").tag(2)
                    Text("4").tag(4)
                    Text("8").tag(8)
                    Text("Unlimited").tag(0)
                }
            }

            Section("Scheduler") {
                Toggle("Enable download schedule", isOn: $schedulerEnabled)
                if schedulerEnabled {
                    Picker("Schedule type", selection: $scheduleType) {
                        Text("Daily").tag("daily")
                        Text("Weekdays Only").tag("weekdays")
                        Text("Custom").tag("custom")
                    }
                    DatePicker("Start time", selection: startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Stop time", selection: stopTime, displayedComponents: .hourAndMinute)
                    Toggle("Pause downloads outside scheduled hours", isOn: $pauseOutside)
                    Toggle("Auto-resume when schedule starts", isOn: $autoResume)
                    Text("Downloads added to scheduled queue will only run during the configured time window. You can assign downloads to the schedule when adding URLs or from the context menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: speedLimit) { _, _ in downloadManager.applyEngineSettings() }
        .onChange(of: throttleOnBattery) { _, _ in downloadManager.applyEngineSettings() }
        .onChange(of: batteryLimit) { _, _ in downloadManager.applyEngineSettings() }
    }
}

// MARK: - Browser Tab

struct BrowserSettingsTab: View {
    @AppStorage("bdm.browser.captureEnabled") private var captureEnabled = true
    @AppStorage("bdm.browser.captureConfirm") private var captureConfirm = false

    var body: some View {
        Form {
            Section("Browser Extensions") {
                Text("Safari, Chrome, and Firefox extensions enable BDM to capture downloads from your browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Install Safari Extension…") {
                    if let url = URL(string: "https://github.com/amirhp-com/BDM-Safari-Extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Install Chrome Extension…") {
                    if let url = URL(string: "https://github.com/amirhp-com/BDM-Chrome-Extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Install Firefox Extension…") {
                    if let url = URL(string: "https://github.com/amirhp-com/BDM-Firefox-Extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Section("Capture") {
                Toggle("Capture downloads from browser", isOn: $captureEnabled)
                Toggle("Show confirmation before capturing", isOn: $captureConfirm)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Notifications Tab

struct NotificationsSettingsTab: View {
    @AppStorage("bdm.notif.onComplete") private var onComplete = true
    @AppStorage("bdm.notif.onBatch") private var onBatch = true
    @AppStorage("bdm.notif.onError") private var onError = true
    @AppStorage("bdm.notif.onChecksum") private var onChecksum = true
    @AppStorage("bdm.notif.onStart") private var onStart = true
    @AppStorage("bdm.notif.onPauseStop") private var onPauseStop = true
    @AppStorage("bdm.notif.sound") private var sound = true

    var body: some View {
        Form {
            Section("Events") {
                Toggle("Download started / resumed", isOn: $onStart)
                Toggle("Download paused / stopped", isOn: $onPauseStop)
                Toggle("Download complete", isOn: $onComplete)
                Toggle("Batch complete", isOn: $onBatch)
                Toggle("Download failed / error", isOn: $onError)
                Toggle("Checksum mismatch", isOn: $onChecksum)
            }
            Section("Sound") {
                Toggle("Play notification sound", isOn: $sound)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Language Tab

struct LanguageSettingsTab: View {
    @Environment(BDMLocalizer.self) private var localizer
    @AppStorage("bdm.language") private var selectedLocale = "en"

    var body: some View {
        Form {
            Section(localizer.t("settings.language")) {
                Text("BDM uses JSON-based localization. Select a language below or add your own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let locales = localizer.availableLocales()

                Picker(localizer.t("settings.language"), selection: $selectedLocale) {
                    ForEach(locales, id: \.code) { locale in
                        Text("\(locale.name) (\(Int(locale.completion * 100))%)")
                            .tag(locale.code)
                    }
                }
                .onChange(of: selectedLocale) { _, newValue in
                    localizer.load(locale: newValue)
                }

                Text("Community translations are loaded from\n~/Library/Application Support/BDM/Locales/\nor bundled in the app.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced Tab

struct AdvancedSettingsTab: View {
    @AppStorage("bdm.debug.verboseLogging") private var verboseLogging = false
    @State private var showResetConfirm = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Data") {
                Button("Export Settings…") { exportSettings() }
                Button("Import Settings…") { importSettings() }
                Button("Reset to Defaults") { showResetConfirm = true }
                    .foregroundStyle(.red)
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Debug") {
                Toggle("Verbose logging to Console.app", isOn: $verboseLogging)
                Text("Settings are stored in UserDefaults under the bdm.* prefix.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("Reset all settings to defaults?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetSettings() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var bdmSettings: [String: Any] {
        UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("bdm.") }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "bdm-settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: bdmSettings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
            statusMessage = "Exported \(bdmSettings.count) settings."
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                statusMessage = "Import failed: not a settings file."
                return
            }
            var applied = 0
            for (key, value) in json where key.hasPrefix("bdm.") {
                UserDefaults.standard.set(value, forKey: key)
                applied += 1
            }
            statusMessage = "Imported \(applied) settings."
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func resetSettings() {
        for key in bdmSettings.keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        statusMessage = "Settings reset. Restart BDM to fully apply."
    }
}
