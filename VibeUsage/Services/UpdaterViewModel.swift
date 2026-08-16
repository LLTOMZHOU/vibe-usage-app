import AppKit
import Combine

/// Hardened builds never install remote code automatically. This lightweight
/// bridge keeps the existing UI stable while directing update checks to the
/// fork's public release page for a human-reviewed download.
@MainActor
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = true
    @Published var availableUpdate: String?
    var isAvailable: Bool { true }

    func checkForUpdates() {
        guard let url = URL(string: "https://github.com/LLTOMZHOU/vibe-usage-app/releases") else { return }
        NSWorkspace.shared.open(url)
    }
}
