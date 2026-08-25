import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// In-process `URLProtocol` stub used by networking tests.
///
/// Stubs are registered per URL *path* and may be dynamic (the responder runs
/// on every matching request, so tests can return different payloads across
/// retry attempts). All shared state is lock-guarded for strict concurrency.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Responder = @Sendable (_ requestCount: Int) -> Stub

    struct Stub {
        let response: HTTPURLResponse?
        let data: Data?
        let error: Error?
    }

    private static let lock = NSLock()
    // Guarded by `lock`; marked nonisolated(unsafe) for Swift 6 strict mode.
    // NOTE: tests run in parallel — state is keyed per URL path so suites
    // never interfere. Do not add global reset/count APIs.
    private nonisolated(unsafe) static var responders: [String: Responder] = [:]
    private nonisolated(unsafe) static var countsByPath: [String: Int] = [:]

    // MARK: Registration

    /// Stubs `path` to answer every request with `status` + JSON body.
    static func stub(path: String, status: Int, json: String) {
        stub(path: path) { _ in
            Stub(
                response: HTTPURLResponse(
                    url: URL(string: "https://stub.test\(path)")!,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!,
                data: json.data(using: .utf8),
                error: nil
            )
        }
    }

    /// Stubs `path` to fail at the transport level.
    static func stubTransportFailure(path: String, code: URLError.Code) {
        stub(path: path) { _ in
            Stub(response: nil, data: nil, error: URLError(code))
        }
    }

    /// Stubs `path` with a dynamic responder (used for retry sequences);
    /// receives how many times *this path* has been requested (1-indexed).
    static func stub(path: String, responder: @escaping Responder) {
        lock.lock(); defer { lock.unlock() }
        responders[path] = responder
        countsByPath[path] = 0
    }

    /// How many times `path` has been requested so far.
    static func requestCount(for path: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return countsByPath[path] ?? 0
    }

    // MARK: URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""

        Self.lock.lock()
        Self.countsByPath[path, default: 0] += 1
        let count = Self.countsByPath[path]!
        let responder = Self.responders[path]
        Self.lock.unlock()

        guard let stub = responder?(count) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
    }

    override func stopLoading() {}
}
