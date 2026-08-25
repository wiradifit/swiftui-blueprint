import Foundation
#if canImport(FoundationNetworking)
// Linux/Windows: URL-loading types live in FoundationNetworking.
import FoundationNetworking
#endif

/// An HTTP verb with a fixed, well-known value.
public struct HTTPMethod: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let get = HTTPMethod(rawValue: "GET")
    public static let post = HTTPMethod(rawValue: "POST")
    public static let put = HTTPMethod(rawValue: "PUT")
    public static let patch = HTTPMethod(rawValue: "PATCH")
    public static let delete = HTTPMethod(rawValue: "DELETE")

    public var description: String { rawValue }
}

/// A declarative description of one API call.
///
/// `Endpoint` is a value type: build one with the fluent modifiers, then hand
/// it to an ``HTTPClient``. Keeping endpoints as plain values makes them easy
/// to unit test without any networking stack involved.
///
/// ```swift
/// let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!)
///     .path("v1/users")
///     .query(name: "page", value: "2")
///     .header(name: "Accept", value: "application/json")
/// ```
public struct Endpoint: Sendable {
    public var baseURL: URL
    public var method: HTTPMethod
    public var path: String
    public var queryItems: [URLQueryItem]
    public var headers: [String: String]
    public var body: Data?
    /// Per-request timeout in seconds. `nil` inherits the session default.
    public var timeout: TimeInterval?

    public init(baseURL: URL, method: HTTPMethod = .get, path: String = "") {
        self.baseURL = baseURL
        self.method = method
        self.path = path
        self.queryItems = []
        self.headers = [:]
        self.body = nil
        self.timeout = nil
    }

    /// Appends a path segment, taking care of slash joining.
    public func path(_ component: String) -> Endpoint {
        var copy = self
        let trimmedComponent = component.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedComponent.isEmpty else { return copy }
        if copy.path.hasSuffix("/") { copy.path += trimmedComponent }
        else if copy.path.isEmpty { copy.path = trimmedComponent }
        else { copy.path += "/" + trimmedComponent }
        return copy
    }

    /// Adds a query item. Values are percent-encoded when the URL is built.
    public func query(name: String, value: String) -> Endpoint {
        var copy = self
        copy.queryItems.append(URLQueryItem(name: name, value: value))
        return copy
    }

    /// Sets (or replaces) a request header.
    public func header(name: String, value: String) -> Endpoint {
        var copy = self
        copy.headers[name] = value
        return copy
    }

    /// Attaches a `Codable` body encoded as JSON.
    public func jsonBody<Body: Encodable & Sendable>(
        _ payload: Body,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Endpoint {
        var copy = self
        copy.body = try encoder.encode(payload)
        copy.headers["Content-Type"] = copy.headers["Content-Type"] ?? "application/json"
        return copy
    }

    /// Overrides the per-request timeout.
    public func timeout(seconds: TimeInterval) -> Endpoint {
        var copy = self
        copy.timeout = seconds
        return copy
    }

    /// Converts the description into a concrete `URLRequest`.
    /// - Throws: `APIError.invalidRequest` when no valid URL can be formed.
    public func makeURLRequest() throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = baseURL.path.hasSuffix("/")
            ? String(baseURL.path.dropLast())
            : baseURL.path
        components?.path = basePath + "/" + path
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        guard let url = components?.url else {
            throw APIError.invalidRequest("could not build URL from \(baseURL) + \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = timeout ?? request.timeoutInterval
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}
