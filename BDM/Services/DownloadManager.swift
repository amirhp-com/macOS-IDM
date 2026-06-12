import AppKit
import Foundation
import IOKit.ps
import SwiftData
import SwiftUI
import BDMShared

/// Coordinates downloads between the UI, SwiftData models, and the XPC downloader service.
@MainActor
@Observable
final class DownloadManager {
    private let modelContext: ModelContext
    private let xpc = XPCClient()

    /// Live speed per download (bytes/second), updated by the polling loop.
    private(set) var speeds: [UUID: Double] = [:]

    private var pollTask: Task<Void, Never>?
    private var lastBytes: [UUID: (bytes: Int64, time: ContinuousClock.Instant)] = [:]
    private var observers: [NSObjectProtocol] = []
    private var pollTick = 0
    private var lastAppliedSpeedLimit: Int64 = -1
    private var lastAppliedMaxConcurrent = -1
    private var lastAppliedDomainLimit = -1

    var totalBytesPerSecond: Double { speeds.values.reduce(0, +) }

    /// Updated by the polling loop — kept as stored state because computing it
    /// with a SwiftData fetch inside view evaluation creates an invalidation loop.
    private(set) var activeCount = 0

    /// Transient event message for the in-app status bar (auto-clears).
    private(set) var statusMessage: String?
    private var statusClearTask: Task<Void, Never>?

