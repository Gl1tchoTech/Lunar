import SwiftUI

/// Real Settings ▸ About destination with MeloPlayer styling.
@MainActor
struct AboutView: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                HStack {
                    Text("About")
                        .font(Typography.display)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                }

                settingsGroup {
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

                settingsGroup {
                    Button {
                        openURL(AppMetadata.repositoryURL)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(ColorTokens.appAccent)
                                .frame(width: 28, height: 28)
                            Text("Source on GitHub")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
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
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .contentShape(Rectangle())
                    }
                }

                settingsGroup {
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
                        Text("MeloPlayer Dark · Lime")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }

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
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
        .background(ColorTokens.canvas)
        .navigationTitle("About")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ColorTokens.surface)
        )
    }
}
