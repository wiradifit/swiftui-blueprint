import Foundation
#if canImport(FoundationNetworking)
// Linux/Windows: URL-loading types live in FoundationNetworking.
import FoundationNetworking
#endif

/// Errors produced by ``HTTPClient`` implementations.
///
/// The error intentionally separates transport-level failures (no response at
/// all) from HTTP-status failures (a response arrived, but not a success one)
/// and payload-decoding failures, because those three classes usually demand
/// different handling in app code.
public enum APIError: Error, Sendable {

    /// The endpoint could not be converted into a valid request URL.
    case invalidRequest(String)

    /// The request failed before a response arrived (offline, DNS, TLS…).
    case transport(URLError)

    /// The request was cancelled before completion.
    case cancelled

    /// A response arrived with a non-2xx status code.
    case unacceptableStatus(code: Int, response: HTTPURLResponse?, body: Data?)

    /// A 2xx response arrived but its body could not be decoded as `T`.
    case decoding(Error)

    /// `true` when retrying the same request might plausibly succeed.
    ///
    /// Transport failures and transient server-side statuses (408, 429, 5xx)
    /// are retryable; client mistakes (bad URL, 4xx), decode failures and
    /// cancellations are not.
    public var isRetryable: Bool {
        switch self {
        case .invalidRequest, .decoding, .cancelled:
            return false
        case .transport:
            return true
        case .unacceptableStatus(let code, _, _):
            return Self.transientStatuses.contains(code)
        }
    }

    /// Status codes generally considered worth retrying.
    public static let transientStatuses: Set<Int> = [408, 429, 500, 502, 503, 504]
}

extension APIError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidRequest(let why):
            return "invalidRequest(\(why))"
        case .transport(let error):
            return "transport(\(error.code.rawValue))"
        case .cancelled:
            return "cancelled"
        case .unacceptableStatus(let code, _, _):
            return "unacceptableStatus(\(code))"
        case .decoding(let error):
            return "decoding(\(error))"
        }
    }
}
