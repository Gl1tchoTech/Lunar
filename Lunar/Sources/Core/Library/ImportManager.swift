import Foundation
import SwiftData

/// `@MainActor` queue + state holder for the import pipeline.
///
/// **Why a manager instead of inline state in `ImportView`?**
/// `onOpenURL` is delivered by the SwiftUI *scene*, so the handler
/// runs regardless of which tab is currently mounted. If the import
/// state lived inside `ImportView` (originally the case in
/// Steps 4 / 5), the URL handler would silently fail when the user
/// was on the Library tab. Hoisting the queue + `isImporting` flag +
/// last-batch / error surface into a long-lived observable means
/// an **"Open In..."** from Files / VLC / Shortcuts is processed
/// even while the user is listening on a different screen.
///
/// **Why a closure for the runner?** The manager is decoupled from
/// `ModelContext` — `LunarAppCoordinator` fills in the closure at
/// launch with `{ urls in try await MusicImporter(context: mainCtx)
/// .importFiles(at: urls) }`. This means tests can supply their own
/// runner closure without spinning up a real SwiftData environment.
///
/// **Concurrency contract:** `enqueue(_:)` / `enqueueMany(_:)` are
/// both `@MainActor` (the class is `@MainActor`-isolated). They
/// spin a single `runPending()` Task at a time. If two URLs arrive
/// before the first batch finishes, both are appended to
/// `pendingURLs` and consumed together at the next drain — the
/// queue never drops a URL.
///
/// **@MainActor + @Observable** — `ImportView` watches via the
/// environment, so any mutation publishes to subscribed views in the
/// same MainActor turn.
@MainActor
@Observable
final class ImportManager {

    // MARK: - Public observable state

    /// Incoming URLs that arrived via `.onOpenURL` (Other Apps
    /// handoff) and haven't been drained yet. Read-only from tests.
    var pendingURLs: [URL] = []

    /// True while a batch is being processed. Drives the toolbar
    /// spinner on `ImportView` (and could drive a guard banner on
    /// every other surface that wants to advertise "Lunar is
    /// working").
    var isImporting: Bool = false

    /// `PersistentIdentifier`s of songs inserted in the most recent
    /// batch. `ImportView` filters its **Imported Today** list off
    /// these; they survive view re-mounts.
    var lastImportIDs: [PersistentIdentifier] = []

    /// Latest user-facing error message, if any. Backing for the
    /// `ImportView` alert; cleared by the alert's OK handler.
    var importError: String?

    /// Heavy-lifting supplied by `LunarAppCoordinator`. Decouples
    /// the manager from `ModelContext` lookup so tests can wire a
    /// fake runner without an environment. Lazy-evaluated in
    /// `runPending()` so the manager can be constructed cleanly
    /// before the coordinator has wired the closure.
    var runner: (@MainActor ([URL]) async throws -> ImportResult)?

    // MARK: - Enqueue

    /// Single-URL entry from a SwiftUI `.onOpenURL` block.
    func enqueue(_ url: URL) {
        pendingURLs.append(url)
        scheduleDrain()
    }

    /// Multi-URL entry from `ImportView.fileImporter`. Appends to
    /// the queue, then schedules a drain.
    func enqueueMany(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        pendingURLs.append(contentsOf: urls)
        scheduleDrain()
    }

    /// Clear an already-displayed error (called by `ImportView`
    /// from its `alert` `OK` handler).
    func clearError() {
        importError = nil
    }

    // MARK: - Drain

    /// Spawn exactly one drain Task at a time. If a drain is
    /// already running or there's nothing queued, no new Task is
    /// spawned. If a drain happens to finish while another URL
    /// arrives, the next call to `scheduleDrain()` picks it up.
    private func scheduleDrain() {
        guard !isImporting, !pendingURLs.isEmpty else { return }
        Task { await self.runPending() }
    }

    /// Drain the next batch. Idempotent — if another drain is
    /// already in flight we return. Otherwise we take a snapshot of
    /// `pendingURLs`, clear it, flip `isImporting`, hand the batch
    /// to the runner, and capture either the inserted IDs or the
    /// error.
    private func runPending() async {
        guard !isImporting else { return }
        guard let runner else { return }
        guard !pendingURLs.isEmpty else { return }

        let batch = pendingURLs
        pendingURLs.removeAll(keepingCapacity: true)
        isImporting = true
        defer { isImporting = false }

        do {
            let result = try await runner(batch)
            lastImportIDs = result.inserted

            if !result.failed.isEmpty {
                let names = result.failed.prefix(3)
                    .map { ($0.url as NSURL).lastPathComponent ?? "?" }
                    .joined(separator: ", ")
                importError = "\(result.failed.count) file\(result.failed.count == 1 ? "" : "s") failed: \(names)"
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
