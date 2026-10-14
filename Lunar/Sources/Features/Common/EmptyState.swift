import SwiftUI
import SwiftData

/// Shared empty-state card used across the Library tabs and the Import tab.
/// Animated on appear so the illustration feels intentional instead of static.
@MainActor
struct EmptyState<Content: View>: View {

    let title: String
    let message: String
    @ViewBuilder let content: () -> Content
    var primaryActionTitle: String? = nil
    var primaryAction: (() -> Void)? = nil

    @State private var shouldShow = false

    var body: some View {
        VStack(spacing: Spacing.l) {
            ZStack {
                content()
                    .foregroundStyle(ColorTokens.appAccent.opacity(0.9))
            }
            .frame(height: 120)
            .scaleEffect(shouldShow ? 1 : 0.82)
            .opacity(shouldShow ? 1 : 0)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(message)
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, Spacing.l)

            if let actionTitle = primaryActionTitle, let action = primaryAction {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, Spacing.l)
                        .padding(.vertical, Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(ColorTokens.appAccent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.canvas)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                shouldShow = true
            }
        }
    }
}

// MARK: - Shared library illustrations

struct LibraryEmptyIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.appAccent.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "music.note.list")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(ColorTokens.appAccent)
        }
    }
}

struct ArtistsEmptyIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.appAccent.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "person.2.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(ColorTokens.appAccent)
        }
    }
}

struct AlbumsEmptyIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.appAccent.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "square.stack.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(ColorTokens.appAccent)
        }
    }
}

struct SourceEmptyIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.appAccent.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "folder.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(ColorTokens.appAccent)
        }
    }
}
