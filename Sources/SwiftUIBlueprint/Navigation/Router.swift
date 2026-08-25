import Foundation
#if canImport(Combine)
import Combine
#endif

/// Headless, platform-neutral navigation state machine driving a
/// `NavigationStack` on Apple platforms (see ``RouterView``).
///
/// The core deliberately contains **no** UI-framework types so it can be unit
/// tested anywhere Swift runs. On Apple platforms a thin additive extension
/// makes `Router` an `ObservableObject`; everywhere else the lightweight
/// `onChange` hook is available instead.
///
/// ```swift
/// enum AppRoute: Hashable { case home, profile(id: Int) }
/// let router = Router<AppRoute>()
/// router.push(.profile(id: 7))
/// ```
@MainActor
public final class Router<Route: Hashable & Sendable> {
    /// Fired after every mutation of the navigation stack.
    public var onChange: (() -> Void)?

    #if canImport(Combine)
    /// Combine publisher driving SwiftUI updates on Apple platforms.
    ///
    /// `ObservableObject.objectWillChange` is a *nonisolated* protocol
    /// requirement, so the witness must be reachable from outside the main
    /// actor even though `Router` itself is `@MainActor`. This is safe:
    /// `ObservableObjectPublisher` is internally thread-safe, and SwiftUI
    /// only subscribes/fires it from the main thread, where every `Router`
    /// mutation occurs.
    nonisolated(unsafe) public let objectWillChange = ObservableObjectPublisher()
    #endif

    private var storage: [Route] = []

    /// Creates an empty stack (the root view lives outside the stack).
    public init() {}

    /// The active stack, excluding the implicit root. Last element = top.
    public var currentPath: [Route] { storage }

    /// The route currently on top, or `nil` when only the root is visible.
    public var topRoute: Route? { storage.last }

    /// Replaces the whole stack (used by the `NavigationStack` binding).
    public func setPath(_ newPath: [Route]) {
        guard storage != newPath else { return }
        storage = newPath
        notify()
    }

    /// Appends `route` to the top of the stack.
    public func push(_ route: Route) {
        storage.append(route)
        notify()
    }

    /// Removes the top route. No-op when only the root is visible.
    @discardableResult
    public func pop() -> Route? {
        guard !storage.isEmpty else { return nil }
        defer { notify() }
        return storage.removeLast()
    }

    /// Clears the stack back to the root.
    public func popToRoot() {
        guard !storage.isEmpty else { return }
        storage.removeAll()
        notify()
    }

    /// Replaces the top route in place (e.g. post-login redirect).
    public func replaceTop(with route: Route) {
        if storage.isEmpty {
            storage.append(route)
        } else {
            storage[storage.count - 1] = route
        }
        notify()
    }

    private func notify() {
        #if canImport(Combine)
        objectWillChange.send()
        #endif
        onChange?()
    }
}

#if canImport(Combine)
// On Apple platforms the router participates in SwiftUI observation directly;
// nothing else is required because `objectWillChange` is provided above.
extension Router: ObservableObject {}
#endif
