import XCTest
@testable import Lunar

/// `AppMetadata` is a small enum whose entire job is reproducing
/// Info.plist values + a repo URL without drifting across the
/// codebase. These tests pin the contract so a future refactor can't
/// silently change the Version/Build formatting the Settings UI shows.
final class AppMetadataTests: XCTestCase {

    func test_version_isNotUnknown_inTestBundle() {
        // The unit-test bundle always has a populated Info.plist.
        // Complain loudly if the gateway ever returns the fallback.
        XCTAssertNotEqual(AppMetadata.version, "unknown")
        XCTAssertFalse(AppMetadata.version.isEmpty)
    }

    func test_build_isNotUnknown_inTestBundle() {
        XCTAssertNotEqual(AppMetadata.build, "unknown")
        XCTAssertFalse(AppMetadata.build.isEmpty)
    }

    func test_versionAndBuild_format() {
        // Contract: `"<version> (<build>)"`. Views depend on this so
        // they don't reimplement it.
        let composite = AppMetadata.versionAndBuild
        XCTAssertTrue(composite.contains("("))
        XCTAssertTrue(composite.contains(")"))
        XCTAssertTrue(composite.hasPrefix(AppMetadata.version))
        XCTAssertTrue(composite.hasSuffix(AppMetadata.build))
    }

    func test_repositoryURL_pointsToCanonicalHome() {
        // Prevents an accidental `git@github.com:...` SSH URL from
        // sneaking in (which the `Link` view wouldn't render).
        XCTAssertEqual(AppMetadata.repositoryURL.scheme, "https")
        XCTAssertEqual(AppMetadata.repositoryURL.host, "github.com")
        XCTAssertEqual(
            AppMetadata.repositoryURL.path,
            "/Gl1tchoTech/Lunar"
        )
    }

    func test_bundleIdentifier_matchesProjectYml() {
        // Locks the bundle ID to `project.yml` so a fork renaming
        // the app gets caught here instead of in a regression
        // screenshot of Settings.
        XCTAssertEqual(AppMetadata.bundleIdentifier, "com.gl1tchotech.lunar")
    }

    func test_copyrightYear_isCurrentCalendarYear() {
        let current = Calendar.current.component(.year, from: Date())
        XCTAssertEqual(AppMetadata.copyrightYear, current)
    }

    func test_displayName_isLunar() {
        XCTAssertEqual(AppMetadata.displayName, "Lunar")
    }
}
