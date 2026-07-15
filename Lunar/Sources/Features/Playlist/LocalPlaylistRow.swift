import SwiftUI

/// A single user-created playlist row in the Playlist tab.
///
/// Layout: 48pt square icon thumb · title · `N songs | duration`.
/// `My Favorites` gets a heart glyph; user-created playlists get a
/// small tone-generic thumb.
struct LocalPlaylistRow: View {

    let playlist: Playlist

    var body: some View {
        HStack(spacing: Spacing.m) {
            iconThumb
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text("\(playlist.songs.count) song\(playlist.songs.count == 1 ? "" : "s") | \(formatTotal(playlistDuration))")
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconThumb: some View {
        if playlist.title == "My Favorites" {
            ZStack {
                ColorTokens.surface
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.destructive)
            }
        } else {
            ZStack {
                ColorTokens.surface
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private var playlistDuration: TimeInterval {
        playlist.songs.reduce(0.0) { $0 + $1.duration }
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
