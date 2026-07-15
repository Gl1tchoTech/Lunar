import SwiftUI

/// Circular pill row that sits under the sort chip in the Library
/// header. Two actions: **Shuffle** (crossed-arrows icon) and
/// **Play All** (play icon). Both are accent-tinted to read as
/// primary CTAs without dominating the layout.
@MainActor
struct LibraryActionRow: View {

    let totalSongs: Int
    let onShuffle: () -> Void
    let onPlayAll: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Spacer()
            actionPill(systemImage: "shuffle", action: onShuffle)
                .accessibilityLabel("Shuffle library")
            actionPill(systemImage: "play.fill", action: onPlayAll)
                .accessibilityLabel("Play all \(totalSongs) songs")
        }
        .padding(.trailing, Spacing.l)
    }

    private func actionPill(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(ColorTokens.appAccent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
