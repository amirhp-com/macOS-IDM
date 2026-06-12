import SwiftUI
import AppKit

// MARK: - Transparent Window Helper

/// Makes the hosting NSWindow transparent so that `.ultraThinMaterial` and `.glassEffect()`
/// can show the desktop through the window. When glass is disabled, restores opaque background.
struct TransparentWindowFinder: NSViewRepresentable {
    var isGlassEnabled: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyWindowTransparency(view: view, glassEnabled: isGlassEnabled)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyWindowTransparency(view: nsView, glassEnabled: isGlassEnabled)
        }
    }

    private func applyWindowTransparency(view: NSView, glassEnabled: Bool) {
        guard let window = view.window else { return }
        if window.tabbingMode != .disallowed {
            window.tabbingMode = .disallowed
        }
        // QC/automation hook: keep the window reachable from any Space
        if ProcessInfo.processInfo.environment["BDM_QC_ALL_SPACES"] == "1",
           !window.collectionBehavior.contains(.canJoinAllSpaces) {
            window.collectionBehavior.insert(.canJoinAllSpaces)
        }
        // Only touch the window when the value actually changes — repeated
        // sets retrigger SwiftUI updates and can spin the layout loop.
        if glassEnabled {
            if window.isOpaque {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        } else {
            if !window.isOpaque {
                window.isOpaque = true
                window.backgroundColor = .windowBackgroundColor
            }
        }
    }
}

// MARK: - Conditional Glass Modifiers

/// Applies `.glassEffect(.regular)` when glass is on, solid background when off.
struct GlassCardModifier: ViewModifier {
    @Environment(AppearanceManager.self) private var appearance

    func body(content: Content) -> some View {
        if appearance.glassEnabled {
            content
                .glassEffect(.regular)
        } else {
            content
                .background(BDMColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(BDMColors.border, lineWidth: 1)
                )
        }
    }
}

/// Applies glass background material to a container.
struct GlassBackgroundModifier: ViewModifier {
    @Environment(AppearanceManager.self) private var appearance

    func body(content: Content) -> some View {
        if appearance.glassEnabled {
            // .regularMaterial keeps vibrancy but enough opacity to read text
            // over any wallpaper; .ultraThinMaterial was illegible on bright ones.
            content.background(.regularMaterial)
        } else {
            content.background(BDMColors.bg)
        }
    }
}

/// Interactive glass effect for buttons.
struct GlassButtonModifier: ViewModifier {
    @Environment(AppearanceManager.self) private var appearance

    func body(content: Content) -> some View {
        if appearance.glassEnabled {
            content
                .glassEffect(.regular.interactive())
        } else {
            content
                .background(BDMColors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(BDMColors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glass card effect (or solid fallback).
    func bdmGlassCard() -> some View {
        modifier(GlassCardModifier())
    }

    /// Apply glass background (or solid fallback).
    func bdmGlassBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }

    /// Apply interactive glass button (or solid fallback).
    func bdmGlassButton() -> some View {
        modifier(GlassButtonModifier())
    }
}

// MARK: - Color Palette (adapts to light/dark appearance)

enum BDMColors {
    /// Builds a Color that resolves per the effective appearance (follows the
    /// app's Theme setting via preferredColorScheme, and the system in Auto).
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static let bg = dynamic(light: rgb(0.957, 0.957, 0.969),      // #f4f4f7
                            dark: rgb(0.051, 0.051, 0.059))       // #0d0d0f
    static let surface = dynamic(light: rgb(1.0, 1.0, 1.0),       // #ffffff
                                 dark: rgb(0.086, 0.086, 0.102))  // #16161a
    static let surface2 = dynamic(light: rgb(0.925, 0.925, 0.945), // #ecedf1
                                  dark: rgb(0.118, 0.118, 0.141)) // #1e1e24
    static let surface3 = dynamic(light: rgb(0.894, 0.894, 0.918), // #e4e4ea
                                  dark: rgb(0.133, 0.133, 0.161)) // #222229
    static let border = dynamic(light: rgb(0.835, 0.835, 0.871),  // #d5d5de
                                dark: rgb(0.165, 0.165, 0.208))   // #2a2a35
    static let accent = Color(red: 0.357, green: 0.553, blue: 0.933)    // #5b8dee
    static let accent2 = Color(red: 0.486, green: 0.416, blue: 0.969)   // #7c6af7
    static let green = dynamic(light: rgb(0.078, 0.612, 0.380),   // #149c61
                               dark: rgb(0.243, 0.812, 0.557))    // #3ecf8e
    static let yellow = dynamic(light: rgb(0.788, 0.494, 0.0),    // #c97e00
                                dark: rgb(0.961, 0.651, 0.137))   // #f5a623
    static let red = dynamic(light: rgb(0.792, 0.196, 0.165),     // #ca322a
                             dark: rgb(0.898, 0.325, 0.294))      // #e5534b
    static let muted = dynamic(light: rgb(0.420, 0.420, 0.510),   // #6b6b82
                               dark: rgb(0.482, 0.482, 0.588))    // #7b7b96
    static let muted2 = dynamic(light: rgb(0.565, 0.565, 0.647),  // #9090a5
                                dark: rgb(0.333, 0.333, 0.416))   // #55556a
}
