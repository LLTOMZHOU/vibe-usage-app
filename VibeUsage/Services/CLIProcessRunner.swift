import Foundation

/// Runs the bundled collector away from the cooperative executor. Output is
/// written to private temporary files so a full pipe cannot deadlock the child
/// and a descendant that inherits an output descriptor cannot delay completion.
enum CLIProcessRunner {
    struct Output: Sendable {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        let timedOut: Bool
    }

    private final class Control: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        var wasCancelled: Bool { lock.withLock { cancelled } }

        func register(_ process: Process) -> Bool {
            lock.withLock {
                guard !cancelled else { return false }
                self.process = process
                return true
            }
        }

        func unregister(_ process: Process) {
            lock.withLock {
                if self.process === process { self.process = nil }
            }
        }

        func cancel() {
            let process = lock.withLock { () -> Process? in
                cancelled = true
                return self.process
            }
            Self.stop(process)
        }

        static func stop(_ process: Process?) {
            guard let process, process.isRunning else { return }
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
    }

    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> Output {
        let control = Control()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let output = try execute(
                            executable: executable,
                            arguments: arguments,
                            environment: environment,
                            timeout: timeout,
                            control: control
                        )
                        if control.wasCancelled { throw CancellationError() }
                        continuation.resume(returning: output)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            control.cancel()
        }
    }

    private final class Deadline: @unchecked Sendable {
        let queue = DispatchQueue(label: "VibeUsage.CLIProcessDeadline")
        var expired = false
    }

    private static func execute(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
        control: Control
    ) throws -> Output {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe-usage-process-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let stdoutURL = directory.appendingPathComponent("stdout")
        let stderrURL = directory.appendingPathComponent("stderr")
        guard FileManager.default.createFile(
            atPath: stdoutURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ), FileManager.default.createFile(
            atPath: stderrURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let stdout = try FileHandle(forWritingTo: stdoutURL)
        defer { try? stdout.close() }
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer { try? stderr.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        guard control.register(process) else {
            Control.stop(process)
            process.waitUntilExit()
            throw CancellationError()
        }
        defer { control.unregister(process) }

        let deadline = Deadline()
        let killItem = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        let timeoutItem = DispatchWorkItem {
            guard process.isRunning else { return }
            deadline.expired = true
            process.terminate()
            deadline.queue.asyncAfter(deadline: .now() + 1, execute: killItem)
        }
        deadline.queue.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        process.waitUntilExit()
        let timedOut = deadline.queue.sync {
            timeoutItem.cancel()
            killItem.cancel()
            return deadline.expired
        }

        return Output(
            stdout: String(decoding: try Data(contentsOf: stdoutURL), as: UTF8.self),
            stderr: String(decoding: try Data(contentsOf: stderrURL), as: UTF8.self),
            exitCode: process.terminationStatus,
            timedOut: timedOut
        )
    }
}
