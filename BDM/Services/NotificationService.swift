import Foundation
import UserNotifications

/// Manages native macOS notifications for BDM.
final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private init() {}

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
        content.sound = .default
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
        content.sound = .default
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
        content.sound = .defaultCritical
        content.categoryIdentifier = "DOWNLOAD_FAILED"

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
        content.sound = .defaultCritical
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
