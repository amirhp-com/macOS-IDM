import SwiftUI

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
            content.background(.ultraThinMaterial)
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

// MARK: - Color Palette (solid fallback when glass is off)

enum BDMColors {
    static let bg = Color(red: 0.051, green: 0.051, blue: 0.059)        // #0d0d0f
    static let surface = Color(red: 0.086, green: 0.086, blue: 0.102)   // #16161a
    static let surface2 = Color(red: 0.118, green: 0.118, blue: 0.141)  // #1e1e24
    static let surface3 = Color(red: 0.133, green: 0.133, blue: 0.161)  // #222229
    static let border = Color(red: 0.165, green: 0.165, blue: 0.208)    // #2a2a35
    static let accent = Color(red: 0.357, green: 0.553, blue: 0.933)    // #5b8dee
    static let accent2 = Color(red: 0.486, green: 0.416, blue: 0.969)   // #7c6af7
    static let green = Color(red: 0.243, green: 0.812, blue: 0.557)     // #3ecf8e
    static let yellow = Color(red: 0.961, green: 0.651, blue: 0.137)    // #f5a623
    static let red = Color(red: 0.898, green: 0.325, blue: 0.294)       // #e5534b
    static let muted = Color(red: 0.482, green: 0.482, blue: 0.588)     // #7b7b96
    static let muted2 = Color(red: 0.333, green: 0.333, blue: 0.416)    // #55556a
}
