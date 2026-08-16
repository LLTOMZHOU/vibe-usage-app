import Foundation

/// Small, dependency-free localization layer for the app's local-first UI.
///
/// The project is distributed as a Swift package rather than an Xcode project,
/// so keeping the paired strings here makes system-language behavior explicit
/// and works in both the packaged app and `swift test`. The preference is read
/// every time a view renders, so it follows the current macOS language after
/// the app is reopened.
enum AppStrings {
    static func text(_ chinese: String, _ english: String, languageIdentifier: String? = nil) -> String {
        let language = (languageIdentifier ?? Locale.preferredLanguages.first ?? Locale.autoupdatingCurrent.identifier)
            .lowercased()
        return language.hasPrefix("zh") ? chinese : english
    }
}
