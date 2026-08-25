import Testing
import Foundation
@testable import SwiftUIBlueprint

@Suite("RetryPolicy")
struct RetryPolicyTests {
    @Test("Exponential backoff grows by factor")
    func exponentialGrowth() {
        let policy = RetryPolicy.exponential(base: .milliseconds(250), factor: 2,
                                             cap: .seconds(10), maxAttempts: 5)
        #expect(policy.delay(afterAttempt: 1) == .milliseconds(250))
        #expect(policy.delay(afterAttempt: 2) == .milliseconds(500))
        #expect(policy.delay(afterAttempt: 3) == .seconds(1))
        #expect(policy.delay(afterAttempt: 4) == .seconds(2))
    }

    @Test("Cap clamps runaway delays")
    func capClamps() {
        let policy = RetryPolicy.exponential(base: .seconds(1), factor: 3,
                                             cap: .seconds(8), maxAttempts: 8)
        // 1 * 3^6 = 729 s, clamped to 8 s.
        #expect(policy.delay(afterAttempt: 7) == .seconds(8))
    }

    @Test("Fixed policy repeats one interval")
    func fixedDelay() {
        let policy = RetryPolicy.fixed(.milliseconds(30), maxAttempts: 4)
        #expect(policy.delay(afterAttempt: 1) == .milliseconds(30))
        #expect(policy.delay(afterAttempt: 3) == .milliseconds(30))
    }

    @Test("Never-retry policy makes exactly one attempt")
    func nonePolicy() {
        let policy = RetryPolicy.none
        #expect(policy.maxAttempts == 1)
        #expect(policy.shouldRetry(afterAttempt: 1, error: APIError.transport(URLError(.timedOut))) == false)
    }

    @Test("shouldRetry honours budget and error classification")
    func classificationMatrix() {
        let policy = RetryPolicy.exponential(maxAttempts: 3)

        // Budget: third attempt is final, nothing follows it.
        #expect(policy.shouldRetry(afterAttempt: 2, error: APIError.transport(URLError(.timedOut))) == true)
        #expect(policy.shouldRetry(afterAttempt: 3, error: APIError.transport(URLError(.timedOut))) == false)

        // Classification: transient statuses retry, client mistakes don't.
        let serverDown = APIError.unacceptableStatus(code: 503, response: nil, body: nil)
        let tooMany = APIError.unacceptableStatus(code: 429, response: nil, body: nil)
        let badRequest = APIError.unacceptableStatus(code: 400, response: nil, body: nil)
        let decode = APIError.decoding(URLError(.cannotDecodeContentData))

        #expect(serverDown.isRetryable == true)
        #expect(tooMany.isRetryable == true)
        #expect(badRequest.isRetryable == false)
        #expect(decode.isRetryable == false)
        #expect(policy.shouldRetry(afterAttempt: 1, error: badRequest) == false)
        #expect(policy.shouldRetry(afterAttempt: 1, error: decode) == false)
        #expect(policy.shouldRetry(afterAttempt: 1, error: APIError.cancelled) == false)
    }
}
