import SwiftUI

/// Color tokens shared across the app. **All views must pull from here** —
/// never hardcode hex values inside feature code.
///
/// Player Style chrome (`PlayerThemes.swift`) overrides these when the
/// Now Playing screen is showing.
enum ColorTokens {

    // MARK: — App-wide accent (MeloPlayer lime/yellow-green)

    /// Primary accent for the dark UI.
    static let appAccent: Color = Color(red: 0.78, green: 1.00, blue: 0.20)

    // MARK: — Surfaces

    static let canvas:   Color = .black
    static let surface:  Color = Color(white: 0.10)
    static let elevated: Color = Color(white: 0.16)
    static let hairline: Color = Color.white.opacity(0.08)

    /// Floating tab bar / mini-player glass background.
    static let glass: Color = Color(white: 0.12).opacity(0.95)

    // MARK: — Liquid Glass

    /// True liquid-glass material for floating chrome (tab bar, mini-player,
    /// sheets, cards). Use with `.background(.ultraThinMaterial)` or the
    /// `liquidGlass` helper view modifier.
    static let liquidGlass: some ViewModifier = LiquidGlassModifier()

    // MARK: — Text

    static let textPrimary:   Color = .white
    static let textSecondary: Color = Color(white: 0.62)
    static let textTertiary:  Color = Color(white: 0.40)

    // MARK: — Semantic

    static let destructive: Color = Color(red: 1.0,  green: 0.27, blue: 0.23)
    static let warning:     Color = Color(red: 1.0,  green: 0.74, blue: 0.0)
    static let success:     Color = Color(red: 0.20, green: 0.84, blue: 0.40)

    // MARK: — Cyber Neon (legacy Player Theme colors, kept for compatibility)

    static let cyberNeonPink: Color = Color(red: 1.00, green: 0.42, blue: 0.74)
    static let cyberNeonCyan: Color = Color(red: 0.27, green: 0.92, blue: 1.00)
}

// MARK: - Liquid Glass Modifier

private struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(ColorTokens.glass)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}
