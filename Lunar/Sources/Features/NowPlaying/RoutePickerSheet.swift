import SwiftUI
import AVKit

/// Liquid-glass sheet presenting the system AirPlay / audio output picker.
///
/// Wraps `AVRoutePickerView` so users can choose speakers, headphones,
/// or AirPlay destinations from within the app.
@MainActor
struct RoutePickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                VStack(spacing: Spacing.l) {
                    headerCard

                    RoutePickerRepresentable()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("AirPlay & Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "airplayaudio")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(ColorTokens.appAccent)

            Text("Choose where to play music")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text("Tap a device below to route audio.")
                .font(Typography.subhead)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.l)
        .modifier(ColorTokens.glassCard(cornerRadius: 22))
    }
}

// MARK: - Route Picker Representable

/// UIKit bridge for `AVRoutePickerView` inside the sheet.
private struct RoutePickerRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.tintColor = UIColor(ColorTokens.appAccent)
        picker.activeTintColor = UIColor(ColorTokens.textPrimary)
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        picker.isOpaque = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(ColorTokens.appAccent)
        uiView.activeTintColor = UIColor(ColorTokens.textPrimary)
    }
}