    /// Shows a transient message in the status bar and optionally posts a
    /// user notification (gated by the given Notifications setting key).
    func announce(_ message: String, notificationKey: String? = nil, notificationBody: String = "") {
        statusMessage = message
        BDMLog.verbose(message)
        statusClearTask?.cancel()
        statusClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                self?.statusMessage = nil
            }
        }
        if let notificationKey,
           UserDefaults.standard.object(forKey: notificationKey) as? Bool ?? true {
            NotificationService.shared.notifyEvent(title: message, body: notificationBody)
        }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        xpc.onCompleted = { [weak self] id, path in
            Task { @MainActor in self?.handleCompleted(id: id, filePath: path) }
        }
        xpc.onFailed = { [weak self] id, error in
            Task { @MainActor in self?.handleFailed(id: id, error: error) }
        }
        xpc.connect()

        reconcileStaleItems()
        startPolling()
        observeMenuBarCommands()
        applyEngineSettings()

        NotificationService.shared.requestPermission()
        NotificationService.shared.registerCategories()
    }

    /// Pushes bandwidth and concurrency settings to the engine. Called at
    /// startup and periodically so Settings changes take effect.
    func applyEngineSettings() {
        let defaults = UserDefaults.standard
        let speedLimitMB = defaults.integer(forKey: "bdm.network.speedLimit")
        let throttleOnBattery = defaults.object(forKey: "bdm.network.throttleOnBattery") as? Bool ?? true
        let batteryLimitMB = defaults.object(forKey: "bdm.network.batteryLimit") as? Int ?? 5
        let maxConcurrent = defaults.object(forKey: "bdm.engine.maxConcurrent") as? Int ?? 3
        let domainLimit = defaults.object(forKey: "bdm.network.domainLimit") as? Int ?? 4

        var limitMB = speedLimitMB
        if throttleOnBattery && Self.isOnBatteryPower() && batteryLimitMB > 0 {
            limitMB = speedLimitMB > 0 ? min(speedLimitMB, batteryLimitMB) : batteryLimitMB
        }
        let limitBytes = Int64(limitMB) * 1_048_576

        if limitBytes != lastAppliedSpeedLimit || maxConcurrent != lastAppliedMaxConcurrent
            || domainLimit != lastAppliedDomainLimit {
            lastAppliedSpeedLimit = limitBytes
            lastAppliedMaxConcurrent = maxConcurrent
            lastAppliedDomainLimit = domainLimit
            BDMLog.verbose("Engine settings: speed=\(limitBytes)B/s concurrent=\(maxConcurrent) perDomain=\(domainLimit)")
            Task {
                await xpc.setSpeedLimit(bytesPerSecond: limitBytes)
                await xpc.setMaxConcurrentDownloads(maxConcurrent)
                await xpc.setPerDomainConnectionLimit(domainLimit)
            }
        }
    }

    private static func isOnBatteryPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String? else {
            return false
        }
        return type == kIOPSBatteryPowerValue
    }

    // MARK: - Adding downloads

    enum StartBehavior {
        case immediately, paused, queued
    }

    func addDownloads(
        urls: [URL],
        savePath: String,
        segments: Int,
        threadsPerSegment: Int,
        behavior: StartBehavior,
        username: String? = nil,
        password: String? = nil,
        finishTasks: [FinishTask] = []
    ) {
        let defaultFolder = Self.expandPath(savePath)
        // Routing rules only apply when the user kept the default location
        let usesDefaultPath = savePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) == "~/Downloads"

        for url in urls {
            let fileName = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent

            var folder = defaultFolder
            var segs = segments > 0 ? segments : 16
            var threads = threadsPerSegment > 0 ? threadsPerSegment : 4
            if usesDefaultPath, let rule = matchingRule(fileName: fileName, domain: url.host) {
                folder = Self.expandPath(rule.destinationFolder)
                if let so = rule.segmentOverride, so > 0 { segs = so }
                if let to = rule.threadsOverride, to > 0 { threads = to }
                BDMLog.verbose("Routing \(fileName) → \(folder) (rule: \(rule.pattern))")
            }

            let item = DownloadItem(
                url: url.absoluteString,
                fileName: fileName,
                destinationPath: (folder as NSString).appendingPathComponent(fileName),
                segmentCount: segs,
                threadsPerSegment: threads
            )
            item.sourceDomain = url.host
            if let username, !username.isEmpty {
                item.username = username
                item.password = password
            }
            item.finishTasks = finishTasks
            modelContext.insert(item)

            switch behavior {
            case .immediately:
                start(item)
            case .paused:
                item.downloadStatus = .paused
            case .queued:
                item.downloadStatus = .queued
                item.note = "Scheduled — will start during configured schedule window"
            }
        }
        try? modelContext.save()
    }

    // MARK: - Lifecycle actions

    func start(_ item: DownloadItem, quiet: Bool = false) {
        if !quiet {
            announce("▶ \(item.fileName)", notificationKey: "bdm.notif.onStart")
        }
        item.downloadStatus = .active
        item.errorMessage = nil
        let id = item.id
        let url = item.url
        let destination = item.destinationPath
        let segments = item.segmentCount
        let threads = item.threadsPerSegment
        let username = item.username
        let password = item.password

        Task {
            let ok = await xpc.startDownload(
                id: id,
                url: url,
                destination: destination,
                segments: segments,
                threadsPerSegment: threads,
                username: username,
                password: password
            )
            if !ok {
                if let item = self.item(for: id) {
                    item.downloadStatus = .failed
                    item.errorMessage = "Could not reach the download service"
                }
            }
        }
    }

    func pause(_ item: DownloadItem, quiet: Bool = false) {
        if !quiet {
            announce("⏸ \(item.fileName)", notificationKey: "bdm.notif.onPauseStop")
        }
        let id = item.id
        item.downloadStatus = .paused
        speeds[id] = nil
        lastBytes[id] = nil
        Task { _ = await xpc.pauseDownload(id: id) }
    }

    /// Resumes from persisted engine state (continues where the transfer stopped).
    func resume(_ item: DownloadItem, quiet: Bool = false) {
        start(item, quiet: quiet)
    }

    /// Downloads the file again from scratch. Any leftover partial/state is
    /// cleared; the existing completed file is only replaced when the new
    /// transfer finalizes (atomic rename), so it stays intact meanwhile.
    func redownload(_ item: DownloadItem) {
        try? FileManager.default.removeItem(atPath: item.destinationPath + ".bdm-partial")
        try? FileManager.default.removeItem(atPath: item.destinationPath + ".bdm-state")
        item.downloadedBytes = 0
        item.completedAt = nil
        item.duration = nil
        item.retryCount = 0
        for segment in item.segments {
            modelContext.delete(segment)
        }
        item.segments = []
        start(item)
    }

    /// Stops the transfer but keeps the partial file and resume state.
    /// Unlike pause, a stopped item sits in the queue until started manually.
    func stop(_ item: DownloadItem, quiet: Bool = false) {
        if !quiet {
            announce("⏹ \(item.fileName)", notificationKey: "bdm.notif.onPauseStop")
        }
        let id = item.id
        item.downloadStatus = .queued
        speeds[id] = nil
        lastBytes[id] = nil
        Task { _ = await xpc.cancelDownload(id: id, deleteFile: false) }
    }

    func stopAll() {
        let items = fetchAll().filter { $0.downloadStatus == .active || $0.downloadStatus == .paused }
        guard !items.isEmpty else { return }
        for item in items { stop(item, quiet: true) }
        announce("⏹ " + loc("action.stop_all") + " (\(items.count))", notificationKey: "bdm.notif.onPauseStop")
    }

    func cancel(_ item: DownloadItem, deleteFile: Bool) {
        let id = item.id
        speeds[id] = nil
        lastBytes[id] = nil
        Task { _ = await xpc.cancelDownload(id: id, deleteFile: deleteFile) }
    }

    /// Cancel (if running) and remove the item from the library.
    func remove(_ item: DownloadItem, deletePartialFile: Bool = true) {
        cancel(item, deleteFile: deletePartialFile)
        modelContext.delete(item)
        try? modelContext.save()
    }

    func pauseAll() {
        let items = fetchAll().filter { $0.downloadStatus == .active }
        guard !items.isEmpty else { return }
        for item in items { pause(item, quiet: true) }
        announce("⏸ " + loc("menu.pause_all") + " (\(items.count))", notificationKey: "bdm.notif.onPauseStop")
    }

    /// Starts everything that can be started: paused, stopped (queued), and failed items.
    func resumeAll() {
        let startable: [DownloadStatus] = [.paused, .queued, .failed]
        let items = fetchAll().filter { startable.contains($0.downloadStatus) }
        guard !items.isEmpty else { return }
        for item in items { resume(item, quiet: true) }
        announce("▶ " + loc("action.start_all") + " (\(items.count))", notificationKey: "bdm.notif.onStart")
    }

    /// Lightweight localization access for status messages.
    private func loc(_ key: String) -> String {
        BDMLocalizer.shared.t(key)
    }

    func setSpeedLimit(bytesPerSecond: Int64) {
        Task { await xpc.setSpeedLimit(bytesPerSecond: bytesPerSecond) }
    }

    // MARK: - Service events

    private func handleCompleted(id: String, filePath: String) {
        guard let uuid = UUID(uuidString: id), let item = item(for: uuid) else { return }
        announce("✓ \(item.fileName)")
        item.downloadStatus = .completed
        item.completedAt = Date()
        item.duration = item.completedAt?.timeIntervalSince(item.createdAt)
        if item.totalBytes > 0 {
            item.downloadedBytes = item.totalBytes
        }
        for segment in item.segments {
            segment.segmentStatus = .completed
            segment.downloadedBytes = segment.totalBytes
        }
        speeds[uuid] = nil
        lastBytes[uuid] = nil
        try? modelContext.save()

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "bdm.notif.onComplete") as? Bool ?? true {
            NotificationService.shared.notifyComplete(
                fileName: item.fileName,
                size: ByteCountFormatter.string(fromByteCount: item.totalBytes, countStyle: .file),
                duration: Self.formatDuration(item.duration ?? 0),
                filePath: filePath
            )
        }
        if defaults.object(forKey: "bdm.completion.playSound") as? Bool ?? true {
            NSSound(named: "Glass")?.play()
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let ext = fileURL.pathExtension.lowercased()
        let autoOpen = defaults.bool(forKey: "bdm.completion.autoOpen")
        let autoMount = defaults.bool(forKey: "bdm.completion.autoMount") && ext == "dmg"
        let autoUnarchive = defaults.bool(forKey: "bdm.completion.autoUnarchive")
            && ["zip", "tar", "gz", "tgz", "rar", "xip"].contains(ext)
        if autoOpen || autoMount || autoUnarchive {
            NSWorkspace.shared.open(fileURL)
        }

        // Run the item's ordered finish tasks
        let tasks = item.finishTasks
        if !tasks.isEmpty {
            Task { await FinishTaskRunner.run(tasks, downloadedFilePath: filePath) }
        }
    }

    private func handleFailed(id: String, error: String) {
        guard let uuid = UUID(uuidString: id), let item = item(for: uuid) else { return }
        announce("✗ \(item.fileName)")
        item.downloadStatus = .failed
        item.errorMessage = error
        speeds[uuid] = nil
        lastBytes[uuid] = nil
        try? modelContext.save()

        // Auto-retry transient failures (skip HTTP 4xx — they won't heal)
        let maxRetries = UserDefaults.standard.object(forKey: "bdm.engine.maxRetries") as? Int ?? 5
        let isPermanent = error.contains("HTTP error 4")
        if !isPermanent && item.retryCount < min(item.maxRetries, maxRetries) {
            item.retryCount += 1
            let attempt = item.retryCount
            Task {
                try? await Task.sleep(for: .seconds(3))
                guard let item = self.item(for: uuid), item.downloadStatus == .failed else { return }
                item.note = "Retry \(attempt)/\(maxRetries)"
                self.resume(item)
            }
            return
        }

        if UserDefaults.standard.object(forKey: "bdm.notif.onError") as? Bool ?? true {
            NotificationService.shared.notifyFailed(fileName: item.fileName, reason: error)
        }
    }

    // MARK: - Progress polling

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollActiveDownloads()
                self?.pollTick += 1
                if let tick = self?.pollTick {
                    // Re-apply bandwidth/battery settings every ~10s,
                    // evaluate the download schedule every ~30s
                    if tick % 20 == 0 { self?.applyEngineSettings() }
                    if tick % 60 == 1 { self?.evaluateSchedule() }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: - Scheduler

    /// Starts scheduled (queued) items inside the configured time window and
    /// pauses them back to queued outside it.
    private func evaluateSchedule() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "bdm.scheduler.enabled") else { return }

        let scheduleType = defaults.string(forKey: "bdm.scheduler.scheduleType") ?? "daily"
        let windowStart = defaults.object(forKey: "bdm.scheduler.startTime") as? Double ?? 32400
        let windowStop = defaults.object(forKey: "bdm.scheduler.stopTime") as? Double ?? 79200
        let autoResume = defaults.object(forKey: "bdm.scheduler.autoResume") as? Bool ?? true
        let pauseOutside = defaults.object(forKey: "bdm.scheduler.pauseOutside") as? Bool ?? true

        let now = Date()
        let secondsIntoDay = now.timeIntervalSince(Calendar.current.startOfDay(for: now))
        var inWindow = windowStart <= windowStop
            ? (secondsIntoDay >= windowStart && secondsIntoDay <= windowStop)
            : (secondsIntoDay >= windowStart || secondsIntoDay <= windowStop) // overnight window
        if scheduleType == "weekdays" {
            let weekday = Calendar.current.component(.weekday, from: now)
            if weekday == 1 || weekday == 7 { inWindow = false }
        }

        let scheduled = fetchAll().filter { $0.note?.hasPrefix("Scheduled") == true }
        if inWindow && autoResume {
            for item in scheduled where item.downloadStatus == .queued {
                start(item)
            }
        } else if !inWindow && pauseOutside {
            for item in scheduled where item.downloadStatus == .active {
                pause(item)
                item.downloadStatus = .queued
            }
        }
    }

    private func pollActiveDownloads() async {
        let active = fetchAll().filter { $0.downloadStatus == .active }
        if activeCount != active.count {
            activeCount = active.count
        }
        guard !active.isEmpty else { return }

        for item in active {
            guard let progress = await xpc.getProgress(id: item.id) else { continue }
            apply(progress, to: item)
        }
    }

    private func apply(_ progress: DownloadProgress, to item: DownloadItem) {
        if item.totalBytes == 0 && progress.totalBytes > 0 {
            item.totalBytes = progress.totalBytes
        }
        item.downloadedBytes = progress.downloadedBytes

        // Speed via delta between polls (light exponential smoothing)
        let now = ContinuousClock.Instant.now
        if let last = lastBytes[item.id] {
            let elapsed = Double(last.time.duration(to: now).components.seconds)
                + Double(last.time.duration(to: now).components.attoseconds) / 1e18
            if elapsed > 0 {
                let instant = Double(progress.downloadedBytes - last.bytes) / elapsed
                let previous = speeds[item.id] ?? instant
                speeds[item.id] = previous * 0.6 + instant * 0.4
            }
        }
        lastBytes[item.id] = (progress.downloadedBytes, now)

        syncSegments(progress.segmentProgress, on: item)
    }

    private func syncSegments(_ segmentProgress: [SegmentProgress], on item: DownloadItem) {
        guard !segmentProgress.isEmpty else { return }

        if item.segments.count != segmentProgress.count {
            for segment in item.segments {
                modelContext.delete(segment)
            }
            var offset: Int64 = 0
            item.segments = segmentProgress
                .sorted { $0.segmentIndex < $1.segmentIndex }
                .map { sp in
                    let segment = DownloadSegment(
                        segmentIndex: sp.segmentIndex,
                        startByte: offset,
                        endByte: offset + max(sp.totalBytes - 1, 0)
                    )
                    offset += sp.totalBytes
                    return segment
                }
        }

        let byIndex = Dictionary(uniqueKeysWithValues: item.segments.map { ($0.segmentIndex, $0) })
        for sp in segmentProgress {
            guard let segment = byIndex[sp.segmentIndex] else { continue }
            segment.downloadedBytes = sp.downloadedBytes
            segment.segmentStatus = sp.status
        }
    }

    // MARK: - Menu bar commands

    private func observeMenuBarCommands() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .menuBarPauseAll, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pauseAll() }
        })
        observers.append(center.addObserver(forName: .menuBarResumeAll, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resumeAll() }
        })
    }

    // MARK: - Helpers

    /// Items marked active in a previous session can't still be running — the
    /// XPC service dies with the app. Mark them paused so the user can resume.
    private func reconcileStaleItems() {
        for item in fetchAll() where item.downloadStatus == .active {
            item.downloadStatus = .paused
        }
        try? modelContext.save()
    }

    private func fetchAll() -> [DownloadItem] {
        (try? modelContext.fetch(FetchDescriptor<DownloadItem>())) ?? []
    }

    private func matchingRule(fileName: String, domain: String?) -> RoutingRule? {
        let descriptor = FetchDescriptor<RoutingRule>(sortBy: [SortDescriptor(\.order)])
        let rules = (try? modelContext.fetch(descriptor)) ?? []
        return rules.first { $0.matches(fileName: fileName, domain: domain) }
    }

    private func item(for id: UUID) -> DownloadItem? {
        let descriptor = FetchDescriptor<DownloadItem>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }

    func formattedSpeed(for id: UUID) -> String? {
        guard let speed = speeds[id], speed > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }

    /// Expands "~" against the real user home. In a sandboxed app
    /// `NSString.expandingTildeInPath` points into the container, which is not
    /// where the user expects files to land.
    static func expandPath(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        let home: String
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = String(cString: dir)
        } else {
            home = NSHomeDirectory()
        }
        return home + path.dropFirst(1)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
