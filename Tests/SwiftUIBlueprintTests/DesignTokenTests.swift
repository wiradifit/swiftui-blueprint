import Testing
import Foundation
@testable import SwiftUIBlueprint

@Suite("Design tokens")
struct DesignTokenTests {
    @Test("Hex strings parse case-insensitively with optional # prefix")
    func hexParsing() {
        let token = ColorToken(hexString: "#FFAA00", darkHexString: "2c2c2e")
        #expect(token != nil)
        #expect(token?.lightHex == 0xFFAA00)
        #expect(token?.darkHex == 0x2C2C2E)
        #expect(token?.red == 255)
        #expect(token?.green == 170)
        #expect(token?.blue == 0)
    }

    @Test("Malformed hex yields nil instead of crashing")
    func malformedHex() {
        #expect(ColorToken(hexString: "") == nil)
        #expect(ColorToken(hexString: "#FFF") == nil)          // shorthand unsupported
        #expect(ColorToken(hexString: "GGHHII") == nil)
        #expect(ColorToken(hexString: "#1234567") == nil)
        #expect(ColorToken(hexString: "12345", darkHexString: "ABCDEF") == nil)
    }

    @Test("Dark variant falls back to light when omitted")
    func darkFallback() {
        let token = ColorToken(hexString: "#112233")!
        #expect(token.darkHex == nil)
    }

    @Test("Default scales carry documented values")
    func scaleDefaults() {
        #expect(SpacingScale.default.xs == 4)
        #expect(SpacingScale.default.sm == 8)
        #expect(SpacingScale.default.md == 12)
        #expect(SpacingScale.default.lg == 20)
        #expect(SpacingScale.default.xl == 32)

        #expect(RadiusScale.default.small == 6)
        #expect(RadiusScale.default.medium == 12)
        #expect(RadiusScale.default.large == 20)
    }

    @Test("Theme customization mutates only what you touch")
    func themeCustomization() {
        var theme = Theme.default
        theme.palette.accent = ColorToken(hexString: "#5E5CE6")!
        #expect(theme.palette.accent.lightHex == 0x5E5CE6)
        #expect(theme.spacing == .default)
        #expect(theme.palette.background.lightHex == Palette.default.background.lightHex)
    }

    @Test("rgb constructor packs channels correctly")
    func rgbConstructor() {
        let token = ColorToken.rgb(16, 32, 64)
        #expect(token.lightHex == 0x102040)
    }
}
