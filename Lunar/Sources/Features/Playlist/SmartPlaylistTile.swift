import SwiftUI

/// Smart-playlist tile with MeloPlayer styling.
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

        var gradient: [Color] {
            switch self {
            case .favorites:       [Color(red: 1.00, green: 0.30, blue: 0.30), Color(red: 1.00, green: 0.50, blue: 0.50)]
            case .mostPlayed:      [Color(red: 0.20, green: 0.60, blue: 1.00), Color(red: 0.40, green: 0.80, blue: 1.00)]
            case .recentlyPlayed:  [Color(red: 0.20, green: 0.80, blue: 0.40), Color(red: 0.40, green: 1.00, blue: 0.60)]
            }
        }
    }

    let kind: Kind
    let songCount: Int
    let totalDuration: TimeInterval
    let action: () -> Void

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
                        .fontWeight(.bold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("\(songCount) song\(songCount == 1 ? "" : "s") | \(formatTotal(totalDuration))")
                        .font(Typography.subhead)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                }
                .padding(.bottom, Spacing.l)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ColorTokens.surface)
            )
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
