import XCTest
import SwiftUI
@testable import Lunar

/// Bootstrap smoke test ensuring the snapshot target compiles.
/// Real per-screen snapshot snapshots arrive once each screen stabilizes.
final class BootstrapSnapshotTests: XCTestCase {

    func test_target_compiles() {
        // Once `swift-snapshot-testing` (or an equivalent) is wired in,
        // real reference snapshots will live here. For now this exists so
        // `xcodebuild test` against this scheme has at least one passing test.
        XCTAssertTrue(true, "Snapshot target compiled cleanly")
    }

    @MainActor
    func test_lunarApp_canBeReferenced() {
        // Confirms the `@testable import Lunar` actually exports LunarApp
        // and the symbols we depend on across the codebase.
        // `@MainActor` is required because `LunarApp` (and the SwiftUI
        // `App` protocol in general) is main-actor isolated.
        _ = LunarApp()
    }
}
