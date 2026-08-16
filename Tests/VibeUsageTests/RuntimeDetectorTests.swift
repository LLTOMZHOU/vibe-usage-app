import XCTest
@testable import VibeUsage

final class RuntimeDetectorTests: XCTestCase {
    func testBundledCLIIsExecutedDirectly() {
        XCTAssertEqual(
            RuntimeDetector.syncArguments(cliPath: "/App/cli/vibe-usage.js"),
            ["/App/cli/vibe-usage.js", "sync"]
        )
    }

    func testMacAppIdentityUsesTheDisplayVersion() {
        XCTAssertEqual(AppConfig.cliIdentityEnvironment["VIBE_USAGE_SURFACE"], "mac-app")
        XCTAssertEqual(AppConfig.cliIdentityEnvironment["VIBE_USAGE_SURFACE_VERSION"], AppConfig.version)
    }

    func testCollectorEnvironmentDropsAmbientSecretsAndRuntimeHooks() {
        let defaults = UserDefaults.standard
        let previousLeaderboardChoice = defaults.object(forKey: "showInPublicLeaderboard")
        defaults.removeObject(forKey: "showInPublicLeaderboard")
        defer {
            if let previousLeaderboardChoice {
                defaults.set(previousLeaderboardChoice, forKey: "showInPublicLeaderboard")
            } else {
                defaults.removeObject(forKey: "showInPublicLeaderboard")
            }
        }

        let environment = AppConfig.collectorEnvironment(
            inheriting: [
                "HOME": "/Users/test",
                "PATH": "/usr/bin",
                "OPENAI_API_KEY": "secret",
                "AWS_SECRET_ACCESS_KEY": "secret",
                "NODE_OPTIONS": "--require=/tmp/inject.js",
                "CODEX_HOME": "/Users/test/.codex",
            ],
            runtimeDirectory: "/opt/node/bin"
        )

        XCTAssertEqual(environment["HOME"], "/Users/test")
        XCTAssertEqual(environment["CODEX_HOME"], "/Users/test/.codex")
        XCTAssertEqual(environment["PATH"], "/opt/node/bin:/usr/bin")
        XCTAssertNil(environment["OPENAI_API_KEY"])
        XCTAssertNil(environment["AWS_SECRET_ACCESS_KEY"])
        XCTAssertNil(environment["NODE_OPTIONS"])
        XCTAssertEqual(environment["VIBE_USAGE_SHOW_IN_RANK"], "0")
    }

    func testReleaseServiceURLCannotBeRedirected() {
        XCTAssertEqual(
            AppConfig.validatedServiceURL("https://vibecafe.ai:444/other"),
            AppConfig.defaultApiUrl
        )
        XCTAssertEqual(
            AppConfig.validatedServiceURL("https://vibecafe.ai.evil.example"),
            AppConfig.defaultApiUrl
        )
    }
}
