import SwiftUI

/// Edits an existing download: name, source URL, destination, credentials,
/// and the ordered finish tasks that run when it completes.
struct EditDownloadSheet: View {
    let download: DownloadItem

    @Environment(\.dismiss) private var dismiss
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(BDMLocalizer.self) private var loc

    @State private var fileName = ""
    @State private var urlString = ""
    @State private var destinationFolder = ""
    @State private var username = ""
    @State private var password = ""
    @State private var finishTasks: [FinishTask] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.t("edit.title"))
                    .font(.headline)
                Spacer()
            }
            .padding()

            Form {
                TextField(loc.t("sort.name"), text: $fileName)
                TextField("URL", text: $urlString)
                    .font(.system(.caption, design: .monospaced))
                HStack {
                    TextField(loc.t("add.save_to"), text: $destinationFolder)
                        .font(.system(.caption, design: .monospaced))
                    Button(loc.t("add.browse")) { browseFolder() }
                }

                Section(loc.t("edit.auth")) {
                    TextField(loc.t("edit.username"), text: $username)
                    SecureField(loc.t("edit.password"), text: $password)
                }

                Section(loc.t("task.section")) {
                    FinishTaskListEditor(tasks: $finishTasks)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(loc.t("add.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(loc.t("edit.save")) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(fileName.isEmpty || URL(string: urlString) == nil)
            }
            .padding()
        }
        .frame(width: 560, height: 480)
        .onAppear {
            fileName = download.fileName
            urlString = download.url
            destinationFolder = (download.destinationPath as NSString).deletingLastPathComponent
            username = download.username ?? ""
            password = download.password ?? ""
            finishTasks = download.finishTasks
        }
    }

    private func save() {
        let wasCompleted = download.isCompleted
        let oldPath = download.destinationPath

        download.fileName = fileName
        download.url = urlString
        download.sourceDomain = URL(string: urlString)?.host
        download.destinationPath = (destinationFolder as NSString).appendingPathComponent(fileName)
        download.username = username.isEmpty ? nil : username
        download.password = username.isEmpty ? nil : password
        download.finishTasks = finishTasks

        // Renaming/moving a completed file moves it on disk too
        if wasCompleted, oldPath != download.destinationPath,
           FileManager.default.fileExists(atPath: oldPath) {
            try? FileManager.default.createDirectory(
                atPath: (download.destinationPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try? FileManager.default.moveItem(atPath: oldPath, toPath: download.destinationPath)
        }
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            destinationFolder = url.path
        }
    }
}
