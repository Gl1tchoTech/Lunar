import SwiftUI

/// Color tokens shared across the app. **All views must pull from here** —
/// never hardcode hex values inside feature code.
///
/// Player Style chrome (`PlayerThemes.swift`) overrides these when the
/// Now Playing screen is showing.
enum ColorTokens {

    // MARK: — App-wide accent

    /// Primary accent (Dark UI / iOS settings tint).
    /// Locked decision: **Purple** (default when no theme override applies).
    static let appAccent: Color = .purple

    // MARK: — Surfaces

    static let canvas:   Color = .black
    static let surface:  Color = Color(white: 0.12)
    static let elevated: Color = Color(white: 0.18)
    static let hairline: Color = Color.white.opacity(0.08)

    // MARK: — Text

    static let textPrimary:   Color = .white
    static let textSecondary: Color = Color(white: 0.66)
    static let textTertiary:  Color = Color(white: 0.45)

    // MARK: — Semantic

    static let destructive: Color = Color(red: 1.0,  green: 0.27, blue: 0.23)
    static let warning:     Color = Color(red: 1.0,  green: 0.74, blue: 0.0)
    static let success:     Color = Color(red: 0.20, green: 0.84, blue: 0.40)

    // MARK: — Cyber Neon (default Player Theme)

    static let cyberNeonPink: Color = Color(red: 1.00, green: 0.42, blue: 0.74)
    static let cyberNeonCyan: Color = Color(red: 0.27, green: 0.92, blue: 1.00)
}
