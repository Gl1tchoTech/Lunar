import SwiftUI

/// Playback speed sheet. Lets the user adjust the time-pitch rate
/// of the currently playing audio.
@MainActor
struct PlaybackSpeedSheet: View {

    @Environment(AudioEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var rate: Double = 1.0

    private static let rates: [Double] = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                VStack(spacing: Spacing.l) {
                    Text(String(format: "%.1fx", rate))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.appAccent)
                        .monospacedDigit()

                    Slider(value: $rate, in: 0.5...2.0, step: 0.05)
                        .tint(ColorTokens.appAccent)
                        .padding(.horizontal, Spacing.l)

                    HStack(spacing: Spacing.s) {
                        ForEach(Self.rates, id: \.self) { preset in
                            Button {
                                rate = preset
                            } label: {
                                Text(String(format: "%.1fx", preset))
                                    .font(Typography.subhead)
                                    .fontWeight(rate == preset ? .bold : .medium)
                                    .foregroundStyle(rate == preset ? ColorTokens.canvas : ColorTokens.textPrimary)
                                    .padding(.horizontal, Spacing.m)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(rate == preset ? ColorTokens.appAccent : ColorTokens.surface)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, Spacing.l)
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.45), .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onChange(of: rate) { _, newValue in
            engine.setPlaybackRate(Float(newValue))
        }
    }
}
