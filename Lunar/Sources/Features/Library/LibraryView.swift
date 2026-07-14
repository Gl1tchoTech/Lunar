import SwiftUI

/// Library tab — placeholder. The full Songs / Artists / Albums / Source
/// tab strip, sort menu, and select mode will arrive in subsequent steps.
///
/// The empty state is the *only* state until the user imports music.
struct LibraryView: View {

    var body: some View {
        NavigationStack {
            EmptyState(
                title: "No music yet",
                message: "Import songs from your device to start building your library.",
                primaryActionTitle: nil,
                primaryAction: nil,
                icon: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60, weight: .light))
                }
            )
            .background(ColorTokens.canvas)
            .navigationTitle("Library")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}
