import Foundation

/// Executes the audited CLI source bundled inside the app.
actor SyncEngine {
    static let shared = SyncEngine()

    enum SyncResult {
        case success(String)
        case failure(SyncError)
    }

    enum SyncError: LocalizedError {
        case noRuntime
        case unauthorized
        case processFailure(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .noRuntime:
                AppStrings.text("未检测到 Node.js 或 Bun，请先安装", "Node.js or Bun was not found. Install one first.")
            case .unauthorized:
                AppStrings.text("API Key 无效，请重新配置", "Invalid API key. Please configure it again.")
            case .processFailure(let msg):
                AppStrings.text("同步失败: \(msg)", "Sync failed: \(msg)")
            case .timeout:
                AppStrings.text("同步超时", "Sync timed out")
            }
        }
    }

    private var isRunning = false

    func runSync() async -> Result<String, SyncError> {
        guard !isRunning else {
            return .success(AppStrings.text("同步已在进行中", "Sync is already in progress"))
        }
        isRunning = true
        defer { isRunning = false }

        guard let runtime = RuntimeDetector.detect() else {
            return .failure(.noRuntime)
        }

        let runtimeDir = (runtime.executablePath as NSString).deletingLastPathComponent
        var environment = AppConfig.collectorEnvironment(runtimeDirectory: runtimeDir)
        #if DEBUG
        environment["VIBE_USAGE_DEV"] = "1"
        #endif

        do {
            let output = try await CLIProcessRunner.run(
                executable: runtime.executablePath,
                arguments: runtime.syncArguments,
                environment: environment,
                timeout: 120
            )
            return interpret(output)
        } catch is CancellationError {
            return .failure(.processFailure(AppStrings.text("同步已取消", "Sync cancelled")))
        } catch {
            return .failure(.processFailure(error.localizedDescription))
        }
    }

    func interpret(_ output: CLIProcessRunner.Output) -> Result<String, SyncError> {
        if output.timedOut { return .failure(.timeout) }

        let stdout = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        debugLog("[SyncEngine] Exit: \(output.exitCode), stdout bytes: \(output.stdout.utf8.count), stderr bytes: \(output.stderr.utf8.count)")

        if output.exitCode == 0 {
            return .success(stdout.isEmpty ? AppStrings.text("同步完成", "Sync complete") : stdout)
        }

        let combined = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
        if combined.contains("Invalid API key") || combined.contains("UNAUTHORIZED") {
            return .failure(.unauthorized)
        }
        return .failure(.processFailure(friendlyFailureMessage(combined, exitCode: output.exitCode)))
    }

    private func friendlyFailureMessage(_ message: String, exitCode: Int32) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Exit code \(exitCode)" }

        if trimmed.contains("RangeError: Invalid string length")
            || trimmed.contains("node:internal/readline") {
            return AppStrings.text("本地同步工具读取历史记录时崩溃（RangeError: Invalid string length）。请更新 @vibe-cafe/vibe-usage 后重试；订阅配额监控可在设置中单独开启或关闭。", "The local sync tool crashed while reading history (RangeError: Invalid string length). Update @vibe-cafe/vibe-usage and try again; subscription-limit monitoring can be enabled or disabled separately in Settings.")
        }

        return trimmed
    }
}
