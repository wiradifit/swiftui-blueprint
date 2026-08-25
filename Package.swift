// swift-tools-version:6.0
// SwiftUIBlueprint — production-grade SwiftUI app foundation kit.
// Pure Swift/SwiftUI. Zero third-party dependencies. Swift 6 strict concurrency clean.
import PackageDescription

let package = Package(
    name: "SwiftUIBlueprint",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftUIBlueprint",
            targets: ["SwiftUIBlueprint"]
        )
    ],
    targets: [
        .target(
            name: "SwiftUIBlueprint",
            path: "Sources/SwiftUIBlueprint"
        ),
        .testTarget(
            name: "SwiftUIBlueprintTests",
            dependencies: ["SwiftUIBlueprint"],
            path: "Tests/SwiftUIBlueprintTests"
        )
    ]
)
