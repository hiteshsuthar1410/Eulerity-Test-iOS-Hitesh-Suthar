//
//  FieldFactoryTests.swift
//  EulerityTests
//
//  M2 — semantic mapping: DTO -> RenderableField with drop/degrade rules (D6, D9,
//  D10) and the D4 total-order sort. Inputs go through the real parser so these are
//  end-to-end from JSON.
//

import XCTest
@testable import Eulerity

final class FieldFactoryTests: XCTestCase {

    private func make(_ json: String) throws -> FieldFactory.Output {
        let schema = try FormParser.parse(Data(json.utf8)).get()
        return FieldFactory.make(from: schema.fields)
    }

    // MARK: - Happy path

    func testFullSampleMapsToFourOrderedFields() throws {
        let output = try make(Fixtures.fullSample)

        XCTAssertTrue(output.diagnostics.isEmpty, "Clean payload produces no diagnostics")
        XCTAssertEqual(output.fields.map(\.id),
                       ["campaign_name", "ad_networks", "daily_budget", "accept_legal"])

        guard case .text(let text) = output.fields[0].kind else { return XCTFail("expected text") }
        XCTAssertEqual(text.subtype, .plain)
        XCTAssertEqual(text.maxLength, 30)

        guard case .dropdown(let dd) = output.fields[1].kind else { return XCTFail("expected dropdown") }
        XCTAssertTrue(dd.allowMultiple)
        XCTAssertEqual(dd.options.map(\.id), ["net_google", "net_meta"])
        XCTAssertEqual(dd.defaultSelection, ["net_meta"])

        guard case .checkbox(let cb) = output.fields[3].kind else { return XCTFail("expected checkbox") }
        XCTAssertEqual(cb.metadata, [.init(text: "Terms of Service", urlString: "https://example.com/terms")])
        XCTAssertEqual(cb.clickableColor, RGBAColor(hex: "#2563EB"))
    }

    // MARK: - Drop rules (D6 / D10)

    func testUnknownTypeIsDropped() throws {
        let output = try make("""
        { "fields": [
            { "id": "ok", "type": "TEXT" },
            { "id": "future", "type": "DATE_PICKER" }
        ] }
        """)
        XCTAssertEqual(output.fields.map(\.id), ["ok"])
        XCTAssertEqual(output.diagnostics, [
            .init(sourceIndex: 1, fieldID: "future", wasDropped: true, reason: .unknownType(raw: "DATE_PICKER"))
        ])
    }

