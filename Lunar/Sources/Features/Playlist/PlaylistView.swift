import SwiftUI

/// Playlist tab — placeholder. Smart playlists (Most Played, Recently
/// Played) and the Local Playlist creator arrive in subsequent steps.
struct PlaylistView: View {

    var body: some View {
        NavigationStack {
            EmptyState(
                title: "No playlists yet",
                message: "Create your first playlist to organize your music.",
                primaryActionTitle: nil,
                primaryAction: nil,
                icon: {
                    Image(systemName: "music.note.tv")
                        .font(.system(size: 60, weight: .light))
                }
            )
            .background(ColorTokens.canvas)
            .navigationTitle("Playlist")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    PlaylistView()
        .preferredColorScheme(.dark)
}
