import SwiftUI

/// Slider for the Now Playing screen. Bidirectionally bound to
/// `AudioEngine.state.currentTime`. Sliding seeks into the song; release
/// commits the seek.
struct ScrubBar: View {

    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager

    @State private var dragValue: Double = 0
    @State private var isDragging: Bool = false

    var body: some View {
        let palette = themeManager.palette
        let duration = max(engine.state.duration, 0.001)
        let display = isDragging ? dragValue : engine.state.currentTime
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { display },
                    set: { newValue in
                        dragValue = newValue
                        isDragging = true
                    }
                ),
                in: 0...duration,
                onEditingChanged: { editing in
                    if !editing {
                        isDragging = false
                        let t = min(duration, max(0, dragValue))
                        // `engine.send(.seek(t))` already updates `state.currentTime`
                        // inside the engine — no direct write needed here.
                        Task { await engine.send(.seek(t)) }
                    }
                }
            )
            .tint(palette.progressTint)
            .background(palette.progressTrack)

            HStack {
                Text(formatTime(display))
                    .font(Typography.monoCaption)
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
                Spacer()
                Text(formatTime(duration))
                    .font(Typography.monoCaption)
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
