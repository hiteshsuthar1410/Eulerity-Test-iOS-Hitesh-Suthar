//
//  ThemeResolutionTests.swift
//  EulerityTests
//
//  M2 — hex parsing + per-channel theme fallback (headless, no UI host).
//

import XCTest
import SwiftUI
@testable import Eulerity

final class ThemeResolutionTests: XCTestCase {

    // MARK: - RGBAColor hex parsing

    func testParsesSixDigitHex() throws {
        let color = try XCTUnwrap(RGBAColor(hex: "#FF8800"))
        XCTAssertEqual(color.red, 1, accuracy: 0.001)
        XCTAssertEqual(color.green, 136.0 / 255, accuracy: 0.001)
        XCTAssertEqual(color.blue, 0, accuracy: 0.001)
        XCTAssertEqual(color.alpha, 1, accuracy: 0.001)
    }

    func testParsesWithoutHashPrefix() throws {
        XCTAssertEqual(RGBAColor(hex: "FF8800"), RGBAColor(hex: "#FF8800"))
    }

    func testParsesShorthandRGB() throws {
        XCTAssertEqual(RGBAColor(hex: "#F80"), RGBAColor(hex: "#FF8800"))
    }

    func testParsesEightDigitHexWithAlpha() throws {
        let color = try XCTUnwrap(RGBAColor(hex: "#00000080"))
        XCTAssertEqual(color.alpha, 128.0 / 255, accuracy: 0.001)
        XCTAssertEqual(color.red, 0, accuracy: 0.001)
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(RGBAColor(hex: "#abcdef"), RGBAColor(hex: "#ABCDEF"))
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(RGBAColor(hex: ""))
        XCTAssertNil(RGBAColor(hex: "#"))
        XCTAssertNil(RGBAColor(hex: "#ZZZ"))
        XCTAssertNil(RGBAColor(hex: "#12345"))     // wrong length
        XCTAssertNil(RGBAColor(hex: "not a color"))
    }

    // MARK: - ResolvedTheme (optional channels)

    func testNilDTOResolvesToAllNilChannels() {
        XCTAssertEqual(ResolvedTheme.resolve(nil), ResolvedTheme())
    }

    func testValidDTOResolvesAllChannels() throws {
        let schema = try FormParser.parse(Data(Fixtures.fullSample.utf8)).get()
        let theme = ResolvedTheme.resolve(schema.theme)
        XCTAssertEqual(theme.background, RGBAColor(hex: "#FFFFFF"))
        XCTAssertEqual(theme.text, RGBAColor(hex: "#111827"))
        XCTAssertEqual(theme.border, RGBAColor(hex: "#D1D5DB"))
        XCTAssertEqual(theme.error, RGBAColor(hex: "#B91C1C"))
    }

    func testBadHexChannelBecomesNilOthersUnaffected() throws {
        // Only `text_color` is malformed — it resolves to nil; the rest still parse.
        let json = """
        { "theme": {
            "background_color": "#000000",
            "text_color": "#GARBAGE",
            "border_color": "#D1D5DB",
            "error_color": "#B91C1C"
        }, "fields": [] }
        """
        let schema = try FormParser.parse(Data(json.utf8)).get()
        let theme = ResolvedTheme.resolve(schema.theme)

        XCTAssertNil(theme.text, "Bad channel becomes nil (UI applies adaptive fallback)")
        XCTAssertEqual(theme.background, RGBAColor(hex: "#000000"), "Good channels unaffected")
        XCTAssertEqual(theme.border, RGBAColor(hex: "#D1D5DB"))
    }

    // MARK: - FormPalette (D17: verbatim server colors, adaptive fallback when absent)

    func testPaletteUsesServerColorsVerbatim() throws {
        let schema = try FormParser.parse(Data(Fixtures.fullSample.utf8)).get()
        let palette = FormPalette(ResolvedTheme.resolve(schema.theme))
        XCTAssertEqual(palette.background, Color(RGBAColor(hex: "#FFFFFF")!))
        XCTAssertEqual(palette.error, Color(RGBAColor(hex: "#B91C1C")!))
    }

    func testPaletteFallsBackToAdaptiveForMissingChannels() throws {
        let json = ##"{ "theme": { "background_color": "#000000" }, "fields": [] }"##
        let schema = try FormParser.parse(Data(json.utf8)).get()
        let palette = FormPalette(ResolvedTheme.resolve(schema.theme))
        XCTAssertEqual(palette.background, Color(RGBAColor(hex: "#000000")!), "present → verbatim")
        XCTAssertEqual(palette.text, FormPalette.adaptive.text, "absent → adaptive")
        XCTAssertEqual(palette.border, FormPalette.adaptive.border)
    }

    func testNilThemeIsFullyAdaptive() {
        let palette = FormPalette(ResolvedTheme())
        XCTAssertEqual(palette.background, FormPalette.adaptive.background)
        XCTAssertEqual(palette.text, FormPalette.adaptive.text)
        XCTAssertEqual(palette.error, FormPalette.adaptive.error)
    }
}
