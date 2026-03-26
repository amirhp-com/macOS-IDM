import SwiftUI

struct SettingsView: View {
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            DownloadsSettingsTab()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
            FoldersSettingsTab()
                .tabItem { Label("Folders & Routing", systemImage: "folder") }
            NetworkSettingsTab()
                .tabItem { Label("Network", systemImage: "network") }
            BrowserSettingsTab()
                .tabItem { Label("Browser", systemImage: "globe") }
            NotificationsSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
            LanguageSettingsTab()
                .tabItem { Label("Language", systemImage: "globe.americas") }
            AdvancedSettingsTab()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Environment(AppearanceManager.self) private var appearance
    @AppStorage("bdm.general.launchAtLogin") private var launchAtLogin = true
    @AppStorage("bdm.general.startMinimized") private var startMinimized = false
    @AppStorage("bdm.general.showDockIcon") private var showDockIcon = true
    @AppStorage("bdm.general.checkUpdates") private var checkUpdates = true
    @AppStorage("bdm.general.confirmRemove") private var confirmRemove = true

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Start minimized to menu bar", isOn: $startMinimized)
                Toggle("Show Dock icon", isOn: $showDockIcon)
                Toggle("Check for updates automatically", isOn: $checkUpdates)
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
    var body: some View {
        VStack(alignment: .leading) {
            Text("Files are matched top-to-bottom. First matching rule wins. Drag to reorder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top)

            // Routing rules table placeholder
            List {
                routingRow(extensions: ".dmg, .pkg, .app", folder: "~/Downloads/Apps/", segments: "Auto")
                routingRow(extensions: ".xip, .zip, .tar.gz, .rar", folder: "~/Downloads/Archives/", segments: "16")
                routingRow(extensions: ".iso, .ipsw, .img", folder: "~/Downloads/Disk Images/", segments: "32")
                routingRow(extensions: ".pdf, .epub, .docx", folder: "~/Documents/", segments: "4")
                routingRow(extensions: ".mp3, .flac, .aac, .wav", folder: "~/Music/Downloads/", segments: "Auto")
                routingRow(extensions: "* (default)", folder: "~/Downloads/", segments: "Auto")
            }

            Button("+ Add rule…") {}
                .font(.caption)
                .padding(.horizontal)
                .padding(.bottom)
        }
    }

    private func routingRow(extensions: String, folder: String, segments: String) -> some View {
        HStack {
            Text(extensions)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(folder)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
            Text(segments)
                .font(.caption)
                .frame(width: 50)
        }
    }
}

// MARK: - Network Tab

struct NetworkSettingsTab: View {
    @AppStorage("bdm.network.speedLimit") private var speedLimit = 0
    @AppStorage("bdm.network.throttleOnBattery") private var throttleOnBattery = true
    @AppStorage("bdm.network.batteryLimit") private var batteryLimit = 5
    @AppStorage("bdm.network.domainLimit") private var domainLimit = 4
    @AppStorage("bdm.scheduler.enabled") private var schedulerEnabled = false

    var body: some View {
        Form {
            Section("Bandwidth") {
                HStack {
                    Text("Global speed limit")
                    Spacer()
                    TextField("MB/s", value: $speedLimit, format: .number)
                        .frame(width: 60)
                    Text("MB/s (0 = unlimited)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Throttle on battery", isOn: $throttleOnBattery)
                if throttleOnBattery {
                    HStack {
                        Text("Battery throttle limit")
                        Spacer()
                        TextField("MB/s", value: $batteryLimit, format: .number)
                            .frame(width: 60)
                        Text("MB/s")
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
                    Text("Configure active hours for scheduled downloads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Browser Tab

struct BrowserSettingsTab: View {
    var body: some View {
        Form {
            Section("Browser Extensions") {
                Text("Safari, Chrome, and Firefox extensions enable BDM to capture downloads from your browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Install Safari Extension…") {}
                Button("Install Chrome Extension…") {}
                Button("Install Firefox Extension…") {}
            }
            Section("Capture") {
                Toggle("Capture downloads from browser", isOn: .constant(true))
                Toggle("Show confirmation before capturing", isOn: .constant(false))
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
    @AppStorage("bdm.notif.sound") private var sound = true

    var body: some View {
        Form {
            Section("Events") {
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
    var body: some View {
        Form {
            Section("Language") {
                Text("BDM uses JSON-based localization. Select a language below or add your own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Language", selection: .constant("en")) {
                    Text("English (100%)").tag("en")
                    Text("فارسی — Persian (community)").tag("fa")
                }

                Text("Community translations are loaded from\n~/Library/Application Support/BDM/Locales/")
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
    var body: some View {
        Form {
            Section("Data") {
                Button("Export Settings…") {}
                Button("Import Settings…") {}
                Button("Reset to Defaults") {}
                    .foregroundStyle(.red)
            }
            Section("Debug") {
                Toggle("Verbose logging to Console.app", isOn: .constant(false))
                Text("Settings file: ~/Library/Application Support/BDM/settings.json")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
