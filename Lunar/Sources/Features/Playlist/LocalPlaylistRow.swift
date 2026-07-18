import SwiftUI

/// A single user-created playlist row in the Playlist tab.
@MainActor
struct LocalPlaylistRow: View {

    let playlist: Playlist

    var body: some View {
        HStack(spacing: Spacing.m) {
            iconThumb
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(Typography.body)
                    .fontWeight(.semibold)
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
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconThumb: some View {
        if playlist.title == "My Favorites" {
            ZStack {
                ColorTokens.elevated
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.destructive)
            }
        } else {
            ZStack {
                ColorTokens.elevated
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
