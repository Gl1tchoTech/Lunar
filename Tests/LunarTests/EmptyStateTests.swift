import XCTest
import SwiftUI
@testable import Lunar

/// Smoke tests ensuring the EmptyState surface compiles for every supported
/// configuration. Runtime snapshot checks live in `LunarSnapshotTests`.
final class EmptyStateTests: XCTestCase {

    func test_init_withTitleOnly_compiles() {
        // Icon inferred as `Image` from the default closure.
        let view = EmptyState(title: "Test")
        let _: EmptyState<Image> = view   // make the inferred type explicit
    }

    func test_init_withAllProperties_compiles() {
        var tapped = false
        let view = EmptyState<EmptyView>(
            title: "Test",
            message: "Test message",
            primaryActionTitle: "Tap",
            primaryAction: { tapped = true },
            icon: { EmptyView() }
        )
        let _: EmptyState<EmptyView> = view
        _ = tapped
    }
}
