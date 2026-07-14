import SwiftUI

/// Row representing a `Source` (Local Files / Other Apps) in the
/// Library Source tab.
///
/// Layout: yellow folder icon (40pt square) · title · `N songs | duration`.
struct SourceRow: View {

    let title: String
    let songCount: Int
    let totalDuration: TimeInterval

    var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTokens.warning)
                    .frame(width: 40, height: 40)
                Image(systemName: "folder.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text("\(songCount) song\(songCount == 1 ? "" : "s") | \(formatTotal(totalDuration))")
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .monospacedDigit()
            }
            Spacer(minLength: Spacing.s)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
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
