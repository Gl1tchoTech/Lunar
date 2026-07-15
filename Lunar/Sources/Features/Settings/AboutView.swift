import SwiftUI

/// Real **Settings ▸ About** destination.
///
/// Surfaces three things:
/// 1. Runtime version + build (read from `AppMetadata`, not hardcoded
///    so a TestFlight bump shows up without touching this file).
/// 2. A tappable link to the source repository.
/// 3. A credits row so the moon icon stack doesn't feel anonymous.
///
/// Designed to look at home next to `PlayerStyleView` and
/// `AppThemeView` — same inset-grouped list, same `ColorTokens.canvas`
/// background, same chevron language (none here, by design).
struct AboutView: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            // MARK: App identity
            Section {
                LabeledContent {
                    Text(AppMetadata.versionAndBuild)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                } label: {
                    Label("Version", systemImage: "number")
                }
                LabeledContent("Build") {
                    Text(AppMetadata.build)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                }
                LabeledContent("Bundle") {
                    Text(AppMetadata.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            // MARK: Source
            Section {
                Button {
                    openURL(AppMetadata.repositoryURL)
                } label: {
                    HStack {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Link(destination: AppMetadata.repositoryURL) {
                    HStack {
                        Text(AppMetadata.repositoryURL.absoluteString)
                            .font(.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
            } header: {
                Text("Source")
            } footer: {
                Text("Lunar is local-first. The source tree is the spec.")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // MARK: Credits
            Section {
                LabeledContent("UI") {
                    Text("SwiftUI + iOS 17+")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                LabeledContent("Audio") {
                    Text("AVAudioEngine + AVAudioUnitEQ")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                LabeledContent("Storage") {
                    Text("SwiftData @Model")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                LabeledContent("Theme") {
                    Text("Cyber Neon · Purple accent")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            } header: {
                Text("Credits")
            }

            // MARK: Footer
            Section {
                EmptyView()
            } footer: {
                VStack(spacing: 4) {
                    Text("\u{1F319} \(AppMetadata.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text("Made with care in Xcode · © \(AppMetadata.copyrightYear)")
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.canvas)
        .navigationTitle("About")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
