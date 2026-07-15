import SwiftUI

/// One of the two smart-playlist tiles at the top of the **Playlist**
/// tab. Mirrors the reference design: full-width rounded card,
/// gradient background, white SF Symbol centered, title + count subtitle.
///
/// Tapping the tile pushes `PlaylistDetailView` configured for the
/// matching smart playlist.
@MainActor
struct SmartPlaylistTile: View {

    enum Kind: Hashable {
        case favorites
        case mostPlayed
        case recentlyPlayed

        var title: String {
            switch self {
            case .favorites:       "My Favorites"
            case .mostPlayed:      "Most Played"
            case .recentlyPlayed:  "Recently Played"
            }
        }

        var systemImage: String {
            switch self {
            case .favorites:       "heart.fill"
            case .mostPlayed:      "music.note"
            case .recentlyPlayed:  "clock"
            }
        }

        /// Each tile uses a distinct pair so the user can read the
        /// smart-playlist context at a glance: warm-pink for Favorites
        /// (matches the heart hero used by `PlaylistDetailView` when
        /// it sees a playlist named "My Favorites"), then cool→warm
        /// gradients for Most Played / Recently Played.
        var gradient: [Color] {
            switch self {
            case .favorites:       [.red, .pink]
            case .mostPlayed:      [.blue, .teal]
            case .recentlyPlayed:  [.teal, .green]
            }
        }
    }

    let kind: Kind
    let songCount: Int
    let totalDuration: TimeInterval
    let action: () -> Void

    /// Debounce flag — prevents a double-tap from enqueueing two
    /// `NavigationStack` pushes for the same destination. Springs
    /// back enabled after a short delay. Without this, the tile can
    /// be pushed twice rapidly when the user double-taps, which
    /// `NavigationStack` handles oddly (back-twice to dismiss).
    @State private var didTap: Bool = false

    var body: some View {
        Button {
            guard !didTap else { return }
            didTap = true
            action()
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                didTap = false
            }
        } label: {
            VStack(spacing: Spacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: kind.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.white)
                }
                .padding(.top, Spacing.l)

                VStack(spacing: 2) {
                    Text(kind.title)
                        .font(Typography.title2)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("\(songCount) song\(songCount == 1 ? "" : "s") | \(formatTotal(totalDuration))")
                        .font(Typography.subhead)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                }
                .padding(.bottom, Spacing.l)
            }
            .frame(maxWidth: .infinity)
            .background(ColorTokens.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ColorTokens.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatTotal(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = total / 60
        let s = total % 60
        if h > 0 { return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))" }
        return "\(m):\(String(format: "%02d", s))"
    }
}
