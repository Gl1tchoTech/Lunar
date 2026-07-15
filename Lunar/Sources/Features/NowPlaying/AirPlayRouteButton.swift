import SwiftUI
import AVKit

/// SwiftUI wrapper around `AVRoutePickerView` — the system
/// AirPlay / external-output picker.
///
/// **Why a wrapper?** AVRoutePickerView is UIKit-only (no SwiftUI
/// analog as of iOS 17). We expose a thin `UIViewRepresentable`
/// so it's a one-liner to drop into the Now Playing chrome.
///
/// **Sizing:** the picker produces an SF-Symbol-like glyph at its
/// natural size; we force `28×28` so it visually matches the adjacent
/// `SleepTimerChip` / `LyricsChip` capsules.
///
/// **Tinting:** the inactive glyph uses the player-theme primary
/// foreground so it reads against the dark Cyber Neon background;
/// the active/highlighted state uses the accent color so users see
/// a clear "currently routed" affordance.
struct AirPlayRouteButton: View {

    let palette: PlayerThemePalette

    var body: some View {
        AirPlayRoutePickerRepresentable(
            activeTint:   palette.accent,
            inactiveTint: palette.primaryText
        )
        .frame(width: 28, height: 28)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(palette.railBackground)
        )
        .accessibilityLabel("AirPlay & Speakers")
        .accessibilityHint("Opens the AirPlay / output picker")
    }
}

private struct AirPlayRoutePickerRepresentable: UIViewRepresentable {
    let activeTint:   Color
    let inactiveTint: Color

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        // Tint the glyph itself. Active covers when a non-default
        // route is selected; inactive covers the idle state.
        picker.tintColor       = UIColor(inactiveTint)
        picker.activeTintColor = UIColor(activeTint)
        // Prioritize the user's home audio device so a single tap
        // routes to the nearest Apple TV / HomePod, matching Apple
        // Music's default behaviour.
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        picker.isOpaque = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor       = UIColor(inactiveTint)
        uiView.activeTintColor = UIColor(activeTint)
    }
}
