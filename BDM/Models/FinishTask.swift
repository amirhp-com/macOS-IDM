import AppKit
import Foundation
import SwiftUI

/// An action to run when a download (or queue) finishes.
/// Stored as JSON on the download item so the list stays orderable.
struct FinishTask: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case playSound
        case openFile
        case runApp
        case runScript
        case wait
        case turnOffWifi
        case quitApp
        case shutdown

        var localizationKey: String { "task.\(rawValue)" }

        var systemImage: String {
            switch self {
            case .playSound: return "speaker.wave.2"
            case .openFile: return "doc.viewfinder"
            case .runApp: return "app.badge.checkmark"
            case .runScript: return "terminal"
            case .wait: return "clock"
            case .turnOffWifi: return "wifi.slash"
            case .quitApp: return "xmark.circle"
            case .shutdown: return "power"
            }
        }

        /// Whether the task takes a parameter (app path, script path+args, seconds).
        var hasParameter: Bool {
            switch self {
            case .runApp, .runScript, .wait: return true
            default: return false
            }
        }
    }

    var id = UUID()
    var kind: Kind
    /// runApp: app path · runScript: script path · wait: seconds
    var parameter: String = ""
    /// runScript only: space-separated arguments
    var arguments: String = ""

    @MainActor
    func displayText(_ loc: BDMLocalizer) -> String {
        var text = loc.t(kind.localizationKey)
        if kind.hasParameter && !parameter.isEmpty {
            text += ": \((parameter as NSString).lastPathComponent)"
        }
        return text
    }

    // MARK: - Serialization helpers

    static func decode(_ json: String?) -> [FinishTask] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([FinishTask].self, from: data)) ?? []
    }

    static func encode(_ tasks: [FinishTask]) -> String? {
        guard !tasks.isEmpty, let data = try? JSONEncoder().encode(tasks) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Executes finish tasks sequentially (so "wait" delays the rest of the chain).
enum FinishTaskRunner {
    @MainActor
    static func run(_ tasks: [FinishTask], downloadedFilePath: String) async {
        for task in tasks {
            BDMLog.verbose("Finish task: \(task.kind.rawValue) \(task.parameter)")
            switch task.kind {
            case .playSound:
                NSSound(named: "Glass")?.play()

            case .openFile:
                NSWorkspace.shared.open(URL(fileURLWithPath: downloadedFilePath))

            case .runApp:
                guard !task.parameter.isEmpty else { continue }
                let url = URL(fileURLWithPath: FinishTaskRunner.expand(task.parameter))
                NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
                    if let error { BDMLog.error("runApp failed: \(error.localizedDescription)") }
                }

            case .runScript:
                // Sandboxed apps can't spawn arbitrary shells; NSUserUnixTask is
                // the supported path — scripts live in
                // ~/Library/Application Scripts/com.amirhpcom.bdm/ and run
                // OUTSIDE the sandbox with full user permissions.
                guard !task.parameter.isEmpty else { continue }
                do {
                    let scriptsDir = try FileManager.default.url(
                        for: .applicationScriptsDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )
                    let name = (task.parameter as NSString).lastPathComponent
                    let unixTask = try NSUserUnixTask(url: scriptsDir.appendingPathComponent(name))
                    var args = task.arguments.split(separator: " ").map(String.init)
                    args.append(downloadedFilePath)
                    unixTask.execute(withArguments: args) { error in
                        if let error {
                            BDMLog.error("runScript \(name): \(error.localizedDescription)")
                        } else {
                            BDMLog.verbose("runScript \(name): done")
                        }
                    }
                } catch {
                    BDMLog.error("runScript: \(error.localizedDescription) — place scripts in ~/Library/Application Scripts/com.amirhpcom.bdm/")
                }

            case .wait:
                let seconds = Double(task.parameter) ?? 5
                try? await Task.sleep(for: .seconds(seconds))

            case .turnOffWifi:
                // networksetup can't be spawned from the sandbox; an
                // Application Scripts helper named wifi-off.sh is the
                // user-controllable way. Fall back to telling the user.
                do {
                    let scriptsDir = try FileManager.default.url(
                        for: .applicationScriptsDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )
                    let helper = scriptsDir.appendingPathComponent("wifi-off.sh")
                    if FileManager.default.fileExists(atPath: helper.path) {
                        let unixTask = try NSUserUnixTask(url: helper)
                        unixTask.execute(withArguments: []) { error in
                            if let error { BDMLog.error("wifi-off: \(error.localizedDescription)") }
                        }
                    } else {
                        BDMLog.error("turnOffWifi needs a wifi-off.sh helper in ~/Library/Application Scripts/com.amirhpcom.bdm/ (e.g. `networksetup -setairportpower en0 off`)")
                    }
                } catch {
                    BDMLog.error("turnOffWifi: \(error.localizedDescription)")
                }

            case .quitApp:
                NSApplication.shared.terminate(nil)

            case .shutdown:
                let script = NSAppleScript(source: "tell application \"System Events\" to shut down")
                var error: NSDictionary?
                script?.executeAndReturnError(&error)
                if let error { BDMLog.error("shutdown failed: \(error)") }
            }
        }
    }

    @MainActor
    private static func expand(_ path: String) -> String {
        DownloadManager.expandPath(path)
    }
}

// MARK: - Editor

/// Orderable editor for a list of finish tasks. Used in the Edit sheet and Add sheet.
struct FinishTaskListEditor: View {
    @Binding var tasks: [FinishTask]
    @Environment(BDMLocalizer.self) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 6) {
                    Image(systemName: task.kind.systemImage)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(task.displayText(loc))
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if task.kind.hasParameter {
                        TextField(parameterPlaceholder(task.kind), text: parameterBinding(task.id))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 150)
                        if task.kind == .runScript {
                            TextField(loc.t("task.args"), text: argumentsBinding(task.id))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 90)
                        }
                    }

                    Button {
                        move(task.id, by: -1)
                    } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless)
                    .disabled(index == 0)
                    Button {
                        move(task.id, by: 1)
                    } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless)
                    .disabled(index == tasks.count - 1)
                    Button {
                        tasks.removeAll { $0.id == task.id }
                    } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                }
            }

            Menu {
                ForEach(FinishTask.Kind.allCases, id: \.self) { kind in
                    Button {
                        tasks.append(FinishTask(kind: kind, parameter: kind == .wait ? "10" : ""))
                    } label: {
                        Label(loc.t(kind.localizationKey), systemImage: kind.systemImage)
                    }
                }
            } label: {
                Label(loc.t("task.add"), systemImage: "plus")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func parameterPlaceholder(_ kind: FinishTask.Kind) -> String {
        switch kind {
        case .runApp: return "/Applications/….app"
        case .runScript: return "script name in Application Scripts"
        case .wait: return loc.t("task.seconds")
        default: return ""
        }
    }

    private func parameterBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { tasks.first(where: { $0.id == id })?.parameter ?? "" },
            set: { newValue in
                if let i = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[i].parameter = newValue
                }
            }
        )
    }

    private func argumentsBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { tasks.first(where: { $0.id == id })?.arguments ?? "" },
            set: { newValue in
                if let i = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[i].arguments = newValue
                }
            }
        )
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard target >= 0, target < tasks.count else { return }
        tasks.swapAt(index, target)
    }
}
