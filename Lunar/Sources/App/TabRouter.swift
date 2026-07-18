import SwiftUI
import Observation

/// Shared tab selection state. Injected at the root so any view can
/// switch tabs (e.g. Library + button -> Import tab).
@MainActor
@Observable
final class TabRouter {
    var selectedTab: AppTab = .library
}
