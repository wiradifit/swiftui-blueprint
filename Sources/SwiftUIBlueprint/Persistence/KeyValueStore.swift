import Foundation

/// Tiny persistence abstraction over key–data stores.
///
/// Conformances ship for `UserDefaults` (real device storage) and an
/// in-memory store (previews, tests). Codable helpers live in extensions so
/// conformers only need the three primitive operations.
public protocol KeyValueStore: Sendable {
    func set(_ data: Data?, forKey key: String)
    func data(forKey key: String) -> Data?
}

public extension KeyValueStore {
    /// Encodes `value` as JSON under `key`.
    ///
    /// Named distinctly from the `Data?` requirement so overload resolution
    /// can never recurse into this generic helper.
    func setValue<T: Encodable & Sendable>(
        _ value: T,
        forKey key: String,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        set(try encoder.encode(value), forKey: key)
    }

    /// Decodes JSON previously stored under `key`.
    func value<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: String,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try decoder.decode(T.self, from: data)
    }

    /// Stores (or removes) a string value.
    func setString(_ string: String?, forKey key: String) {
        set(string?.data(using: .utf8), forKey: key)
    }

    /// Reads back a string value.
    func string(forKey key: String) -> String? {
        data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// `UserDefaults`-backed store.
///
/// ```swift
/// let store = UserDefaultsStore(suiteName: "com.example.app")
/// try store.setValue(UserSettings.default, forKey: "settings")
/// ```
/// `UserDefaults` is documented thread-safe; `@unchecked` only bridges the
/// missing `Sendable` annotation on Linux toolchains.
public struct UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults

    /// - Parameter suiteName: Passed through to `UserDefaults(suiteName:)`;
    ///   `nil` uses `.standard`.
    public init(suiteName: String?) {
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func set(_ data: Data?, forKey key: String) {
        defaults.set(data, forKey: key)
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }
}

/// Thread-safe volatile store for previews and unit tests.
public final class InMemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data]

    public init(initial: [String: Data] = [:]) {
        self.storage = initial
    }

    public func set(_ data: Data?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = data
    }

    public func data(forKey key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    /// Current number of entries (diagnostics/testing aid).
    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return storage.count
    }
}
