import Foundation
import UserNotifications

/// Manages native macOS notifications for BDM.
final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private init() {}

    /// Notification sound respects Settings → Notifications → Sound.
    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "bdm.notif.sound") as? Bool ?? true
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[BDM] Notification permission error: \(error)")
            }
        }
    }

    /// Notify that a download completed.
    func notifyComplete(fileName: String, size: String, duration: String, filePath: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(fileName) — Complete"
        content.body = "\(size) downloaded in \(duration)"
        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = "DOWNLOAD_COMPLETE"
        content.userInfo = ["filePath": filePath]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notify that a batch completed.
    func notifyBatchComplete(batchName: String, fileCount: Int, totalSize: String, folder: String) {
        let content = UNMutableNotificationContent()
        content.title = "Batch \"\(batchName)\" — All \(fileCount) files done"
        content.body = "\(totalSize) total · Saved to \(folder)"
        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = "BATCH_COMPLETE"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notify that a download failed.
    func notifyFailed(fileName: String, reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(fileName) — Failed"
        content.body = reason
        content.sound = soundEnabled ? .defaultCritical : nil
        content.categoryIdentifier = "DOWNLOAD_FAILED"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Lightweight event notification (start/pause/stop announcements).
    func notifyEvent(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // events are frequent; keep them silent

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notify that a newer version is available.
    func notifyUpdateAvailable(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "BDM \(version) is available"
        content.body = "Open the GitHub releases page to download the update."
        content.sound = soundEnabled ? .default : nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notify checksum mismatch.
    func notifyChecksumMismatch(fileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(fileName) — Checksum Mismatch!"
        content.body = "The downloaded file does not match the expected hash."
        content.sound = soundEnabled ? .defaultCritical : nil
        content.categoryIdentifier = "CHECKSUM_MISMATCH"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Register notification categories with actions.
    func registerCategories() {
        let revealAction = UNNotificationAction(identifier: "REVEAL", title: "Reveal in Finder")
        let openAction = UNNotificationAction(identifier: "OPEN", title: "Open File")
        let retryAction = UNNotificationAction(identifier: "RETRY", title: "Retry Now")
        let openFolderAction = UNNotificationAction(identifier: "OPEN_FOLDER", title: "Open Folder")
        let redownloadAction = UNNotificationAction(identifier: "REDOWNLOAD", title: "Re-download")

        let completeCategory = UNNotificationCategory(
            identifier: "DOWNLOAD_COMPLETE",
            actions: [revealAction, openAction],
            intentIdentifiers: []
        )
        let batchCategory = UNNotificationCategory(
            identifier: "BATCH_COMPLETE",
            actions: [openFolderAction],
            intentIdentifiers: []
        )
        let failedCategory = UNNotificationCategory(
            identifier: "DOWNLOAD_FAILED",
            actions: [retryAction],
            intentIdentifiers: []
        )
        let checksumCategory = UNNotificationCategory(
            identifier: "CHECKSUM_MISMATCH",
            actions: [redownloadAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            completeCategory, batchCategory, failedCategory, checksumCategory
        ])
    }
}
