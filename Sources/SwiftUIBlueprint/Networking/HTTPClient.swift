import Foundation
#if canImport(FoundationNetworking)
// Linux/Windows: URL-loading types live in FoundationNetworking.
import FoundationNetworking
#endif

/// Minimal interface any HTTP transport must satisfy.
///
/// Conforming your own client (or using ``URLSessionHTTPClient``) keeps view
/// models testable: swap in a stub conforming to this protocol in tests.
public protocol HTTPClient: Sendable {
    /// Performs the request, returning raw data plus the HTTP response.
    /// Successful means "got a response" — status validation happens here and
    /// surfaces as `APIError.unacceptableStatus` for non-2xx codes.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public extension HTTPClient {
    /// Performs an ``Endpoint`` and decodes a successful JSON body into `T`.
    func fetch<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let request = try endpoint.makeURLRequest()
        let (data, _) = try await send(request)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    /// Performs an ``Endpoint``, ignoring the body (fire-and-forget calls).
    func run(_ endpoint: Endpoint) async throws {
        _ = try await send(endpoint.makeURLRequest())
    }
}

/// Production ``HTTPClient`` backed by `URLSession` with built-in retries.
///
/// The client applies a ``RetryPolicy`` to every failure that reports itself
/// as retryable (see `APIError.isRetryable`) and honours task cancellation
/// immediately — cancelling the surrounding `Task` aborts both the in-flight
/// request and any pending backoff sleep.
///
/// ```swift
/// let client = URLSessionHTTPClient(retry: .exponential(maxAttempts: 3))
/// let users: [User] = try await client.fetch(endpoint)
/// ```
/// `URLSession` is documented thread-safe, so the unchecked conformance only
/// silences the missing `Sendable` annotation on Linux toolchains.
public struct URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    private let retry: RetryPolicy

    /// - Parameters:
    ///   - session: A configured session. Defaults to an ephemeral one.
    ///   - retry: Policy describing how failures are retried.
    public init(session: URLSession = URLSession(configuration: .ephemeral), retry: RetryPolicy = .none) {
        self.session = session
        self.retry = retry
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await perform(request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.transport(URLError(.badServerResponse))
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw APIError.unacceptableStatus(code: http.statusCode, response: http, body: data)
                }
                return (data, http)
            } catch let error as APIError {
                guard error.isRetryable, retry.shouldRetry(afterAttempt: attempt, error: error) else {
                    throw error
                }
                try await retry.waitForDelay(afterAttempt: attempt)
            } catch is CancellationError {
                throw APIError.cancelled
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw APIError.cancelled
            }
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Wrapped through dataTask so the implementation is portable to every
        // Swift platform (including Linux) instead of relying on newer async
        // URLSession conveniences. In-flight cancellation is not wired to the
        // underlying session task; backoff sleeps between retries are fully
        // cancellable via Task.sleep.
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error as? URLError {
                    continuation.resume(throwing: APIError.transport(error))
                } else if let error = error {
                    continuation.resume(throwing: APIError.transport(
                        URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
                    ))
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: APIError.transport(URLError(.badServerResponse)))
                }
            }
            task.resume()
        }
    }
}
