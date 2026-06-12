import Foundation
import os

/// App-wide logging. Verbose messages only reach Console.app when
/// Settings → Advanced → "Verbose logging" is enabled.
enum BDMLog {
    private static let logger = Logger(subsystem: "com.amirhpcom.bdm", category: "app")

    static var verboseEnabled: Bool {
        UserDefaults.standard.bool(forKey: "bdm.debug.verboseLogging")
    }

    static func verbose(_ message: String) {
        guard verboseEnabled else { return }
        // notice-level persists to the log store (info-level is memory-only,
        // which makes Console.app's "show last N minutes" miss it)
        logger.notice("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
