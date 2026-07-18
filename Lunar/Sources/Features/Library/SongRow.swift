import SwiftUI
import SwiftData

/// A single song row for the Library "Songs" list.
@MainActor
struct SongRow: View {

    let song: Song
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            artworkThumb
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.s)

            if song.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.appAccent)
            }

            Text(durationString(song.duration))
                .font(Typography.caption1)
                .foregroundStyle(ColorTokens.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artworkThumb: some View {
        if let data = song.artwork, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                ColorTokens.elevated
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
