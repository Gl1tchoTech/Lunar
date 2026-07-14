import SwiftUI
import SwiftData

/// A single song row for the Library "Songs" list.
///
/// Layout: 48pt square artwork thumb · title (1 line) · artist
/// (secondary, 1 line) · optional duration on the trailing edge.
struct SongRow: View {

    let song: Song
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            artworkThumb
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s)
            Text(durationString(song.duration))
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.xs)
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
                ColorTokens.surface
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .light))
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
