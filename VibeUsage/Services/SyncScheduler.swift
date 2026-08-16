import Foundation

/// Schedules periodic sync at a fixed interval (default 30 minutes)
@MainActor
final class SyncScheduler {
    private let interval: TimeInterval
    private let action: @Sendable () async -> Void
    // Dispatch sources are thread-safe but were not Sendable in Swift 6.0.
    // All lifecycle mutations remain isolated to this class's main actor.
    private nonisolated(unsafe) let timer = DispatchSource.makeTimerSource(
        queue: DispatchQueue.global(qos: .utility)
    )
    private var started = false

    /// - Parameters:
    ///   - interval: Seconds between syncs (default 1800 = 30 minutes)
    ///   - action: Async closure to execute on each tick
    init(interval: TimeInterval = 1800, action: @escaping @Sendable () async -> Void) {
        self.interval = interval
        self.action = action
    }

    func start() {
        guard !started else { return }
        started = true

        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .seconds(10)
        )
        timer.setEventHandler { [action] in
            Task {
                await action()
            }
        }
        timer.resume()
    }

    func stop() {
        guard started else { return }
        started = false
        timer.cancel()
    }

    deinit {
        if started {
            timer.cancel()
        }
    }
}
