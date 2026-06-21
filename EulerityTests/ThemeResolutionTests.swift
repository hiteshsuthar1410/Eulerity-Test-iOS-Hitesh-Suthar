//
//  ThemeResolutionTests.swift
//  EulerityTests
//
//  M2 — hex parsing + per-channel theme fallback (headless, no UI host).
//

import XCTest
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

    // MARK: - ResolvedTheme

    func testNilDTOResolvesToDefault() {
        XCTAssertEqual(ResolvedTheme.resolve(nil), .default)
    }

    func testValidDTOResolvesAllChannels() throws {
        let schema = try FormParser.parse(Data(Fixtures.fullSample.utf8)).get()
        let theme = ResolvedTheme.resolve(schema.theme)
        XCTAssertEqual(theme.background, RGBAColor(hex: "#FFFFFF"))
        XCTAssertEqual(theme.text, RGBAColor(hex: "#111827"))
        XCTAssertEqual(theme.border, RGBAColor(hex: "#D1D5DB"))
        XCTAssertEqual(theme.error, RGBAColor(hex: "#B91C1C"))
    }

    func testBadHexFallsBackPerChannelOnly() throws {
        // Only `text_color` is malformed — the other channels must still parse.
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

        XCTAssertEqual(theme.text, ResolvedTheme.default.text, "Bad channel falls back")
        XCTAssertEqual(theme.background, RGBAColor(hex: "#000000"), "Good channels unaffected")
        XCTAssertEqual(theme.border, RGBAColor(hex: "#D1D5DB"))
    }
}
