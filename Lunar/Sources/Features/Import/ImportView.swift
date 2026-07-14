import SwiftUI

/// Import tab — placeholder. The full Local Files / Wi-Fi Drive / Other
/// Apps / Cloud Providers surface arrives in a later step.
struct ImportView: View {

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
        }
    }
}

#Preview {
    ImportView()
        .preferredColorScheme(.dark)
}
