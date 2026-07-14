import SwiftUI
import SwiftData

@main
struct LunarApp: App {

    /// App-wide SwiftData container. Built once at launch.
    let container: ModelContainer

    /// User-selected Player Theme (persisted via UserDefaults).
    @State private var theme = PlayerThemeManager()

    init() {
        do {
            container = try ModelContainer(for: LunarSchema.schema)
        } catch {
            // SwiftData failing to mount at launch is unrecoverable — abort
            // rather than launch into an inconsistent state.
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(theme)
                .preferredColorScheme(nil)   // follow System
                .tint(ColorTokens.appAccent)
        }
        .modelContainer(container)
    }

    // NOTE: First-launch EQ-preset seeding is performed in `RootView.task`
    // on the main context, NOT here. Doing it during `App.init` blocks
    // launch and (under Swift 6 strict concurrency) trips an isolation
    // warning because `ModelContext(container)` is a detached background
    // context, not `@MainActor`-isolated like `container.mainContext`.
}
