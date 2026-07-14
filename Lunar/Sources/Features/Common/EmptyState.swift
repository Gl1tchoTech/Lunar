import SwiftUI

/// Reusable empty-state surface.
///
/// Used by every list-style screen until real data arrives:
/// - Centered SF Symbol (or custom View) on top
/// - Heading in `title2`
/// - Optional supporting copy
/// - Optional primary CTA pill
///
/// All views should compose this — never reimplement manually.
struct EmptyState<Icon: View>: View {

    let title: String
    let message: String?
    let primaryActionTitle: String?
    let primaryAction: (() -> Void)?
    @ViewBuilder let icon: () -> Icon

    init(
        title: String,
        message: String? = nil,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        @ViewBuilder icon: @escaping () -> Icon = {
            // Default returns bare `Image` so Swift can infer `Icon == Image`
            // at call sites that omit an explicit icon closure. Modifiers
            // (like `.font`) are applied in `body` instead so the generic
            // parameter still binds to `Image` cleanly.
            Image(systemName: "music.note")
        }
    ) {
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer(minLength: Spacing.xxl)

            icon()
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.bottom, Spacing.s)

            Text(title)
                .font(Typography.title2)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            if let primaryActionTitle, let primaryAction {
                Button(action: primaryAction) {
                    Text(primaryActionTitle)
                        .font(Typography.button)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.s)
                        .background(ColorTokens.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, Spacing.m)
            }

            Spacer(minLength: Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.l)
    }
}

#Preview {
    EmptyState(
        title: "No music yet",
        message: "Add songs to your library to start listening.",
        primaryActionTitle: "Import Music",
        primaryAction: { }
    )
    .background(ColorTokens.canvas)
    .preferredColorScheme(.dark)
}
