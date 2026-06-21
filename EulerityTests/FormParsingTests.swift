//
//  FormParsingTests.swift
//  EulerityTests
//
//  M1 — the resilient decoding boundary. These tests prove the parsing layer
//  preserves good data and degrades gracefully on the kinds of malformed/ahead-of-
//  client payloads a server can send, without ever throwing past the boundary.
//
//  Note on scope: decode is *mechanical and per-element* — it never enforces
//  semantic rules (required id, unknown-type drop, duplicate-id de-dup, empty
//  options). Those are FieldFactory's job (M2). So tests here assert that decode
//  *preserves* such cases for the factory to handle, not that they are dropped.
//

import XCTest
@testable import Eulerity

final class FormParsingTests: XCTestCase {

    // MARK: - Helpers

    /// Parses a JSON string and returns the schema, failing the test on `.failure`.
    private func parse(_ json: String,
                       file: StaticString = #filePath,
                       line: UInt = #line) throws -> FormSchemaDTO {
        let data = Data(json.utf8)
        switch FormParser.parse(data) {
        case .success(let schema):
            return schema
        case .failure(let error):
            XCTFail("Expected success, got \(error)", file: file, line: line)
            throw error
        }
    }

    // MARK: - Happy path

    func testFullSamplePayloadDecodes() throws {
        let schema = try parse(Fixtures.fullSample)

        XCTAssertEqual(schema.formTitle, "Campaign Setup")
        XCTAssertEqual(schema.theme?.backgroundColor, "#FFFFFF")
        XCTAssertEqual(schema.theme?.errorColor, "#B91C1C")
        XCTAssertEqual(schema.fields.count, 4)

        // Source order is preserved exactly (M2 will sort by `order`).
        XCTAssertEqual(schema.fields.map(\.id),
                       ["campaign_name", "ad_networks", "daily_budget", "accept_legal"])

        // A representative field decodes all its properties.
        let name = schema.fields[0]
        XCTAssertEqual(name.type, .text)
        XCTAssertEqual(name.subtype, .plain)
        XCTAssertEqual(name.maxLength, 30)
        XCTAssertEqual(name.required, true)
        XCTAssertEqual(name.placeholder, "e.g., Summer Sale")

        // Dropdown options decode with id + label intact.
        let dropdown = schema.fields[1]
        XCTAssertEqual(dropdown.allowMultiple, true)
        XCTAssertEqual(dropdown.defaultValues, ["net_meta"])
        XCTAssertEqual(dropdown.options?.count, 2)
        XCTAssertEqual(dropdown.options?.map(\.id), ["net_google", "net_meta"])

        // Checkbox rich-text metadata + clickable color decode.
        let checkbox = schema.fields[3]
        XCTAssertEqual(checkbox.type, .checkbox)
        XCTAssertEqual(checkbox.metadata?["Terms of Service"], "https://example.com/terms")
        XCTAssertEqual(checkbox.clickableTextColor, "#2563EB")
    }

    // MARK: - Net 2: unknown type tolerance

    func testUnknownTypeDecodesAsUnknownAndSurvives() throws {
        let json = """
        { "fields": [
            { "id": "future", "type": "DATE_PICKER", "label": "Pick a date" }
        ] }
        """
        let schema = try parse(json)

        XCTAssertEqual(schema.fields.count, 1, "Unknown type must NOT drop at decode")
        XCTAssertEqual(schema.fields[0].type, .unknown("DATE_PICKER"))
    }

    func testTypeMatchingIsCaseInsensitive() throws {
        let json = """
        { "fields": [ { "id": "a", "type": "text", "subtype": "Secure" } ] }
        """
        let schema = try parse(json)
        XCTAssertEqual(schema.fields[0].type, .text)
        XCTAssertEqual(schema.fields[0].subtype, .secure)
    }

    // MARK: - Net 1: per-element failable decode

    func testNonObjectFieldElementsAreDroppedSiblingsSurvive() throws {
        let json = """
        { "fields": [
            { "id": "a", "type": "TEXT" },
            "junk",
            42,
            null,
            { "id": "b", "type": "TOGGLE" }
        ] }
        """
        let schema = try parse(json)

        XCTAssertEqual(schema.fields.count, 2, "Only the two object elements survive")
        XCTAssertEqual(schema.fields.map(\.id), ["a", "b"])
    }

