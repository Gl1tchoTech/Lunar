import SwiftUI

/// Floating mini-player card. Sits above the tab bar whenever a song
/// is loaded, hidden otherwise. Tap launches the full Now Playing.
@MainActor
struct MiniPlayer: View {

    @Binding var isPresented: Bool

    @Environment(AudioEngine.self) private var engine

    var body: some View {
        if engine.state.currentTitle.isEmpty {
            EmptyView()
        } else {
            Button {
                isPresented = true
            } label: {
                HStack(spacing: Spacing.s) {
                    artworkThumb
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.state.currentTitle)
                            .font(Typography.subhead)
                            .fontWeight(.semibold)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                        Text(engine.state.currentArtist)
                            .font(Typography.caption1)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Spacing.xs)

                    HStack(spacing: Spacing.xs) {
                        Button {
                            Task { await engine.send(.togglePlayPause) }
                        } label: {
                            Image(systemName: engine.state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 34, height: 34)
                                .background(ColorTokens.appAccent)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(engine.state.isPlaying ? "Pause" : "Play")

                        Button {
                            engine.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Next track")
                    }
                }
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .background(ColorTokens.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var artworkThumb: some View {
        ZStack {
            ColorTokens.elevated
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}
