# SwiftUIBlueprint

[![CI](https://github.com/wiradifit/swiftui-blueprint/actions/workflows/ci.yml/badge.svg)](https://github.com/wiradifit/swiftui-blueprint/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2016%20·%20macOS%2013%20·%20tvOS%2016%20·%20watchOS%209-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**A production-grade SwiftUI app foundation kit.** Type-safe navigation,
declarative design tokens, a retry-aware async networking client, and a tiny
key–value persistence abstraction — pure Swift, **zero third-party
dependencies**, and strict-concurrency clean under the Swift 6 language mode.

## Why

Every new app re-solves the same four problems: routing, theming, networking,
and lightweight persistence. SwiftUIBlueprint ships small, composable answers
with the boring parts done right — Sendable everywhere, error taxonomy that
distinguishes transport/status/decode failures, and a headless core you can
unit test on any platform Swift runs on.

## Contents

| Module | What you get |
|---|---|
| **Networking** | `Endpoint` (declarative request builder) · `HTTPClient` protocol · `URLSessionHTTPClient` (async/await over URLSession) · `RetryPolicy` (exponential backoff, injectable) · `APIError` with retryability classification |
| **Navigation** | `Router<Route>` — headless, type-safe navigation stack state machine · `RouterView` turns it into a `NavigationStack` |
| **Theming** | `ColorToken` (light/dark hex pairs) · `Palette`, `SpacingScale`, `RadiusScale`, `Theme` · `.theme(…)` environment modifier, `padding(_:_)` scale helper |
| **Persistence** | `KeyValueStore` protocol · `UserDefaultsStore` · thread-safe `InMemoryKeyValueStore` · Codable helpers |

## Requirements

- Swift **6.0+** toolchain (Xcode 16+ on Apple platforms)
- Deployment targets: **iOS 16.0**, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0
- Why iOS 16? Apple's App Store data (Feb 12 2026, developer site) shows iOS 26 at 66% and iOS 18 at 24% of all active devices — only ~10% remain older, nearly all of those on iOS 17+. Independent trackers (Apr 2026) put dropping *iOS 16 itself* at under 3% audience loss, so iOS ≥16 covers comfortably more than 95% of active devices.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/wiradifit/swiftui-blueprint", from: "1.0.0")
]
```

## Usage

### Networking with retries

```swift
import SwiftUIBlueprint

let client = URLSessionHTTPClient(
    retry: .exponential(base: .milliseconds(250), factor: 2, cap: .seconds(8), maxAttempts: 3)
)

struct Todo: Codable, Sendable { let id: Int; let title: String }

let endpoint = Endpoint(baseURL: URL(string: "https://jsonplaceholder.typicode.com")!)
    .path("todos").path("1")

let todo: Todo = try await client.fetch(endpoint)

do {
    _ = try await client.fetch(endpoint)
} catch let error as APIError {
    // error.isRetryable tells you whether another attempt is plausible;
    // .transport / .unacceptableStatus(code:response:body:) / .decoding are
    // distinct cases so UI can react precisely.
}
```

### Type-safe navigation

```swift
enum AppRoute: Hashable, Sendable {
    case profile(id: Int)
    case settings
}

struct RootScreen: View {
    var body: some View {
        RouterView(Router<AppRoute>()) {
            HomeScreen()
        } destination: { route in
            switch route {
            case .profile(let id): ProfileScreen(id: id)
            case .settings:        SettingsScreen()
            }
        }
    }
}

// From any child screen:
router.push(.profile(id: 7))
router.pop()
router.popToRoot()
router.replaceTop(with: .settings)   // e.g. post-login redirect
```

The router is `@MainActor`, observable through Combine on Apple platforms, and
fully unit-testable anywhere (`onChange` hook) — see `Tests/`.

### Design tokens

```swift
var theme = Theme.default
theme.palette.accent = ColorToken(hexString: "#5E5CE6", darkHexString: "#7D7AFF")!

WindowGroup { RootScreen() }
    .theme(theme)

Text("Hello").foregroundStyle(Color(token: theme.palette.accent))
Text("Padded").padding(.all, \.md)          // 12 pt from the spacing ladder
```

### Key–value persistence

```swift
let store = UserDefaultsStore(suiteName: "com.example.settings")
try store.setValue(Settings(notificationsEnabled: true, displayName: "Ada"), forKey: "settings")
let restored: Settings? = try store.value(Settings.self, forKey: "settings")
```

## Verification status (read before shipping)

This repository is developed primarily on a **Linux CI host**, where:

- ✅ `swift build` passes with zero warnings under Swift 6 language mode
  (strict concurrency is the default there — no data-race warnings).
- ✅ All **30 tests** in 6 suites pass (`swift test`, swift-testing), covering
  endpoint building, HTTP status/retry/decode paths via a mock `URLProtocol`,
  router semantics, token parsing, and store round-trips.
- ⚠️ The **SwiftUI surface layer** (`RouterView`, `Color(token:)`,
  `.theme(…)`) is guarded by `#if canImport(SwiftUI)` and therefore
  **compile-verified only** on Apple platforms — this host cannot run
  simulators or UIKit/AppKit. The GitHub Actions matrix builds the package
  for iOS Simulator on macOS to typecheck that layer on every push.
  No simulator runtime testing has been performed.

Run everything locally:

```bash
swift build
swift test
```

## Design notes

- **Headless core, thin shell.** Navigation state lives in `Router`
  (Foundation-only). The SwiftUI glue is additive and platform-guarded, which
  is what makes the logic testable off-Apple.
- **Swift 6 strict concurrency.** Every public type is `Sendable` or
  actor-isolated. The two `@unchecked Sendable`s (`URLSessionHTTPClient`,
  `UserDefaultsStore`) exist solely to bridge missing annotations in
  swift-corelibs-foundation; both underlying types are documented
  thread-safe.
- **Portable networking.** Requests go through the completion-based
  `URLSession.dataTask` wrapped in continuations, so the same code runs on
  Darwin and Linux (`FoundationNetworking`). In-flight cancellation is not
  wired to the socket; backoff sleeps are cancellable via task cancellation.

## License

MIT — see [LICENSE](LICENSE).
