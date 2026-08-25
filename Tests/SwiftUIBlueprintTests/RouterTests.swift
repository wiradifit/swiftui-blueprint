import Testing
import Foundation
@testable import SwiftUIBlueprint

enum TestRoute: Hashable, Sendable {
    case home
    case profile(id: Int)
    case settings
}

@MainActor
@Suite("Router")
struct RouterTests {
    @Test("Push appends, pop removes, popToRoot clears")
    func stackSemantics() {
        let router = Router<TestRoute>()
        #expect(router.currentPath.isEmpty)
        #expect(router.topRoute == nil)

        router.push(.home)
        router.push(.profile(id: 7))
        #expect(router.currentPath == [.home, .profile(id: 7)])
        #expect(router.topRoute == .profile(id: 7))

        #expect(router.pop() == .profile(id: 7))
        #expect(router.topRoute == .home)
        #expect(router.pop() == .home)
        #expect(router.pop() == nil, "popping an empty stack is a safe no-op")

        router.push(.settings)
        router.popToRoot()
        #expect(router.currentPath.isEmpty)
    }

    @Test("replaceTop swaps the top or seeds an empty stack")
    func replaceTop() {
        let router = Router<TestRoute>()
        router.replaceTop(with: .home)
        #expect(router.currentPath == [.home])

        router.push(.settings)
        router.replaceTop(with: .profile(id: 1))
        #expect(router.currentPath == [.home, .profile(id: 1)])
    }

    @Test("setPath installs arbitrary stacks and ignores identical values")
    func setPathDeduplicates() {
        let router = Router<TestRoute>()
        var changes = 0
        router.onChange = { changes += 1 }

        router.setPath([.home, .settings])
        router.setPath([.home, .settings])   // duplicate write: no notification
        router.setPath([])
        #expect(changes == 2)
    }

    @Test("onChange fires exactly once per mutation")
    func changeNotifications() {
        let router = Router<TestRoute>()
        var changes = 0
        router.onChange = { changes += 1 }

        router.push(.home)
        router.push(.settings)
        router.popToRoot()
        #expect(changes == 3)
    }
}
