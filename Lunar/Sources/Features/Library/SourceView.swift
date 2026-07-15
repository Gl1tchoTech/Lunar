import SwiftUI
import SwiftData

/// Library — Source tab. Today's data model doesn't natively split
/// songs into "Local Files" vs "Other Apps" sources. For Step 4 the
/// two rows are still listed so the tab is real and ready, with the
/// `Library Service` migration planned for Step 6.
///
/// Real implementation: a long-press song menu lets the user reassign
/// a song between Local and Imported buckets. For now every song is
/// counted as "Local Files".
@MainActor
struct SourceView: View {

    @Query private var songs: [Song]

    var body: some View {
        Group {
            if songs.isEmpty {
                EmptyState(
                    title: "No source yet",
                    message: "Once you import music, your Local Files and other-app sources will appear here.",
                    icon: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 60, weight: .light))
                    }
                )
            } else {
                sourceList
            }
        }
        .background(ColorTokens.canvas)
    }

    private var sourceList: some View {
        List {
            Section {
                sortChip
                    .listRowBackground(ColorTokens.canvas)
            }
            Section {
                // Step 4 simplified: every song lives in `Application Support/Music/`
                // (MusicLibrary). Filter on a future `Song.source: String?` field
                // is part of Step 6.
                SourceRow(
                    title: "Local Files",
                    songCount: songs.count,
                    totalDuration: songs.reduce(0.0) { $0 + $1.duration }
                )
                .listRowBackground(ColorTokens.canvas)
                SourceRow(
                    title: "Other Apps",
                    songCount: 0,
                    totalDuration: 0
                )
                .listRowBackground(ColorTokens.canvas)
                .opacity(0.45)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var sortChip: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.up.arrow.down")
            Text("Source (\(songs.count))")
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .font(Typography.subhead)
        .foregroundStyle(ColorTokens.textPrimary)
        .padding(.vertical, Spacing.s)
    }
}
