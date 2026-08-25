import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftUIBlueprint

// NOTE: swift-testing executes suites in parallel. Every test below uses a
// unique URL path so the shared MockURLProtocol registry stays race-free.

@Suite("URLSessionHTTPClient")
struct HTTPClientTests {
    private func makeClient(retry: RetryPolicy) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSessionHTTPClient(session: URLSession(configuration: configuration), retry: retry)
    }

    private func endpoint(_ path: String) -> Endpoint {
        Endpoint(baseURL: URL(string: "https://stub.test")!).path(path)
    }

    @Test("Decodes a successful JSON response")
    func decodesSuccess() async throws {
        MockURLProtocol.stub(path: "/users", status: 200,
                             json: #"{"users":[{"id":1,"name":"Ada"},{"id":2,"name":"Alan"}]}"#)
        struct UsersEnvelope: Codable, Sendable { let users: [User] }

        let envelope = try await makeClient(retry: .none).fetch(endpoint("/users"), as: UsersEnvelope.self)
        #expect(envelope.users == [User(id: 1, name: "Ada"), User(id: 2, name: "Alan")])
        #expect(MockURLProtocol.requestCount(for: "/users") == 1)
    }

    @Test("Non-2xx maps to unacceptableStatus and does not retry by default")
    func statusErrorNoRetry() async {
        MockURLProtocol.stub(path: "/missing", status: 404, json: "{}")

        do {
            _ = try await makeClient(retry: RetryPolicy.fixed(.milliseconds(1), maxAttempts: 5))
                .send(endpoint("/missing").makeURLRequest())
            Issue.record("expected unacceptableStatus")
        } catch let error as APIError {
            guard case .unacceptableStatus(let code, _, _) = error else {
                Issue.record("wrong error: \(error)")
                return
            }
            #expect(code == 404)
            #expect(error.isRetryable == false)
            #expect(MockURLProtocol.requestCount(for: "/missing") == 1)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Transient 503 is retried until success within budget")
    func retriesThenSucceeds() async throws {
        MockURLProtocol.stub(path: "/flaky") { attempt in
            let status = attempt <= 2 ? 503 : 200
            return MockURLProtocol.Stub(
                response: HTTPURLResponse(url: URL(string: "https://stub.test/flaky")!,
                                          statusCode: status, httpVersion: nil, headerFields: nil)!,
                data: #"{"id":9,"name":"Grace"}"#.data(using: .utf8),
                error: nil
            )
        }

        let user = try await makeClient(
            retry: RetryPolicy.exponential(base: .milliseconds(1), factor: 2,
                                           cap: .milliseconds(5), maxAttempts: 3)
        ).fetch(endpoint("/flaky"), as: User.self)

        #expect(user.id == 9)
        #expect(MockURLProtocol.requestCount(for: "/flaky") == 3)
    }

    @Test("Retry budget exhaustion surfaces the last error")
    func retriesExhausted() async {
        MockURLProtocol.stub(path: "/down", status: 503, json: "{}")

        do {
            _ = try await makeClient(
                retry: RetryPolicy.exponential(base: .milliseconds(1), factor: 2,
                                               cap: .milliseconds(2), maxAttempts: 3)
            ).send(endpoint("/down").makeURLRequest())
            Issue.record("expected unacceptableStatus after exhausting retries")
        } catch let error as APIError {
            guard case .unacceptableStatus(let code, _, _) = error else {
                Issue.record("wrong error: \(error)")
                return
            }
            #expect(code == 503)
            #expect(MockURLProtocol.requestCount(for: "/down") == 3)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Decode failures are classified and never retried")
    func decodeFailureNotRetried() async {
        MockURLProtocol.stub(path: "/weird", status: 200, json: #"{"nonsense": true}"#)

        do {
            let _: User = try await makeClient(
                retry: RetryPolicy.fixed(.milliseconds(1), maxAttempts: 4)
            ).fetch(endpoint("/weird"))
            Issue.record("expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                Issue.record("wrong error: \(error)")
                return
            }
            #expect(error.isRetryable == false)
            #expect(MockURLProtocol.requestCount(for: "/weird") == 1)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Transport failures are retryable and retried")
    func transportRetries() async {
        MockURLProtocol.stubTransportFailure(path: "/offline", code: .notConnectedToInternet)

        do {
            _ = try await makeClient(
                retry: RetryPolicy.fixed(.milliseconds(1), maxAttempts: 2)
            ).send(endpoint("/offline").makeURLRequest())
            Issue.record("expected transport error")
        } catch let error as APIError {
            guard case .transport = error else {
                Issue.record("wrong error: \(error)")
                return
            }
            #expect(error.isRetryable == true)
            #expect(MockURLProtocol.requestCount(for: "/offline") == 2)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }
}
