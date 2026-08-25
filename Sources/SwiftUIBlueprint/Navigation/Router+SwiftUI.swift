import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Turns any ``Router`` into a full `NavigationStack` screen.
///
/// ```swift
/// RouterView(router) {
///     HomeScreen()                      // root content
/// } destination: { route in
///     switch route {
///     case .profile(let id): ProfileScreen(id: id)
///     case .settings: SettingsScreen()
///     }
/// }
/// ```
///
/// Pushing from anywhere is `router.push(.profile(id: 7))` — pass the router
/// into child screens directly (environmentObject-style helpers are left to
/// your app architecture on purpose, keeping this kit dependency-light).
public struct RouterView<Route: Hashable & Sendable, Content: View, Destination: View>: View {
    @StateObject private var router: Router<Route>
    private let content: () -> Content
    private let destination: (Route) -> Destination

    public init(
        _ router: @autoclosure @escaping () -> Router<Route>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) {
        _router = StateObject(wrappedValue: router())
        self.content = content
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(
            path: Binding(
                get: { router.currentPath },
                set: { router.setPath($0) }
            )
        ) {
            content()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
    }
}
#endif
