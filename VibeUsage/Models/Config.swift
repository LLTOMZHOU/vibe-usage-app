import Foundation
import Security

/// Non-secret metadata stored under Application Support. `apiKey` exists only
/// in memory after being loaded from Keychain; encoded files always omit it.
struct VibeUsageConfig: Codable {
    var apiKey: String?
    var apiUrl: String?
    var lastSync: String?
    var hostname: String?
}

enum ConfigManager {
    private static let configDir = AppConfig.dataDirectory
    private static let configFile = configDir.appendingPathComponent(AppConfig.configFileName)
    private static let keychainService = "io.github.lltzhou.vibe-usage-hardened"
    private static let keychainAccount = "vibecafe-api-key"

    static func load() -> VibeUsageConfig? {
        let keychainKey = loadAPIKey()
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return keychainKey.map {
                VibeUsageConfig(apiKey: $0, apiUrl: AppConfig.defaultApiUrl, hostname: AppConfig.deviceAlias)
            }
        }
        do {
            let data = try Data(contentsOf: configFile)
            var config = try JSONDecoder().decode(VibeUsageConfig.self, from: data)
            let validatedURL = AppConfig.validatedServiceURL(config.apiUrl)
            let metadataNeedsRewrite = config.apiUrl != validatedURL || config.hostname == nil
            config.apiUrl = validatedURL
            config.hostname = config.hostname ?? AppConfig.deviceAlias

            // One-way migration for an early hardened build: move a plaintext
            // key into Keychain, then immediately rewrite the metadata file.
            if let diskKey = config.apiKey, !diskKey.isEmpty, storeAPIKey(diskKey) {
                config.apiKey = nil
                writeMetadata(config)
                config.apiKey = diskKey
            } else {
                config.apiKey = keychainKey ?? config.apiKey
                if metadataNeedsRewrite {
                    var metadata = config
                    metadata.apiKey = nil
                    writeMetadata(metadata)
                }
            }
            return config
        } catch {
            print("Failed to load config: \(error)")
            return nil
        }
    }

    /// Save config to disk
    static func save(_ config: VibeUsageConfig) {
        guard let apiKey = config.apiKey, !apiKey.isEmpty, storeAPIKey(apiKey) else {
            print("Failed to save API key securely in Keychain")
            return
        }
        var metadata = config
        metadata.apiKey = nil
        metadata.apiUrl = AppConfig.validatedServiceURL(metadata.apiUrl)
        metadata.hostname = metadata.hostname ?? AppConfig.deviceAlias
        writeMetadata(metadata)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: configFile)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Check if config exists and has an API key
    static var isConfigured: Bool {
        load()?.apiKey != nil
    }

    private static func writeMetadata(_ config: VibeUsageConfig) {
        do {
            try FileManager.default.createDirectory(
                at: configDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: configDir.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFile.path)
        } catch {
            print("Failed to save config metadata: \(error)")
        }
    }

    private static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func storeAPIKey(_ apiKey: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }
}
