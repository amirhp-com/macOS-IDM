import SwiftUI
import SwiftData

struct AddURLsSheet: View {
    var prefillText: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc

    @State private var urlText = ""
    @State private var savePath = "~/Downloads/"
    @State private var segmentCount = UserDefaults.standard.object(forKey: "bdm.engine.defaultSegments") as? Int ?? 16
    @State private var threadsPerSegment = UserDefaults.standard.object(forKey: "bdm.engine.threadsPerSegment") as? Int ?? 4
    @State private var startOption: StartOption = .immediately
    @State private var showAdvanced = false
    @State private var username = ""
    @State private var password = ""
    @State private var finishTasks: [FinishTask] = []

    private enum StartOption: String, CaseIterable {
        case immediately
        case paused
        case scheduled

        var localizationKey: String {
            switch self {
            case .immediately: return "add.immediately"
            case .paused: return "add.paused"
            case .scheduled: return "add.scheduled"
            }
        }
    }

    private var parsedURLs: [URL] {
        urlText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { URL(string: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(loc.t("add.title"))
                    .font(.headline)
                if !parsedURLs.isEmpty {
                    Text(loc.t("add.urls_detected", ["n": "\(parsedURLs.count)"]))
                        .font(.caption2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(BDMColors.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding()

            // URL input
            TextEditor(text: $urlText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 100)
                .padding(.horizontal)

            // Parsed preview
            if !parsedURLs.isEmpty {
                VStack(spacing: 2) {
                    ForEach(parsedURLs, id: \.absoluteString) { url in
                        HStack(spacing: 6) {
                            Text(fileIcon(for: url))
                                .font(.caption)
                            Text(url.lastPathComponent)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(BDMColors.surface2.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Options
            VStack(spacing: 10) {
                optionRow(loc.t("add.save_to")) {
                    TextField("Path", text: $savePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button(loc.t("add.browse")) {
                        browseFolder()
                    }
                    .font(.caption)
                }

                optionRow(loc.t("add.segments")) {
                    Picker("", selection: $segmentCount) {
                        Text("Auto").tag(0)
                        Text("4").tag(4)
                        Text("8").tag(8)
                        Text("16").tag(16)
                        Text("32").tag(32)
                    }
                    .frame(maxWidth: .infinity)
                }

                optionRow(loc.t("add.threads")) {
                    Picker("", selection: $threadsPerSegment) {
                        Text("Auto").tag(0)
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }
                    .frame(maxWidth: .infinity)
                }

                optionRow(loc.t("add.start")) {
                    Picker("", selection: $startOption) {
                        ForEach(StartOption.allCases, id: \.self) { option in
                            Text(loc.t(option.localizationKey)).tag(option)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                DisclosureGroup(loc.t("add.advanced"), isExpanded: $showAdvanced) {
                    VStack(spacing: 8) {
                        optionRow(loc.t("edit.username")) {
                            TextField("", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                        optionRow(loc.t("edit.password")) {
                            SecureField("", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                        HStack(alignment: .top) {
                            Text(loc.t("task.section"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .trailing)
                            FinishTaskListEditor(tasks: $finishTasks)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.caption)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(loc.t("add.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(loc.t("add.download_n", ["n": "\(parsedURLs.count)"]) + " →") {
                    addDownloads()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsedURLs.isEmpty)
            }
            .padding()
        }
        .frame(width: 520)
        .onAppear {
            if !prefillText.isEmpty {
                urlText = prefillText
            }
        }
    }

    private func optionRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            content()
        }
    }

    private func addDownloads() {
        let behavior: DownloadManager.StartBehavior
        switch startOption {
        case .immediately: behavior = .immediately
        case .paused: behavior = .paused
        case .scheduled: behavior = .queued
        }
        downloadManager.addDownloads(
            urls: parsedURLs,
            savePath: savePath,
            segments: segmentCount,
            threadsPerSegment: threadsPerSegment,
            behavior: behavior,
            username: username.isEmpty ? nil : username,
            password: username.isEmpty ? nil : password,
            finishTasks: finishTasks
        )
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            savePath = url.path
        }
    }

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "dmg", "iso", "ipsw", "img": return "💿"
        case "zip", "xip", "tar", "gz", "rar": return "📦"
        case "mp3", "flac", "aac": return "🎵"
        default: return "📄"
        }
    }
}
