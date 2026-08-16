import Foundation

/// Detects a JavaScript runtime for the audited CLI bundled with the app.
enum RuntimeDetector {
    struct Runtime {
        let executablePath: String
        let name: String /// "bun" or "node"
        let cliPath: String

        var syncArguments: [String] {
            RuntimeDetector.syncArguments(cliPath: cliPath)
        }

        func snapshotArguments(for range: UsageQueryRange) -> [String] {
            RuntimeDetector.snapshotArguments(cliPath: cliPath, range: range)
        }
    }

    static func syncArguments(cliPath: String) -> [String] {
        [cliPath, "sync"]
    }

    static func snapshotArguments(cliPath: String, range: UsageQueryRange) -> [String] {
        [cliPath, "snapshot"] + range.localSnapshotArguments
    }

    static var bundledCLIPath: String? {
        Bundle.appResources.url(
            forResource: "vibe-usage",
            withExtension: "js",
            subdirectory: "vibe-usage-cli/bin"
        )?.path
    }

    /// Search common paths where node/bun might be installed
    private static let searchPaths: [String] = {
        // Start with PATH from environment
        var paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        // Add common install locations that might not be in PATH
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        paths.append(contentsOf: [
            "\(home)/.bun/bin",
            "\(home)/.volta/bin",
            "\(home)/.fnm/current/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/opt/local/bin",
        ])

        // nvm: resolve actual version directory (nvm doesn't create a "current" symlink)
        paths.append(contentsOf: resolveNvmPaths(home: home))

        return paths
    }()

    /// Resolve nvm node bin paths by reading ~/.nvm/alias/default or scanning versions directory.
    private static func resolveNvmPaths(home: String) -> [String] {
        let nvmDir = "\(home)/.nvm"
        let versionsDir = "\(nvmDir)/versions/node"
        let fm = FileManager.default

        // 1. Try reading ~/.nvm/alias/default to find the default version
        let aliasPath = "\(nvmDir)/alias/default"
        if let alias = try? String(contentsOfFile: aliasPath, encoding: .utf8) {
            let prefix = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty, let resolved = findNvmVersion(versionsDir: versionsDir, prefix: prefix, fm: fm) {
                return ["\(versionsDir)/\(resolved)/bin"]
            }
        }

        // 2. Fallback: pick the latest installed version (highest semver directory)
        if let entries = try? fm.contentsOfDirectory(atPath: versionsDir) {
            let sorted = entries
                .filter { $0.hasPrefix("v") }
                .sorted { compareVersions($0, $1) }
            if let latest = sorted.last {
                return ["\(versionsDir)/\(latest)/bin"]
            }
        }

        return []
    }

    /// Find the best matching nvm version directory for a given prefix (e.g. "22" matches "v22.22.0").
    private static func findNvmVersion(versionsDir: String, prefix: String, fm: FileManager) -> String? {
        // Normalize: "22" → "v22", "v22" → "v22", "lts/jod" → try lts alias
        var target = prefix
        if target.hasPrefix("lts/") {
            // Read lts alias: ~/.nvm/alias/lts/<name>
            let ltsName = String(target.dropFirst(4))
            let ltsAliasPath = "\(versionsDir)/../../alias/lts/\(ltsName)"
            if let ltsVersion = try? String(contentsOfFile: ltsAliasPath, encoding: .utf8) {
                target = ltsVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return nil
            }
        }

        let vPrefix = target.hasPrefix("v") ? target : "v\(target)"

        guard let entries = try? fm.contentsOfDirectory(atPath: versionsDir) else { return nil }
        // Find all versions matching prefix, pick highest
        let matches = entries
            .filter { $0.hasPrefix(vPrefix) && ($0 == vPrefix || $0.dropFirst(vPrefix.count).first == ".") }
            .sorted { compareVersions($0, $1) }
        return matches.last
    }

    /// Compare two version strings like "v22.11.0" and "v22.22.0" for sorting (ascending).
    private static func compareVersions(_ a: String, _ b: String) -> Bool {
        let partsA = a.dropFirst().split(separator: ".").compactMap { Int($0) }
        let partsB = b.dropFirst().split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va != vb { return va < vb }
        }
        return false
    }

    /// Detect the best available JS runtime
    static func detect() -> Runtime? {
        guard let cliPath = bundledCLIPath else { return nil }
        // Node is the reference runtime used by the vendored CLI's test suite.
        if let nodePath = findExecutable("node") {
            return Runtime(executablePath: nodePath, name: "node", cliPath: cliPath)
        }
        if let bunPath = findExecutable("bun") {
            return Runtime(executablePath: bunPath, name: "bun", cliPath: cliPath)
        }
        return nil
    }

    private static func findExecutable(_ name: String) -> String? {
        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}
