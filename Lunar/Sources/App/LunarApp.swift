import SwiftUI

@main
struct LunarApp: App {
    @State private var theme = PlayerThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(theme)
                .preferredColorScheme(nil)   // follow System
                .tint(ColorTokens.appAccent)
        }
    }
}
