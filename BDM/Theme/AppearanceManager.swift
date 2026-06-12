import SwiftUI

/// Centralized appearance state. Controls Liquid Glass toggle and theme.
@Observable
final class AppearanceManager {
    /// Whether Liquid Glass background is enabled.
    var glassEnabled: Bool {
        didSet { UserDefaults.standard.set(glassEnabled, forKey: "bdm.appearance.glass") }
    }

    /// App theme preference.
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "bdm.appearance.theme") }
    }

    /// Default view mode.
    var viewMode: ViewMode {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "bdm.appearance.viewMode") }
    }

    /// Whether sidebar is visible.
    var showSidebar: Bool {
        didSet { UserDefaults.standard.set(showSidebar, forKey: "bdm.appearance.showSidebar") }
    }

    /// Whether the right-hand preview/detail panel is visible.
    var showPreview: Bool {
        didSet { UserDefaults.standard.set(showPreview, forKey: "bdm.appearance.showPreview") }
    }

    /// Whether the menu bar status icon is shown.
    var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "bdm.general.showMenuBarIcon") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.glassEnabled = defaults.object(forKey: "bdm.appearance.glass") as? Bool ?? true
        self.theme = AppTheme(rawValue: defaults.string(forKey: "bdm.appearance.theme") ?? "") ?? .system
        self.viewMode = ViewMode(rawValue: defaults.string(forKey: "bdm.appearance.viewMode") ?? "") ?? .detailed
        self.showSidebar = defaults.object(forKey: "bdm.appearance.showSidebar") as? Bool ?? true
        self.showPreview = defaults.object(forKey: "bdm.appearance.showPreview") as? Bool ?? true
        self.showMenuBarIcon = defaults.object(forKey: "bdm.general.showMenuBarIcon") as? Bool ?? true
    }
}

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ViewMode: String, CaseIterable {
    case detailed
    case compact
    case minimal
    case grid
    case table

    var displayName: String {
        switch self {
        case .detailed: return "Detailed"
        case .compact: return "Compact"
        case .minimal: return "Minimal"
        case .grid: return "Grid"
        case .table: return "Table"
        }
    }

    var localizationKey: String {
        switch self {
        case .detailed: return "view.detailed"
        case .compact: return "view.compact"
        case .minimal: return "view.minimal"
        case .grid: return "view.grid"
        case .table: return "view.table"
        }
    }

    var systemImage: String {
        switch self {
        case .detailed: return "list.bullet"
        case .compact: return "list.dash"
        case .minimal: return "line.3.horizontal"
        case .grid: return "square.grid.2x2"
        case .table: return "tablecells"
        }
    }
}
