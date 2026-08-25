import Testing
import Foundation
@testable import SwiftUIBlueprint

struct User: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

@Suite("Endpoint")
struct EndpointTests {
    private let base = URL(string: "https://api.example.com")!

    @Test("Path segments join without double slashes")
    func pathJoining() throws {
        let endpoint = Endpoint(baseURL: base).path("v1").path("/users/")
        #expect(endpoint.path == "v1/users")
        let request = try endpoint.makeURLRequest()
        #expect(request.url?.absoluteString == "https://api.example.com/v1/users")
    }

    @Test("Query values are percent-encoded")
    func queryEncoding() throws {
        let endpoint = Endpoint(baseURL: base)
            .path("search")
            .query(name: "q", value: "hello world")
            .query(name: "page", value: "2")
        let request = try endpoint.makeURLRequest()
        #expect(request.url?.absoluteString.contains("q=hello%20world") == true)
        #expect(request.url?.absoluteString.hasSuffix("page=2") == true)
    }

    @Test("Method and headers are applied")
    func methodAndHeaders() throws {
        let endpoint = Endpoint(baseURL: base, method: .post)
            .path("v1/things")
            .header(name: "Accept", value: "application/json")
        let request = try endpoint.makeURLRequest()
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("JSON bodies encode and stamp Content-Type once")
    func jsonBody() throws {
        let payload = User(id: 1, name: "Ada")
        let endpoint = try Endpoint(baseURL: base).jsonBody(payload)
        #expect(endpoint.headers["Content-Type"] == "application/json")
        let reApplied = try endpoint.jsonBody(payload)
        #expect(reApplied.headers["Content-Type"] == "application/json")

        var decoded = try JSONDecoder().decode(User.self, from: endpoint.body!)
        #expect(decoded == payload)
    }

    @Test("Per-request timeout overrides the default")
    func timeoutOverride() throws {
        let endpoint = Endpoint(baseURL: base).timeout(seconds: 7)
        #expect(try endpoint.makeURLRequest().timeoutInterval == 7)
    }
}
