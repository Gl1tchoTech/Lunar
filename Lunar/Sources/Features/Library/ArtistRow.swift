import SwiftUI
import SwiftData

/// Row representing a single artist in the Library Artists tab.
///
/// Layout: 48pt circular portrait · name (1 line) · `N songs | duration`.
///
/// Artists are derived on-the-fly from `Song.artistEntity` via the
/// `@Query` in `ArtistsView` — we don't store a separate row anymore.
struct ArtistRow: View {

    let artist: Artist

    var body: some View {
        HStack(spacing: Spacing.m) {
            artworkThumb
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(footerText)
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }

    private var footerText: String {
        let count = artist.songs.count
        let total = artist.songs.reduce(0.0) { $0 + $1.duration }
        return "\(count) song\(count == 1 ? "" : "s") | \(formatTotal(total))"
    }

    @ViewBuilder
    private var artworkThumb: some View {
        if let data = artist.artwork, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                ColorTokens.surface
                Image(systemName: "person.fill")
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
