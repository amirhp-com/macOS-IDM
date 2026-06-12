import Foundation

/// Checks GitHub releases for a newer version.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let releasesURL = URL(string: "https://api.github.com/repos/amirhp-com/macOS-IDM/releases/latest")!
    private static let lastCheckKey = "bdm.updates.lastCheck"

    private(set) var statusMessage: String?
    private(set) var updateAvailable = false
    private(set) var latestVersion: String?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Runs the automatic daily check if enabled and due.
    func checkIfDue() async {
        guard UserDefaults.standard.object(forKey: "bdm.general.checkUpdates") as? Bool ?? true else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 86_400 else { return }
        await check()
        if updateAvailable, let latestVersion {
            NotificationService.shared.notifyUpdateAvailable(version: latestVersion)
        }
    }

    /// Fetches the latest release and compares versions.
    func check() async {
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
        statusMessage = nil
        do {
            var request = URLRequest(url: Self.releasesURL)
            request.timeoutInterval = 15
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 404 {
                statusMessage = "You're on \(currentVersion). No published releases yet."
                return
            }
            guard http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                statusMessage = "Could not read release information."
                return
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            latestVersion = latest
            updateAvailable = Self.isVersion(latest, newerThan: currentVersion)
            statusMessage = updateAvailable
                ? "Version \(latest) is available (you have \(currentVersion))."
                : "You're up to date (\(currentVersion))."
        } catch {
            statusMessage = "Update check failed: \(error.localizedDescription)"
        }
    }

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let av = a.split(separator: ".").map { Int($0) ?? 0 }
        let bv = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(av.count, bv.count) {
            let x = i < av.count ? av[i] : 0
            let y = i < bv.count ? bv[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
