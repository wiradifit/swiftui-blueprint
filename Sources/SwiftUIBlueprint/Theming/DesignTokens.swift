import Foundation

/// A color pair (light/dark) expressed as framework-free hex values.
///
/// Tokens keep your palette declarative and diffable. Rendering happens in the
/// SwiftUI layer (`Color(token:)`); here they are pure values, safe to unit
/// test, serialize, and share with designers.
public struct ColorToken: Hashable, Sendable {
    /// Hex value used in light appearance, e.g. `0x1C1C1E`.
    public let lightHex: UInt32
    /// Hex value used in dark appearance; falls back to `lightHex`.
    public let darkHex: UInt32?

    public init(light: UInt32, dark: UInt32? = nil) {
        precondition(light <= 0xFFFFFF, "hex must be RGB (0…0xFFFFFF)")
        if let dark = dark { precondition(dark <= 0xFFFFFF, "hex must be RGB (0…0xFFFFFF)") }
        self.lightHex = light
        self.darkHex = dark
    }

    /// Parses `"#RRGGBB"` / `"RRGGBB"`. Returns `nil` on malformed input
    /// instead of crashing — bad design data should never take an app down.
    public init?(hexString: String, darkHexString: String? = nil) {
        guard let light = Self.parse(hexString) else { return nil }
        let dark = darkHexString.flatMap(Self.parse)
        self.init(light: light, dark: dark)
    }

    public static func rgb(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> ColorToken {
        ColorToken(light: (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue))
    }

    static func parse(_ string: String) -> UInt32? {
        var body = string
        if body.hasPrefix("#") { body.removeFirst() }
        guard body.count == 6, let value = UInt32(body, radix: 16) else { return nil }
        return value
    }

    /// Red channel (0–255) of the light variant.
    public var red: UInt8 { UInt8((lightHex >> 16) & 0xFF) }
    /// Green channel (0–255) of the light variant.
    public var green: UInt8 { UInt8((lightHex >> 8) & 0xFF) }
    /// Blue channel (0–255) of the light variant.
    public var blue: UInt8 { UInt8(lightHex & 0xFF) }
}

/// Semantic color roles every app screen needs.
public struct Palette: Sendable {
    public var accent: ColorToken
    public var background: ColorToken
    public var surface: ColorToken
    public var textPrimary: ColorToken
    public var textSecondary: ColorToken
    public var separator: ColorToken
    public var danger: ColorToken
    public var success: ColorToken

    public init(
        accent: ColorToken,
        background: ColorToken,
        surface: ColorToken,
        textPrimary: ColorToken,
        textSecondary: ColorToken,
        separator: ColorToken,
        danger: ColorToken,
        success: ColorToken
    ) {
        self.accent = accent
        self.background = background
        self.surface = surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.separator = separator
        self.danger = danger
        self.success = success
    }

    /// Neutral, accessible defaults (system-like greys + blue accent).
    public static let `default` = Palette(
        accent: ColorToken(light: 0x0066CC, dark: 0x409CFF),
        background: ColorToken(light: 0xF2F2F7, dark: 0x000000),
        surface: ColorToken(light: 0xFFFFFF, dark: 0x1C1C1E),
        textPrimary: ColorToken(light: 0x000000, dark: 0xFFFFFF),
        textSecondary: ColorToken(light: 0x3C3C43, dark: 0xEBEBF5),
        separator: ColorToken(light: 0xC6C6C8, dark: 0x38383A),
        danger: ColorToken(light: 0xD70015, dark: 0xFF453A),
        success: ColorToken(light: 0x248A3D, dark: 0x30D158)
    )
}

/// Spacing scale in points — use these instead of magic numbers.
public struct SpacingScale: Hashable, Sendable {
    public let xs: CGFloat, sm: CGFloat, md: CGFloat, lg: CGFloat, xl: CGFloat

    public init(xs: CGFloat, sm: CGFloat, md: CGFloat, lg: CGFloat, xl: CGFloat) {
        self.xs = xs; self.sm = sm; self.md = md; self.lg = lg; self.xl = xl
    }

    /// 4 / 8 / 12 / 20 / 32 pt ladder.
    public static let `default` = SpacingScale(xs: 4, sm: 8, md: 12, lg: 20, xl: 32)
}

/// Corner-radius scale in points.
public struct RadiusScale: Hashable, Sendable {
    public let small: CGFloat, medium: CGFloat, large: CGFloat

    public init(small: CGFloat, medium: CGFloat, large: CGFloat) {
        self.small = small; self.medium = medium; self.large = large
    }

    /// 6 / 12 / 20 pt ladder.
    public static let `default` = RadiusScale(small: 6, medium: 12, large: 20)
}

/// Text style roles mapped to SwiftUI font styles in the UI layer.
public enum FontRole: String, CaseIterable, Sendable {
    case largeTitle, title, headline, body, callout, caption
}

/// The complete design-token bundle applied app-wide.
public struct Theme: Sendable {
    public var palette: Palette
    public var spacing: SpacingScale
    public var radius: RadiusScale

    public init(palette: Palette, spacing: SpacingScale, radius: RadiusScale) {
        self.palette = palette
        self.spacing = spacing
        self.radius = radius
    }

    /// Ships with neutral defaults — swap pieces, don't start from scratch:
    ///
    /// ```swift
    /// var theme = Theme.default
    /// theme.palette.accent = ColorToken(hexString: "#5E5CE6")!
    /// ```
    public static let `default` = Theme(
        palette: .default,
        spacing: .default,
        radius: .default
    )
}

#if canImport(CoreGraphics)
import CoreGraphics
#else
/// Minimal fallback so token scales compile on platforms without CoreGraphics.
public typealias CGFloat = Double
#endif
