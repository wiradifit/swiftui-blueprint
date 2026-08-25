import Foundation

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Token rendering (Apple platforms)

#if os(macOS)
import AppKit

public extension Color {
    /// Renders a ``ColorToken``, switching automatically between its light and
    /// dark variants via NSAppearance.
    init(token: ColorToken) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? (token.darkHex ?? token.lightHex) : token.lightHex
            return NSColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1
            )
        })
    }
}

#else
import UIKit

public extension Color {
    /// Renders a ``ColorToken``, switching automatically between its light and
    /// dark variants via UITraitCollection.
    init(token: ColorToken) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark
                ? (token.darkHex ?? token.lightHex)
                : token.lightHex
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1
            )
        })
    }
}
#endif

// MARK: - Environment

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = Theme.default
}

public extension EnvironmentValues {
    /// Active ``Theme``; defaults to `Theme.default` when none installed.
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Installs `theme` for this view subtree.
    ///
    /// ```swift
    /// WindowGroup { RootScreen() }.theme(.brand)
    /// ```
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }

    /// Convenience padding using the active ``SpacingScale``.
    ///
    /// ```swift
    /// Text("Hi").padding(.all, \.md)
    /// ```
    func padding(_ edge: Edge.Set, _ step: KeyPath<SpacingScale, CGFloat>) -> some View {
        modifier(SpacedPadding(edge: edge, step: step))
    }
}

private struct SpacedPadding: ViewModifier {
    let edge: Edge.Set
    let step: KeyPath<SpacingScale, CGFloat>
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.padding(edge, theme.spacing[keyPath: step])
    }
}
#endif
