import Foundation
import SwiftUI

/// JSON-based localization engine.
/// Loads en.json from bundle, overlays user locale from Application Support.
@Observable
final class BDMLocalizer {
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
    func load(locale: String) {
        currentLocale = locale

        if locale == "en" {
            strings = fallback
            isRTL = false
            return
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let localeURL = appSupport?
            .appendingPathComponent("BDM/Locales/\(locale).json")

        guard let url = localeURL,
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
    func availableLocales() -> [(code: String, name: String, completion: Double)] {
        var locales: [(code: String, name: String, completion: Double)] = [
            ("en", "English", 1.0)
        ]

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let localesDir = appSupport?.appendingPathComponent("BDM/Locales")

        guard let dir = localesDir,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return locales
        }

        for file in files where file.pathExtension == "json" {
            let code = file.deletingPathExtension().lastPathComponent
            if code == "en" { continue }

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
