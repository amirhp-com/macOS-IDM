import SwiftUI
import SwiftData

struct AddURLsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var urlText = ""
    @State private var savePath = "~/Downloads/"
    @State private var segmentCount = 16
    @State private var threadsPerSegment = 4
    @State private var startImmediately = true

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
                Text("Add Downloads")
                    .font(.headline)
                if !parsedURLs.isEmpty {
                    Text("\(parsedURLs.count) URLs detected")
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
                optionRow("Save to") {
                    TextField("Path", text: $savePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button("Browse…") {
                        browseFolder()
                    }
                    .font(.caption)
                }

                optionRow("Segments") {
                    Picker("", selection: $segmentCount) {
                        Text("Auto").tag(0)
                        Text("4").tag(4)
                        Text("8").tag(8)
                        Text("16").tag(16)
                        Text("32").tag(32)
                    }
                    .frame(maxWidth: .infinity)
                }

                optionRow("Threads/Seg") {
                    Picker("", selection: $threadsPerSegment) {
                        Text("Auto").tag(0)
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }
                    .frame(maxWidth: .infinity)
                }

                optionRow("Start") {
                    Picker("", selection: $startImmediately) {
                        Text("Immediately").tag(true)
                        Text("Add paused").tag(false)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Download \(parsedURLs.count) File\(parsedURLs.count == 1 ? "" : "s") →") {
                    addDownloads()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsedURLs.isEmpty)
            }
            .padding()
        }
        .frame(width: 520)
    }

    private func optionRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(BDMColors.muted)
                .frame(width: 90, alignment: .trailing)
            content()
        }
    }

    private func addDownloads() {
        for url in parsedURLs {
            let item = DownloadItem(
                url: url.absoluteString,
                fileName: url.lastPathComponent,
                destinationPath: (savePath as NSString).appendingPathComponent(url.lastPathComponent),
                segmentCount: segmentCount > 0 ? segmentCount : 16,
                threadsPerSegment: threadsPerSegment > 0 ? threadsPerSegment : 4
            )
            if startImmediately {
                item.downloadStatus = .active
            }
            modelContext.insert(item)
        }
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