    func testMalformedOptionIsDroppedOthersSurvive() throws {
        let json = """
        { "fields": [
            { "id": "dd", "type": "DROPDOWN", "options": [
                { "id": "ok", "label": "Fine" },
                "not-an-object",
                { "id": "ok2", "label": "Also fine" }
            ] }
        ] }
        """
        let schema = try parse(json)
        XCTAssertEqual(schema.fields[0].options?.count, 2)
        XCTAssertEqual(schema.fields[0].options?.map(\.id), ["ok", "ok2"])
    }

    // MARK: - D1: per-property leniency

    func testWrongTypedPropertyDegradesButFieldSurvives() throws {
        // `order` and `max_length` are sent as strings; the field must survive with
        // those properties nil rather than being dropped wholesale.
        let json = """
        { "fields": [
            { "id": "a", "type": "TEXT", "order": "first", "max_length": "lots", "required": true }
        ] }
        """
        let schema = try parse(json)

        XCTAssertEqual(schema.fields.count, 1)
        XCTAssertNil(schema.fields[0].order)
        XCTAssertNil(schema.fields[0].maxLength)
        XCTAssertEqual(schema.fields[0].required, true, "Well-typed siblings are unaffected")
    }

    // MARK: - Missing keys

    func testMissingFieldsKeyYieldsEmptyArray() throws {
        let schema = try parse("{ \"form_title\": \"Empty\" }")
        XCTAssertEqual(schema.formTitle, "Empty")
        XCTAssertTrue(schema.fields.isEmpty)
    }

    func testMissingThemeIsNil() throws {
        let schema = try parse("{ \"fields\": [] }")
        XCTAssertNil(schema.theme)
    }

    func testThemePresentButNotAnObjectFallsBackToNil() throws {
        let schema = try parse("{ \"theme\": \"blue\", \"fields\": [] }")
        XCTAssertNil(schema.theme, "A non-object theme degrades to nil, not a crash")
    }

    // MARK: - Garbage input

    func testNonJSONInputFailsCleanly() {
        switch FormParser.parse(Data("this is not json".utf8)) {
        case .success:
            XCTFail("Expected failure for non-JSON input")
        case .failure(let error):
            guard case .notDecodable = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testRootNotAnObjectFailsCleanly() {
        switch FormParser.parse(Data("[1, 2, 3]".utf8)) {
        case .success:
            XCTFail("Expected failure for array root")
        case .failure:
            break
        }
    }

    // MARK: - D6 preconditions: nil & duplicate id (decode preserves; M2 enforces)

    func testMissingIdDecodesAsNilAndFieldSurvives() throws {
        // The factory (M2) will drop this; decode must preserve it so the factory
        // can see it and emit a diagnostic.
        let json = """
        { "fields": [ { "type": "TEXT", "label": "No id" } ] }
        """
        let schema = try parse(json)
        XCTAssertEqual(schema.fields.count, 1)
        XCTAssertNil(schema.fields[0].id)
    }

    func testDuplicateIdsBothPresentAtDecodeStage() throws {
        // Decode does NOT de-dupe — that is a collection-level rule owned by the
        // factory (D6). Both must be present here, in source order.
        let json = """
        { "fields": [
            { "id": "dup", "type": "TEXT", "label": "First" },
            { "id": "dup", "type": "TOGGLE", "label": "Second" }
        ] }
        """
        let schema = try parse(json)
        XCTAssertEqual(schema.fields.count, 2)
        XCTAssertEqual(schema.fields.map(\.id), ["dup", "dup"])
        XCTAssertEqual(schema.fields.map(\.label), ["First", "Second"])
    }

    // MARK: - Bundle provider integration

    func testBundleProviderLoadsAndParsesRealPayload() throws {
        // Hosted unit tests run inside the app process, so `.main` resolves to the
        // app bundle that ships form.json. This doubles as proof the resource is
        // actually bundled. (Previously XCTSkip'd for an async/isolation hang; the
        // loader is now synchronous, so this runs normally — see D5/D8.)
        let data = try BundleFormProvider().loadForm()
        let schema = try FormParser.parse(data).get()
        XCTAssertEqual(schema.fields.count, 4)
        XCTAssertEqual(schema.formTitle, "Campaign Setup")
    }

    func testBundleProviderThrowsWhenResourceMissing() throws {
        let provider = BundleFormProvider(resourceName: "does_not_exist",
                                          bundle: Bundle(for: Self.self))
        do {
            _ = try provider.loadForm()
            XCTFail("Expected resourceNotFound")
        } catch let error as BundleFormProvider.LoadError {
            XCTAssertEqual(error, .resourceNotFound(name: "does_not_exist"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
