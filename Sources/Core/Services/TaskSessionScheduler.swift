import Foundation

@MainActor
public final class TaskSessionScheduler: SessionScheduling {
    private var task: Task<Void, Never>?
    private let now: () -> Date

    public var hasScheduledAction: Bool { task != nil }

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    deinit {
        task?.cancel()
    }

    public func schedule(
        deadline: Date,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        cancel()
        let delay = max(0, deadline.timeIntervalSince(now()))
        task = Task { @MainActor [weak self] in
            do {
                if delay > 0 {
                    try await Task<Never, Never>.sleep(for: .seconds(delay))
                }
                try Task<Never, Never>.checkCancellation()
                action()
            } catch {
                // Cancellation is the normal rescheduling path.
            }
            self?.task = nil
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
