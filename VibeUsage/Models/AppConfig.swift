import Foundation

enum AppConfig {
    static let version = "0.5.7.4"

    /// This fork keeps credentials and upload state separate from the upstream
    /// app so installing either build cannot silently grant the other access.
    static let dataDirectory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0].appendingPathComponent("VibeUsageHardened", isDirectory: true)

    static let cliIdentityEnvironment = [
        "VIBE_USAGE_SURFACE": "mac-app",
        "VIBE_USAGE_SURFACE_VERSION": version,
    ]

    static var deviceAlias: String {
        let defaults = UserDefaults.standard
        let key = "privacyDeviceAlias"
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = "Mac-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        defaults.set(generated, forKey: key)
        return generated
    }

    private static let forwardedChildEnvironmentKeys: Set<String> = [
        "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "SHELL",
        "CODEX_HOME", "CLAUDE_CONFIG_DIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
        "XDG_CACHE_HOME", "KIMI_CODE_HOME", "MIMOCODE_HOME", "DSH_HOME",
    ]

    static func collectorEnvironment(
        inheriting base: [String: String] = ProcessInfo.processInfo.environment,
        runtimeDirectory: String,
        includeCloudCredentials: Bool = true
    ) -> [String: String] {
        var environment = base.filter { forwardedChildEnvironmentKeys.contains($0.key) }
        let inheritedPath = base["PATH"].map { ":\($0)" } ?? ""
        environment["PATH"] = runtimeDirectory + inheritedPath
        environment.merge(cliIdentityEnvironment) { _, appValue in appValue }
        environment["VIBE_USAGE_CONFIG_DIR"] = dataDirectory.path
        environment["VIBE_USAGE_STATE_DIR"] = dataDirectory.path
        environment["VIBE_USAGE_CACHE_DIR"] = dataDirectory.appendingPathComponent("cache").path
        environment["VIBE_USAGE_HOSTNAME"] = deviceAlias
        environment["VIBE_USAGE_UPLOAD_PROJECT"] = UserDefaults.standard.bool(forKey: "uploadProjectNames") ? "1" : "0"
        environment["VIBE_USAGE_UPLOAD_SESSIONS"] = UserDefaults.standard.bool(forKey: "uploadSessionMetadata") ? "1" : "0"
        environment["VIBE_USAGE_SHOW_IN_RANK"] = UserDefaults.standard.bool(forKey: "showInPublicLeaderboard") ? "1" : "0"
        if includeCloudCredentials, let apiKey = ConfigManager.load()?.apiKey {
            environment["VIBE_USAGE_API_KEY"] = apiKey
        }
        return environment
    }

    static func localCollectorEnvironment(
        inheriting base: [String: String] = ProcessInfo.processInfo.environment,
        runtimeDirectory: String
    ) -> [String: String] {
        var environment = collectorEnvironment(
            inheriting: base,
            runtimeDirectory: runtimeDirectory,
            includeCloudCredentials: false
        )
        // Defense in depth if the allowlist changes later.
        environment.removeValue(forKey: "VIBE_USAGE_API_KEY")
        return environment
    }

    /// Release builds only send credentials to the audited first-party origin.
    /// Debug builds retain localhost support for development.
    static func validatedServiceURL(_ candidate: String?) -> String {
        guard let candidate,
              let url = URL(string: candidate),
              let host = url.host?.lowercased()
        else { return defaultApiUrl }

        #if DEBUG
        if (url.scheme == "http" || url.scheme == "https"), host == "localhost" || host == "127.0.0.1" {
            return candidate
        }
        #endif

        guard url.scheme == "https", host == "vibecafe.ai", url.port == nil,
              url.user == nil, url.password == nil else {
            return defaultApiUrl
        }
        return defaultApiUrl
    }

    #if DEBUG
    static let defaultApiUrl = "http://localhost:3000"
    static let configFileName = "config.dev.json"
    static let isDev = true
    #else
    static let defaultApiUrl = "https://vibecafe.ai"
    static let configFileName = "config.json"
    static let isDev = false
    #endif
}
