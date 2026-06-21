//
//  RichTextLabelTests.swift
//  EulerityTests
//
//  M6 — the pure rich-text builder: link ranges, colors, https-only filtering, and the
//  longest-first / overlap-skip guard (D22).
//

import XCTest
import SwiftUI
@testable import Eulerity

final class RichTextLabelTests: XCTestCase {

    private typealias Link = RenderableField.Checkbox.MetadataLink

    private func make(_ label: String,
                      _ links: [Link],
                      linkColor: Color = .blue,
                      textColor: Color = .black,
                      required: Bool = false) -> AttributedString {
        RichText.make(label: label, links: links, linkColor: linkColor,
                      textColor: textColor, required: required, requiredColor: .red)
    }

    func testLinkRangeCarriesURLAndColor() {
        let attr = make("I agree to the Terms of Service.",
                        [Link(text: "Terms of Service", urlString: "https://example.com/terms")])
        let range = try! XCTUnwrap(attr.range(of: "Terms of Service"))
        XCTAssertEqual(attr[range].link, URL(string: "https://example.com/terms"))
        XCTAssertEqual(attr[range].foregroundColor, .blue)
    }

    func testPlainTextKeepsTextColorAndNoLink() {
        let attr = make("I agree to the Terms of Service.",
                        [Link(text: "Terms of Service", urlString: "https://example.com/terms")])
        let range = try! XCTUnwrap(attr.range(of: "I agree"))
        XCTAssertNil(attr[range].link)
        XCTAssertEqual(attr[range].foregroundColor, .black)
    }

    func testRequiredMarkerAppended() {
        let attr = make("Accept", [], required: true)
        XCTAssertTrue(String(attr.characters).hasSuffix(" *"))
    }

    // MARK: - URL safety (https-only)

    func testNonHttpSchemeIsNotLinked() {
        let attr = make("Tap run code now",
                        [Link(text: "run code", urlString: "javascript:alert(1)")])
        let range = try! XCTUnwrap(attr.range(of: "run code"))
        XCTAssertNil(attr[range].link, "javascript: must never become a link")
        XCTAssertEqual(attr[range].foregroundColor, .black, "and stays plain text")
    }

    func testMalformedURLIsNotLinked() {
        let attr = make("See here",
                        [Link(text: "here", urlString: "not a url")])
        let range = try! XCTUnwrap(attr.range(of: "here"))
        XCTAssertNil(attr[range].link)
    }

    func testMissingSubstringIsSkippedWithoutCrash() {
        let attr = make("No link here",
                        [Link(text: "Absent Key", urlString: "https://example.com")])
        XCTAssertEqual(String(attr.characters), "No link here")
    }

    // MARK: - Overlap guard (D22): longest-first, skip overlapping

    func testShortKeyCannotCorruptLongerLink() {
        // "Terms" (first occurrence) falls inside "Terms of Service"; longest-first
        // links the long key, and the short key's overlapping range is skipped — so
        // the whole phrase resolves to the LONG url, not the short one.
        let attr = make("Terms of Service",
                        [Link(text: "Terms", urlString: "https://short.example"),
                         Link(text: "Terms of Service", urlString: "https://long.example")])
        let whole = try! XCTUnwrap(attr.range(of: "Terms of Service"))
        XCTAssertEqual(attr[whole].link, URL(string: "https://long.example"))

        // The "Terms" sub-range is covered by the long link, not the short one.
        let shortRange = try! XCTUnwrap(attr.range(of: "Terms"))
        XCTAssertEqual(attr[shortRange].link, URL(string: "https://long.example"))
    }

    func testNonOverlappingStandaloneKeyStillLinks() {
        // Here "Terms" first appears standalone (non-overlapping) → it links normally.
        let attr = make("Terms here, and Service there",
                        [Link(text: "Terms", urlString: "https://short.example"),
                         Link(text: "Service", urlString: "https://svc.example")])
        let termsRange = try! XCTUnwrap(attr.range(of: "Terms"))
        XCTAssertEqual(attr[termsRange].link, URL(string: "https://short.example"))
        let serviceRange = try! XCTUnwrap(attr.range(of: "Service"))
        XCTAssertEqual(attr[serviceRange].link, URL(string: "https://svc.example"))
    }
}
