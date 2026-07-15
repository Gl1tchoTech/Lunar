import SwiftUI
import SwiftData

/// Row representing a single album in the Library Albums tab.
///
/// Layout: 56pt square cover · album title · artist · `N songs | duration`.
struct AlbumRow: View {

    let album: Album

    var body: some View {
        HStack(spacing: Spacing.m) {
            artworkThumb
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(album.artist)
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                Text(footerText)
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: Spacing.s)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }

    private var footerText: String {
        let count = album.songs.count
        let total = album.songs.reduce(0.0) { $0 + $1.duration }
        return "\(count) song\(count == 1 ? "" : "s") | \(formatTotal(total))"
    }

    @ViewBuilder
    private var artworkThumb: some View {
        if let data = album.artwork, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                ColorTokens.surface
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
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
