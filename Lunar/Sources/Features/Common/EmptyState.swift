import SwiftUI

/// Reusable empty-state surface with MeloPlayer styling.
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
                .foregroundStyle(ColorTokens.appAccent.opacity(0.85))
                .padding(.bottom, Spacing.s)

            Text(title)
                .font(Typography.title2)
                .fontWeight(.bold)
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
                        .foregroundStyle(.black)
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
