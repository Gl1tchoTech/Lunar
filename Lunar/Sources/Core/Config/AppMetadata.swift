import Foundation

/// Runtime accessor for app-level metadata that ships in
/// `Info.plist` + `project.yml`.
///
/// Centralises three things that would otherwise get hand-copied into
/// every Settings row, About screen, footer, or bug-report template:
///
/// 1. **`version`** — `CFBundleShortVersionString` (driven by
///    `MARKETING_VERSION` in `project.yml`, e.g. `"0.4.0"`).
/// 2. **`build`** — `CFBundleVersion` (driven by
///    `CURRENT_PROJECT_VERSION` in `project.yml`, e.g. `"47"`).
/// 3. **`repositoryURL`** — canonical home of the source. Single source
///    of truth so the About row, share sheets, and bug-report links
///    all stay in sync.
///
/// Falls back to a tier-0 marker (`"unknown"`) when the bundle keys are
/// missing — this surfaces the misconfiguration loudly instead of
/// silently shipping a blank version string in the UI.
enum AppMetadata {

    // MARK: - Public, read-only

    /// User-facing version (e.g. `"0.4.0"`).
    static let version: String = {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "unknown"
    }()

    /// Build number (e.g. `"47"`). Bumped per TestFlight / release in
    /// `project.yml` → `CURRENT_PROJECT_VERSION`.
    static let build: String = {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
            ?? "unknown"
    }()

    /// Source repository. Lives here (not `project.yml`) because it's
    /// surfaced in user-facing UI links — bundling the URL next to
    /// version metadata keeps "where is this from?" answered in one place.
    static let repositoryURL: URL = {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/Gl1tchoTech/Lunar")!
    }()

    /// Bundle identifier — handy in bug-report copy.
    static let bundleIdentifier: String = {
        Bundle.main.bundleIdentifier ?? "com.unknown.app"
    }()

    /// Display name as the user sees it on the Home Screen.
    static let displayName: String = {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? "Lunar"
    }()

    /// Copyright year. Centralised so the About footer doesn't drift
    /// from the actual ship year when the marketing version advances.
    static let copyrightYear: Int = {
        // Read system locale's current year — keeps it accurate even
        // when the binary lives across midnight on Dec 31.
        Calendar.current.component(.year, from: Date())
    }()

    /// `MARKETING_VERSION (CFBundleVersion)`, pre-formatted for the
    /// most common About-row layout (e.g. `"0.4.0 (47)"`). Saves
    /// Views from reimplementing the format.
    static var versionAndBuild: String {
        "\(version) (\(build))"
    }
}
