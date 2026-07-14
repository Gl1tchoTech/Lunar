import SwiftUI
import Observation

// MARK: — PlayerThemeID

/// Identifies one of the six Player Style themes.
enum PlayerThemeID: String, CaseIterable, Identifiable, Codable {
    case cyberNeon      // default
    case vinylLime
    case aurora
    case vividOcean
    case sepiaWood
    case pastelPlayful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cyberNeon:     "Cyber Neon"
        case .vinylLime:     "Vinyl / Lime"
        case .aurora:        "Aurora"
        case .vividOcean:    "Vivid Ocean"
        case .sepiaWood:     "Sepia Wood"
        case .pastelPlayful: "Pastel Playful"
        }
    }
}

// MARK: — PlayerThemePalette

/// All colors required to render a single Player Style. Other UI elements
/// (toggles, CTAs outside Now Playing) keep using `ColorTokens`.
struct PlayerThemePalette: Equatable {
    let canvas:          [Color]    // 2-stop gradient, top → bottom
    let primaryText:     Color
    let secondaryText:   Color
    let accent:          Color      // play button, key UI
    let accentSecondary: Color?     // optional secondary accent
    let railBackground:  Color      // pill dock, transport row
    let progressTint:    Color
    let progressTrack:   Color

    var linearBackground: LinearGradient {
        LinearGradient(colors: canvas, startPoint: .top, endPoint: .bottom)
    }
}

extension PlayerThemePalette {

    static let cyberNeon = PlayerThemePalette(
        canvas:          [.black, Color(red: 0.08, green: 0.00, blue: 0.15)],
        primaryText:     .white,
        secondaryText:   Color(white: 0.66),
        accent:          Color(red: 1.00, green: 0.42, blue: 0.74),  // pink
        accentSecondary: Color(red: 0.27, green: 0.92, blue: 1.00),  // cyan
        railBackground:  Color.black.opacity(0.60),
        progressTint:    Color(red: 1.00, green: 0.42, blue: 0.74),
        progressTrack:   Color.white.opacity(0.15)
    )

    static let vinylLime = PlayerThemePalette(
        canvas:          [Color(red: 0.10, green: 0.18, blue: 0.05),
                          Color(red: 0.04, green: 0.06, blue: 0.02)],
        primaryText:     .white,
        secondaryText:   Color(white: 0.66),
        accent:          Color(red: 0.78, green: 1.00, blue: 0.20),
        accentSecondary: Color(red: 0.27, green: 0.92, blue: 1.00),
        railBackground:  Color.black.opacity(0.50),
        progressTint:    Color(red: 0.78, green: 1.00, blue: 0.20),
        progressTrack:   Color.white.opacity(0.15)
    )

    static let aurora = PlayerThemePalette(
        canvas:          [Color(red: 0.04, green: 0.08, blue: 0.32),
                          Color(red: 0.12, green: 0.04, blue: 0.28)],
        primaryText:     .white,
        secondaryText:   Color(white: 0.66),
        accent:          Color(red: 0.55, green: 0.45, blue: 1.00),
        accentSecondary: Color(red: 0.20, green: 0.80, blue: 1.00),
        railBackground:  Color.black.opacity(0.40),
        progressTint:    Color(red: 0.55, green: 0.45, blue: 1.00),
        progressTrack:   Color.white.opacity(0.15)
    )

    static let vividOcean = PlayerThemePalette(
        canvas:          [Color(red: 0.05, green: 0.45, blue: 0.85),
                          Color(red: 0.02, green: 0.20, blue: 0.55)],
        primaryText:     .white,
        secondaryText:   Color(white: 0.85),
        accent:          .white,
        accentSecondary: Color(red: 0.40, green: 0.90, blue: 1.00),
        railBackground:  Color.black.opacity(0.30),
        progressTint:    .white,
        progressTrack:   Color.white.opacity(0.20)
    )

    static let sepiaWood = PlayerThemePalette(
        canvas:          [Color(red: 0.98, green: 0.94, blue: 0.86),
                          Color(red: 0.82, green: 0.69, blue: 0.50)],
        primaryText:     Color(red: 0.30, green: 0.20, blue: 0.10),
        secondaryText:   Color(red: 0.45, green: 0.35, blue: 0.20),
        accent:          Color(red: 0.55, green: 0.32, blue: 0.10),
        accentSecondary: Color(red: 0.40, green: 0.22, blue: 0.06),
        railBackground:  Color(red: 0.95, green: 0.88, blue: 0.75),
        progressTint:    Color(red: 0.78, green: 1.00, blue: 0.20),
        progressTrack:   Color(red: 0.55, green: 0.32, blue: 0.10).opacity(0.25)
    )

    static let pastelPlayful = PlayerThemePalette(
        canvas:          [Color(red: 1.00, green: 0.80, blue: 0.86),
                          Color(red: 0.80, green: 0.94, blue: 1.00)],
        primaryText:     Color(red: 0.20, green: 0.10, blue: 0.30),
        secondaryText:   Color(red: 0.40, green: 0.30, blue: 0.45),
        accent:          Color(red: 0.85, green: 0.50, blue: 0.95),
        accentSecondary: Color(red: 1.00, green: 0.60, blue: 0.75),
        railBackground:  Color.white.opacity(0.65),
        progressTint:    Color(red: 0.85, green: 0.50, blue: 0.95),
        progressTrack:   Color.white.opacity(0.50)
    )
}

// MARK: — PlayerThemeManager

/// Holds the user's chosen Player Theme. Auto-persists to UserDefaults.
@Observable
final class PlayerThemeManager {
    static let storageKey = "Lunar.PlayerThemeID"

    var current: PlayerThemeID {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.current = stored.flatMap(PlayerThemeID.init(rawValue:)) ?? .cyberNeon
    }

    var palette: PlayerThemePalette {
        switch current {
        case .cyberNeon:     return .cyberNeon
        case .vinylLime:     return .vinylLime
        case .aurora:        return .aurora
        case .vividOcean:     return .vividOcean
        case .sepiaWood:      return .sepiaWood
        case .pastelPlayful:  return .pastelPlayful
        }
    }

    func setTheme(_ id: PlayerThemeID) {
        current = id
    }
}