    func testMissingTypeIsDropped() throws {
        let output = try make(#"{ "fields": [ { "id": "x", "label": "no type" } ] }"#)
        XCTAssertTrue(output.fields.isEmpty)
        XCTAssertEqual(output.diagnostics.first?.reason, .unknownType(raw: nil))
    }

    func testMissingOrEmptyIDIsDropped() throws {
        let output = try make("""
        { "fields": [
            { "type": "TEXT", "label": "no id" },
            { "id": "   ", "type": "TEXT", "label": "blank id" },
            { "id": "kept", "type": "TEXT" }
        ] }
        """)
        XCTAssertEqual(output.fields.map(\.id), ["kept"])
        XCTAssertEqual(output.diagnostics.filter { $0.reason == .missingID }.count, 2)
    }

    func testDuplicateIDFirstWins() throws {
        let output = try make("""
        { "fields": [
            { "id": "dup", "type": "TEXT", "label": "First" },
            { "id": "dup", "type": "TOGGLE", "label": "Second" }
        ] }
        """)
        XCTAssertEqual(output.fields.count, 1)
        XCTAssertEqual(output.fields[0].label, "First")
        if case .text = output.fields[0].kind {} else { XCTFail("first occurrence (text) should win") }
        XCTAssertEqual(output.diagnostics, [
            .init(sourceIndex: 1, fieldID: "dup", wasDropped: true, reason: .duplicateID("dup"))
        ])
    }

    func testDuplicateIDNotReservedWhenFirstIsDropped() throws {
        // The first "x" is a dropdown with no options (dropped), so "x" is NOT reserved
        // and the later valid text field with id "x" survives.
        let output = try make("""
        { "fields": [
            { "id": "x", "type": "DROPDOWN" },
            { "id": "x", "type": "TEXT", "label": "kept" }
        ] }
        """)
        XCTAssertEqual(output.fields.map(\.id), ["x"])
        XCTAssertEqual(output.fields[0].label, "kept")
    }

    func testDropdownWithNoValidOptionsIsDropped() throws {
        let output = try make(#"{ "fields": [ { "id": "dd", "type": "DROPDOWN", "options": [] } ] }"#)
        XCTAssertTrue(output.fields.isEmpty)
        XCTAssertEqual(output.diagnostics.first?.reason, .dropdownHasNoValidOptions)
    }

    // MARK: - Degrade rules (D10)

    func testDropdownDropsBadOptionsKeepsGood() throws {
        let output = try make("""
        { "fields": [ { "id": "dd", "type": "DROPDOWN", "options": [
            { "id": "a", "label": "Apple" },
            { "label": "no id" },
            { "id": "a", "label": "dup id" },
            { "id": "b" }
        ] } ] }
        """)
        guard case .dropdown(let dd) = output.fields[0].kind else { return XCTFail() }
        XCTAssertEqual(dd.options.map(\.id), ["a", "b"])
        XCTAssertEqual(dd.options[1].label, "b", "Missing label degrades to the option id")
        XCTAssertEqual(output.diagnostics, [
            .init(sourceIndex: 0, fieldID: "dd", wasDropped: false, reason: .droppedInvalidOptions(count: 2))
        ])
    }

    func testUnknownDefaultValuesAreFiltered() throws {
        let output = try make("""
        { "fields": [ { "id": "dd", "type": "DROPDOWN", "allow_multiple": true,
            "default_values": ["a", "ghost"],
            "options": [ { "id": "a", "label": "A" } ] } ] }
        """)
        guard case .dropdown(let dd) = output.fields[0].kind else { return XCTFail() }
        XCTAssertEqual(dd.defaultSelection, ["a"])
        XCTAssertEqual(output.diagnostics.first?.reason, .filteredUnknownDefaultValues(["ghost"]))
    }

    func testSingleSelectReducesMultipleDefaults() throws {
        let output = try make("""
        { "fields": [ { "id": "dd", "type": "DROPDOWN", "allow_multiple": false,
            "default_values": ["b", "a"],
            "options": [ { "id": "a", "label": "A" }, { "id": "b", "label": "B" } ] } ] }
        """)
        guard case .dropdown(let dd) = output.fields[0].kind else { return XCTFail() }
        XCTAssertEqual(dd.defaultSelection, ["a"], "Keeps the first by option order")
        XCTAssertTrue(output.diagnostics.contains { $0.reason == .reducedMultipleDefaultsForSingleSelect })
    }

    func testNonPositiveMaxLengthIsIgnored() throws {
        let output = try make(#"{ "fields": [ { "id": "t", "type": "TEXT", "max_length": 0 } ] }"#)
        guard case .text(let text) = output.fields[0].kind else { return XCTFail() }
        XCTAssertNil(text.maxLength)
        XCTAssertEqual(output.diagnostics.first?.reason, .ignoredNonPositiveMaxLength(0))
    }

    func testUnknownSubtypeDegradesToPlain() throws {
        let output = try make(#"{ "fields": [ { "id": "t", "type": "TEXT", "subtype": "RICHTEXT" } ] }"#)
        guard case .text(let text) = output.fields[0].kind else { return XCTFail() }
        XCTAssertEqual(text.subtype, .plain)
        XCTAssertEqual(output.diagnostics.first?.reason, .unknownSubtypeDegradedToPlain(raw: "RICHTEXT"))
    }

    // MARK: - D4 ordering

    func testFieldsSortByOrderWithStableTieBreak() throws {
        // order: A=2, B=nil, C=2, D=1  (source indices 0..3)
        // expected (order ?? max, sourceIndex): D(1,3), A(2,0), C(2,2), B(max,1)
        let output = try make("""
        { "fields": [
            { "id": "A", "type": "TEXT", "order": 2 },
            { "id": "B", "type": "TEXT" },
            { "id": "C", "type": "TEXT", "order": 2 },
            { "id": "D", "type": "TEXT", "order": 1 }
        ] }
        """)
        XCTAssertEqual(output.fields.map(\.id), ["D", "A", "C", "B"])
    }

    // MARK: - Diagnostics shape

    func testDiagnosticDescriptionIsHumanReadable() {
        let d = FieldDiagnostic(sourceIndex: 3, fieldID: "x", wasDropped: true, reason: .missingID)
        XCTAssertTrue(d.description.contains("DROPPED"))
        XCTAssertTrue(d.description.contains("field[3]"))
    }
}
