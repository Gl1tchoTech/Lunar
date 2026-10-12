import SwiftUI
import SwiftData

/// Library — Source tab.
@MainActor
struct SourceView: View {

    @Query private var songs: [Song]

    var body: some View {
        Group {
            if songs.isEmpty {
                EmptyState(
                    title: "No source yet",
                    message: "Once you import music, your Local Files and other-app sources will appear here.",
                    icon: { SourceEmptyIllustration() }
                )
            } else {
                sourceList
            }
        }
        .background(ColorTokens.canvas)
    }

    private var sourceList: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                HStack {
                    Text("\(songs.count) song\(songs.count == 1 ? "" : "s")")
                        .font(Typography.subhead)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)

                SourceRow(
                    title: "Local Files",
                    songCount: songs.count,
                    totalDuration: songs.reduce(0.0) { $0 + $1.duration }
                )
                .padding(.horizontal, Spacing.l)

                SourceRow(
                    title: "Other Apps",
                    songCount: 0,
                    totalDuration: 0
                )
                .padding(.horizontal, Spacing.l)
                .opacity(0.45)
            }
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
    }
}
