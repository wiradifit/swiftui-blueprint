import Foundation

/// Declarative retry behaviour applied by ``URLSessionHTTPClient``.
///
/// Only failures whose `APIError.isRetryable` is `true` ever reach the policy;
/// the policy then decides whether another attempt is allowed and how long to
/// wait before making it.
///
/// ```swift
/// let policy = RetryPolicy.exponential(
///     base: .seconds(0.5),
///     factor: 2,
///     cap: .seconds(8),
///     maxAttempts: 4
/// )
/// ```
public struct RetryPolicy: Sendable {
    /// Total number of attempts allowed, *including* the first one.
    public let maxAttempts: Int
    /// Delay before the retry following `attempt` n (1-indexed).
    private let delayForAttempt: @Sendable (Int) -> Duration

    /// A policy that never retries.
    public static let none = RetryPolicy(maxAttempts: 1) { _ in .zero }

    /// Constant-delay policy.
    public static func fixed(_ interval: Duration, maxAttempts: Int) -> RetryPolicy {
        precondition(maxAttempts >= 1, "maxAttempts must be >= 1")
        return RetryPolicy(maxAttempts: maxAttempts) { _ in interval }
    }

    /// Exponential backoff: `base * factor^(attempt-1)`, clamped to `cap`.
    public static func exponential(
        base: Duration = .milliseconds(250),
        factor: Double = 2,
        cap: Duration = .seconds(10),
        maxAttempts: Int = 3
    ) -> RetryPolicy {
        precondition(maxAttempts >= 1, "maxAttempts must be >= 1")
        return RetryPolicy(maxAttempts: maxAttempts) { attempt in
            // Portable exponential growth without libm: base * factor^(n-1).
            var multiplier = 1.0
            for _ in 1..<max(attempt, 1) { multiplier *= factor }
            return min(base * multiplier, cap)
        }
    }

    /// Full control over delays.
    public init(maxAttempts: Int, delayForAttempt: @escaping @Sendable (Int) -> Duration) {
        precondition(maxAttempts >= 1, "maxAttempts must be >= 1")
        self.maxAttempts = maxAttempts
        self.delayForAttempt = delayForAttempt
    }

    /// Whether another attempt may follow `attempt` for this error.
    public func shouldRetry(afterAttempt attempt: Int, error: APIError) -> Bool {
        guard error.isRetryable else { return false }
        return attempt < maxAttempts
    }

    /// The delay to apply after `attempt`.
    public func delay(afterAttempt attempt: Int) -> Duration {
        delayForAttempt(attempt)
    }

    /// Sleeps for `delay(afterAttempt:)`; throws `CancellationError` when the
    /// surrounding task is cancelled mid-backoff.
    public func waitForDelay(afterAttempt attempt: Int) async throws {
        try await Task.sleep(for: delay(afterAttempt: attempt))
    }
}
