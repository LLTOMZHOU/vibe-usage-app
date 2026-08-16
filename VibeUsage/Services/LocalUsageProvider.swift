import Foundation

/// Reads supported AI-tool logs through the audited bundled collector and
/// decodes a dashboard snapshot. It never receives an API key and the invoked
/// command has no dependency on the collector's upload client.
actor LocalUsageProvider {
    nonisolated static let shared = LocalUsageProvider()

    enum LocalUsageError: LocalizedError {
        case noRuntime
        case processFailure(String)
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .noRuntime:
                return "未检测到 Node.js 或 Bun，请先安装后刷新"
            case .processFailure(let message):
                return "本地读取失败：\(message)"
            case .invalidResponse(let message):
                return "本地数据格式异常：\(message)"
            }
        }
    }

    private var isRunning = false

    func fetch(range: UsageQueryRange) async throws -> UsageResponse {
        while isRunning {
            try await Task.sleep(for: .milliseconds(100))
        }
        isRunning = true
        defer { isRunning = false }

        guard let runtime = RuntimeDetector.detect() else {
            throw LocalUsageError.noRuntime
        }

        try FileManager.default.createDirectory(
            at: AppConfig.dataDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let identifier = UUID().uuidString
        let stdoutURL = AppConfig.dataDirectory.appendingPathComponent("snapshot-\(identifier).json")
        let stderrURL = AppConfig.dataDirectory.appendingPathComponent("snapshot-\(identifier).log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer {
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: runtime.executablePath)
        process.arguments = runtime.snapshotArguments(for: range)
        let runtimeDirectory = (runtime.executablePath as NSString).deletingLastPathComponent
        process.environment = AppConfig.localCollectorEnvironment(runtimeDirectory: runtimeDirectory)
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + 120,
                execute: timeoutItem
            )
            process.waitUntilExit()
            timeoutItem.cancel()
            try stdoutHandle.synchronize()
            try stderrHandle.synchronize()
        } catch {
            throw LocalUsageError.processFailure(error.localizedDescription)
        }

        let stderrData = (try? Data(contentsOf: stderrURL)) ?? Data()
        let stderr = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw LocalUsageError.processFailure(stderr.isEmpty ? "Exit code \(process.terminationStatus)" : stderr)
        }

        do {
            let data = try Data(contentsOf: stdoutURL)
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw LocalUsageError.invalidResponse(error.localizedDescription)
        }
    }
}
