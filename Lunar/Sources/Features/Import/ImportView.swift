import SwiftUI

/// Import tab — placeholder surface plus the persistent MiniPlayer +
/// Now Playing cover overlay (matches Library / Playlist).
/// Real Local Files / Wi-Fi Drive / Other Apps / Cloud Providers arrive
/// in Step 5.
struct ImportView: View {

    @Environment(AudioEngine.self) private var audioEngine
    @State private var presentingNowPlaying = false

    var body: some View {
        NavigationStack {
            EmptyState(
                title: "Nothing to import yet",
                message: "Bring music in from local files, your computer, or other apps.",
                primaryActionTitle: nil,
                primaryAction: nil,
                icon: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 60, weight: .light))
                }
            )
            .background(ColorTokens.canvas)
            .navigationTitle("Import")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
            .safeAreaInset(edge: .bottom) {
                MiniPlayer(isPresented: $presentingNowPlaying)
            }
        }
    }
}

#Preview {
    ImportView()
        .environment(AudioEngine())
        .preferredColorScheme(.dark)
}
