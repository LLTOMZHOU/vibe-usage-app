import Foundation

/// Reads supported AI-tool logs through the audited bundled collector and
/// decodes a dashboard snapshot. It never receives an API key and the invoked
/// command has no dependency on the collector's upload client.
actor LocalUsageProvider {
    nonisolated static let shared = LocalUsageProvider()

    enum LocalUsageError: LocalizedError {
        case noRuntime
        case timeout
        case processFailure(String)
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .noRuntime:
                return AppStrings.text("未检测到 Node.js 或 Bun，请先安装后刷新", "Node.js or Bun was not found. Install one, then refresh.")
            case .timeout:
                return AppStrings.text("本地读取超时", "Local read timed out")
            case .processFailure(let message):
                return AppStrings.text("本地读取失败：\(message)", "Local read failed: \(message)")
            case .invalidResponse(let message):
                return AppStrings.text("本地数据格式异常：\(message)", "Local data format error: \(message)")
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

        let runtimeDirectory = (runtime.executablePath as NSString).deletingLastPathComponent
        let output: CLIProcessRunner.Output
        do {
            output = try await CLIProcessRunner.run(
                executable: runtime.executablePath,
                arguments: runtime.snapshotArguments(for: range),
                environment: AppConfig.localCollectorEnvironment(runtimeDirectory: runtimeDirectory),
                timeout: 120
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LocalUsageError.processFailure(error.localizedDescription)
        }

        if output.timedOut { throw LocalUsageError.timeout }
        let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.exitCode == 0 else {
            throw LocalUsageError.processFailure(stderr.isEmpty ? "Exit code \(output.exitCode)" : stderr)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: Data(output.stdout.utf8))
        } catch {
            throw LocalUsageError.invalidResponse(error.localizedDescription)
        }
    }
}
