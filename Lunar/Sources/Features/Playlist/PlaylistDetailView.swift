import SwiftUI
import SwiftData

/// Detail page for a single playlist.
@MainActor
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
        ScrollView {
            VStack(spacing: Spacing.m) {
                heroCard

                HStack(spacing: Spacing.s) {
                    Spacer()
                    pillButton(systemImage: "shuffle", label: "Shuffle", action: { playAll(shuffled: true) })
                    pillButton(systemImage: "play.fill", label: "Play All", action: { playAll(shuffled: false) })
                }
                .padding(.horizontal, Spacing.l)

                ForEach(songs) { song in
                    SongRow(
                        song: song,
                        onToggleFavorite: { libraryService?.toggleFavorite(song) }
                    )
                    .onTapGesture { tapped(song) }
                }
                .padding(.horizontal, Spacing.l)
            }
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
    }

    private func pillButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(Typography.subhead)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.appAccent)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                switch heroStyle {
                case .gradient(let colors):
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                    Image(systemName: "music.note")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                case .icon(let systemName):
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ColorTokens.appAccent.opacity(0.85))
                        .frame(width: 160, height: 160)
                    Image(systemName: systemName)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.black)
                case .heart:
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ColorTokens.destructive.opacity(0.85))
                        .frame(width: 160, height: 160)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(title)
                .font(Typography.title1)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.l)
    }

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
