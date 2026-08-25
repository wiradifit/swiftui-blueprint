import Testing
import Foundation
@testable import SwiftUIBlueprint

private struct Settings: Codable, Sendable, Equatable {
    var notificationsEnabled: Bool
    var displayName: String
}

@Suite("KeyValueStore")
struct KeyValueStoreTests {
    @Test("In-memory store round-trips strings and removals")
    func inMemoryBasics() {
        let store = InMemoryKeyValueStore()
        #expect(store.string(forKey: "greeting") == nil)

        store.setString("hello", forKey: "greeting")
        #expect(store.string(forKey: "greeting") == "hello")

        store.setString(nil, forKey: "greeting")
        #expect(store.string(forKey: "greeting") == nil)
        #expect(store.count == 0)
    }

    @Test("Codable helpers encode and decode values")
    func codableHelpers() throws {
        let store = InMemoryKeyValueStore()
        let settings = Settings(notificationsEnabled: true, displayName: "Jake")

        try store.setValue(settings, forKey: "settings")
        let restored: Settings? = try store.value(Settings.self, forKey: "settings")
        #expect(restored == settings)

        let missing: Settings? = try store.value(Settings.self, forKey: "absent")
        #expect(missing == nil)
    }

    @Test("In-memory store survives concurrent writers intact")
    func concurrentWrites() async {
        let store = InMemoryKeyValueStore()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    store.set("\(index)".data(using: .utf8), forKey: "key-\(index % 10)")
                }
            }
        }
        #expect(store.count == 10, "ten distinct keys expected after concurrent writes")
    }

    @Test("UserDefaults-backed store persists within its suite")
    func userDefaultsStore() throws {
        let suite = "blueprint-tests-\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let defaults = UserDefaults(suiteName: suite)!
        let store = UserDefaultsStore(defaults: defaults)

        store.setString("persisted", forKey: "flag")
        #expect(store.string(forKey: "flag") == "persisted")

        let settings = Settings(notificationsEnabled: false, displayName: "Lab")
        try store.setValue(settings, forKey: "settings")
        let restored: Settings? = try store.value(Settings.self, forKey: "settings")
        #expect(restored == settings)
    }
}
