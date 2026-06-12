import Foundation
import SwiftUI

/// JSON-based localization engine.
/// Loads en.json from bundle, overlays user locale from Application Support.
@Observable
@MainActor
final class BDMLocalizer {
    static let shared = BDMLocalizer()

    private var strings: [String: Any] = [:]
    private var fallback: [String: Any] = [:]
    private(set) var isRTL = false
    private(set) var currentLocale = "en"

    init() {
        loadBundled()
    }

    /// Load the bundled en.json as the fallback.
    private func loadBundled() {
        if let url = Bundle.main.url(forResource: "en", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            fallback = json
            strings = json
        }
    }

    /// Load a user locale, overlaying on top of English fallback.
    /// Checks the app bundle first, then ~/Library/Application Support/BDM/Locales/.
    func load(locale: String) {
        currentLocale = locale

        if locale == "en" {
            strings = fallback
            isRTL = false
            return
        }

        // First, check the app bundle for the locale file
        var resolvedURL: URL?
        if let bundleURL = Bundle.main.url(forResource: locale, withExtension: "json") {
            resolvedURL = bundleURL
        }

        // Then, check Application Support (user overrides take priority)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let appSupportURL = appSupport?.appendingPathComponent("BDM/Locales/\(locale).json"),
           FileManager.default.fileExists(atPath: appSupportURL.path) {
            resolvedURL = appSupportURL
        }

        guard let url = resolvedURL,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[BDM] Could not load locale \(locale), staying on English")
            return
        }

        // Overlay: user strings on top of English fallback
        var merged = fallback
        for (key, value) in json {
            merged[key] = value
        }
        strings = merged

        // RTL detection
        isRTL = (json["_direction"] as? String)?.lowercased() == "rtl"
    }

    /// Translate a key with optional variable interpolation.
    /// Missing keys fall back to English, never return blank.
    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        var result: String

        if let value = strings[key] as? String {
            result = value
        } else if let value = fallback[key] as? String {
            result = value
        } else {
            // Missing key entirely — return the key itself
            print("[BDM] Missing localization key: \(key)")
            return key
        }

        // Replace {{var}} placeholders
        for (name, value) in vars {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
        }

        return result
    }

    /// Pluralize: expects nested object like {"one": "1 file", "other": "{{n}} files"}
    func tp(_ key: String, count: Int) -> String {
        if let plural = strings[key] as? [String: String] ?? fallback[key] as? [String: String] {
            let form = count == 1 ? "one" : "other"
            if let template = plural[form] ?? plural["other"] {
                return template.replacingOccurrences(of: "{{n}}", with: "\(count)")
            }
        }
        return t(key, ["n": "\(count)"])
    }

    /// List all available locale files.
    /// Scans both the app bundle and ~/Library/Application Support/BDM/Locales/.
    func availableLocales() -> [(code: String, name: String, completion: Double)] {
        var locales: [(code: String, name: String, completion: Double)] = [
            ("en", "English", 1.0)
        ]
        var seenCodes: Set<String> = ["en"]

        // Collect locale JSON files from both bundle and Application Support
        var localeFiles: [(code: String, url: URL)] = []

        // 1. Scan the app bundle for locale JSON files
        if let bundleResourcePath = Bundle.main.resourceURL {
            if let bundleFiles = try? FileManager.default.contentsOfDirectory(
                at: bundleResourcePath, includingPropertiesForKeys: nil
            ) {
                for file in bundleFiles where file.pathExtension == "json" {
                    let code = file.deletingPathExtension().lastPathComponent
                    if code == "en" { continue }
                    localeFiles.append((code, file))
                }
            }
        }

        // 2. Scan Application Support (overrides bundle if same code exists)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let localesDir = appSupport?.appendingPathComponent("BDM/Locales")

        if let dir = localesDir,
           let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                let code = file.deletingPathExtension().lastPathComponent
                if code == "en" { continue }
                // Application Support overrides bundle — remove earlier bundle entry
                localeFiles.removeAll { $0.code == code }
                localeFiles.append((code, file))
            }
        }

        // 3. Build locale entries
        for (code, file) in localeFiles {
            guard !seenCodes.contains(code) else { continue }
            seenCodes.insert(code)

            if let data = try? Data(contentsOf: file),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let name = json["_language_name"] as? String ?? code
                let totalKeys = fallback.keys.filter { !$0.hasPrefix("_") }.count
                let translatedKeys = json.keys.filter { !$0.hasPrefix("_") && fallback[$0] != nil }.count
                let completion = totalKeys > 0 ? Double(translatedKeys) / Double(totalKeys) : 0

                locales.append((code, name, completion))
            }
        }

        return locales
    }
}
