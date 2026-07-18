import SwiftUI

/// Row representing a Source in the Library Source tab.
@MainActor
struct SourceRow: View {

    let title: String
    let songCount: Int
    let totalDuration: TimeInterval

    var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ColorTokens.warning.opacity(0.85))
                    .frame(width: 48, height: 48)
                Image(systemName: "folder.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text("\(songCount) song\(songCount == 1 ? "" : "s") | \(formatTotal(totalDuration))")
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .monospacedDigit()
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
