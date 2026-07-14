import SwiftUI
import SwiftData

/// Detail page for a single playlist. Reused for:
/// - **Smart playlists** (Most Played, Recently Played) — `heroStyle = .gradient`
/// - **My Favorites** (predicate rendered at runtime) — `heroStyle = .heart`
/// - **User-created playlists** — `heroStyle = .icon`
///
/// Push from `PlaylistView`. Tapping a song plays it + opens Now Playing.
struct PlaylistDetailView: View {

    enum HeroStyle {
        case gradient(colors: [Color])
        case icon(systemName: String)
        case heart
    }

    let title: String
    let subtitle: String?
    let heroStyle: HeroStyle
    let songs: [Song]

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var presentingNowPlaying = false

    var body: some View {
        Group {
            if songs.isEmpty {
                EmptyState(
                    title: "Nothing here yet",
                    message: title == "My Favorites"
                        ? "Tap the heart on any song to add it to your favorites."
                        : "This playlist is empty.",
                    icon: { Image(systemName: "music.note.list") }
                )
            } else {
                playlistList
            }
        }
        .background(ColorTokens.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $presentingNowPlaying) {
            NowPlayingView()
                .environment(audioEngine)
        }
        .task {
            if libraryService == nil {
                libraryService = LibraryService(context: modelContext)
            }
        }
    }

    private var playlistList: some View {
        List {
            Section {
                heroCard
                    .listRowBackground(ColorTokens.canvas)
                    .listRowSeparator(.hidden)
                LibraryActionRow(
                    totalSongs: songs.count,
                    onShuffle: { playAll(shuffled: true) },
                    onPlayAll: { playAll(shuffled: false) }
                )
                .listRowBackground(ColorTokens.canvas)
            }
            Section {
                ForEach(songs) { song in
                    SongRow(
                        song: song,
                        onToggleFavorite: { libraryService?.toggleFavorite(song) }
                    )
                    .listRowBackground(ColorTokens.canvas)
                    .onTapGesture { tapped(song) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var heroCard: some View {
        switch heroStyle {
        case .gradient(let colors):
            VStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                    switch heroStyle {
                    case .gradient:  Image(systemName: "music.note").font(.system(size: 64)).foregroundStyle(.white)
                    default: EmptyView()
                    }
                }
                Text(title)
                    .font(Typography.title1)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
        case .icon(let systemName):
            VStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ColorTokens.appAccent.opacity(0.85))
                        .frame(width: 160, height: 160)
                    Image(systemName: systemName)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(Typography.title1)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
        case .heart:
            VStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ColorTokens.destructive.opacity(0.85))
                        .frame(width: 160, height: 160)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(Typography.title1)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
        }
    }

    // MARK: - Actions

    private func playAll(shuffled: Bool) {
        let list = shuffled ? songs.shuffled() : songs
        guard let service = libraryService else { return }
        let requests = service.playbackRequests(for: list)
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func tapped(_ song: Song) {
        guard let service = libraryService else { return }
        let (requests, startIndex) = service.playbackRequests(
            for: songs,
            startingAt: song.persistentModelID
        )
        audioEngine.playQueue(requests, startIndex: startIndex)
        presentingNowPlaying = true
    }
}
