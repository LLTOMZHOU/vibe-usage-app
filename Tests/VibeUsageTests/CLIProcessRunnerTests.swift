import Foundation
import Testing
@testable import VibeUsage

struct CLIProcessRunnerTests {
    private func run(_ script: String, timeout: TimeInterval = 5) async throws -> CLIProcessRunner.Output {
        try await CLIProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", script],
            environment: ["PATH": "/usr/bin:/bin"],
            timeout: timeout
        )
    }

    @Test
    func capturesLargeOutputWithoutDeadlocking() async throws {
        let output = try await run("""
        head -c 262144 /dev/zero
        head -c 262144 /dev/zero >&2
        printf 'finished'
        """)
        #expect(output.exitCode == 0)
        #expect(!output.timedOut)
        #expect(output.stdout.utf8.count == 262144 + "finished".utf8.count)
        #expect(output.stderr.utf8.count == 262144)
    }

    @Test
    func timeoutKillsAProcessThatIgnoresTermination() async throws {
        let started = Date()
        let output = try await run("trap '' TERM; while :; do :; done", timeout: 0.1)
        #expect(output.timedOut)
        #expect(Date().timeIntervalSince(started) < 4)
        let result = await SyncEngine().interpret(output)
        guard case .failure(.timeout) = result else {
            Issue.record("Deadline was not reported as a timeout")
            return
        }
    }

    @Test
    func cancellationStopsAProcessThatIgnoresTermination() async throws {
        let started = Date()
        let task = Task {
            try await run("trap '' TERM; while :; do :; done", timeout: 30)
        }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Cancelled process unexpectedly completed")
        } catch is CancellationError { }
        #expect(Date().timeIntervalSince(started) < 4)
    }

    @Test
    func descendantKeepingOutputOpenDoesNotDelayCompletion() async throws {
        let started = Date()
        let output = try await run("sleep 2 & printf done")
        #expect(output.exitCode == 0)
        #expect(output.stdout == "done")
        #expect(Date().timeIntervalSince(started) < 1.5)
    }

    @Test
    func successfulStderrDoesNotFailSync() async throws {
        let output = try await run("printf 'launcher note' >&2; printf done")
        let result = await SyncEngine().interpret(output)
        guard case .success(let message) = result else {
            Issue.record("Successful exit was treated as a failure")
            return
        }
        #expect(message == "done")
    }

    @Test
    func failureKeepsBothOutputChannels() async throws {
        let output = try await run("printf 'primary error'; printf 'launcher error' >&2; exit 1")
        let result = await SyncEngine().interpret(output)
        guard case .failure(.processFailure(let message)) = result else {
            Issue.record("Nonzero exit was not reported")
            return
        }
        #expect(message.contains("primary error"))
        #expect(message.contains("launcher error"))
    }

    @Test
    func invalidExecutableFailsWithoutHanging() async {
        do {
            _ = try await CLIProcessRunner.run(
                executable: "/does-not-exist/vibe-usage",
                arguments: [],
                environment: [:],
                timeout: 0.1
            )
            Issue.record("Missing executable unexpectedly succeeded")
        } catch { }
    }
}
