//
//  FormViewModelTests.swift
//  EulerityTests
//
//  M3 — state seeding, max_length truncation, error lifecycle, and the Save payload
//  shape (D15: scalars for single values, arrays for multi-select). The test class is
//  @MainActor simply because `FormViewModel` is @MainActor, so its methods are called
//  directly (no `await` needed — the loader is synchronous, D5).
//

import XCTest
@testable import Eulerity

@MainActor
final class FormViewModelTests: XCTestCase {

    private func makeVM(_ json: String) throws -> FormViewModel {
        let schema = try FormParser.parse(Data(json.utf8)).get()
        let vm = FormViewModel()
        vm.apply(schema)
        return vm
    }

    private func fullyValidSampleVM() throws -> FormViewModel {
        let vm = try makeVM(Fixtures.fullSample)
        vm.setText("Summer Sale", for: "campaign_name")
        vm.setText("50", for: "daily_budget")
        vm.setBool(true, for: "accept_legal")
        // ad_networks already seeded with default ["net_meta"]
        return vm
    }

    // MARK: - Seeding

    func testSeedsDefaults() throws {
        let vm = try makeVM(Fixtures.fullSample)
        XCTAssertEqual(vm.values["campaign_name"], .text(""))
        XCTAssertEqual(vm.values["ad_networks"], .selection(["net_meta"]))
        XCTAssertEqual(vm.values["accept_legal"], .bool(false))
        XCTAssertEqual(vm.title, "Campaign Setup")
        XCTAssertEqual(vm.fields.count, 4)
    }

    // MARK: - max_length

    func testSetTextTruncatesAtMaxLength() throws {
        let vm = try makeVM(Fixtures.fullSample) // campaign_name max_length = 30
        vm.setText(String(repeating: "x", count: 40), for: "campaign_name")
        XCTAssertEqual(vm.values["campaign_name"], .text(String(repeating: "x", count: 30)))
    }

    // MARK: - Error lifecycle

    func testSaveInvalidPopulatesErrorsForRequiredFields() throws {
        let vm = try makeVM(Fixtures.fullSample)
        let result = vm.save()

        guard case .invalid(let errors) = result else { return XCTFail("expected invalid") }
        XCTAssertEqual(errors["campaign_name"], "Name is required.") // custom message
        XCTAssertNotNil(errors["daily_budget"]) // required, empty
        XCTAssertNil(errors["ad_networks"], "seeded with default [net_meta] → already valid")
    }

    func testErrorClearsOnEdit() throws {
        let vm = try makeVM(Fixtures.fullSample)
        _ = vm.save()
        XCTAssertNotNil(vm.errors["campaign_name"])

        vm.setText("Anything", for: "campaign_name")
        XCTAssertNil(vm.errors["campaign_name"], "Editing a field clears its error")
    }

    func testRequiredCheckboxBlocksSaveUntilChecked() throws {
        let vm = try fullyValidSampleVM()
        vm.setBool(false, for: "accept_legal")
        guard case .invalid(let errors) = vm.save() else { return XCTFail("expected invalid") }
        XCTAssertNotNil(errors["accept_legal"])

        vm.setBool(true, for: "accept_legal")
        guard case .valid = vm.save() else { return XCTFail("expected valid after checking") }
    }

    // MARK: - Numeric (D15)

    func testNumberFieldRejectsPastedJunkOnSave() throws {
        let vm = try fullyValidSampleVM()
        vm.setText("50abc", for: "daily_budget")
        guard case .invalid(let errors) = vm.save() else { return XCTFail("expected invalid") }
        XCTAssertNotNil(errors["daily_budget"])
    }

    // MARK: - Save payload shape (D15)

    func testValidSaveEmitsSpecExactShape() throws {
        let vm = try fullyValidSampleVM()
        guard case .valid(let pairs) = vm.save() else { return XCTFail("expected valid") }

        // Render order preserved.
        XCTAssertEqual(pairs.map(\.id),
                       ["campaign_name", "ad_networks", "daily_budget", "accept_legal"])

        let byID = Dictionary(uniqueKeysWithValues: pairs.map { ($0.id, $0.value) })
        XCTAssertEqual(byID["campaign_name"], .string("Summer Sale")) // scalar string
        XCTAssertEqual(byID["ad_networks"], .array(["net_meta"]))      // multi → array
        XCTAssertEqual(byID["daily_budget"], .string("50"))           // NUMBER → raw string, not 50
        XCTAssertEqual(byID["accept_legal"], .bool(true))             // scalar bool
    }

    func testSingleSelectDropdownEmitsScalarNotArray() throws {
        let vm = try makeVM("""
        { "fields": [ { "id": "net", "type": "DROPDOWN", "allow_multiple": false,
            "options": [ { "id": "g", "label": "Google" }, { "id": "m", "label": "Meta" } ] } ] }
        """)
        vm.setSingleSelection("g", for: "net")
        guard case .valid(let pairs) = vm.save() else { return XCTFail("expected valid") }
        XCTAssertEqual(pairs.first?.value, .string("g"), "single-select is a scalar id, not [\"g\"]")
    }

    func testMultiSelectArrayPreservesOptionOrder() throws {
        let vm = try makeVM("""
        { "fields": [ { "id": "net", "type": "DROPDOWN", "allow_multiple": true,
            "options": [ { "id": "g", "label": "Google" }, { "id": "m", "label": "Meta" }, { "id": "t", "label": "TikTok" } ] } ] }
        """)
        // Select in reverse order; output must follow option declaration order.
        vm.toggleSelection("t", for: "net")
        vm.toggleSelection("g", for: "net")
        guard case .valid(let pairs) = vm.save() else { return XCTFail("expected valid") }
        XCTAssertEqual(pairs.first?.value, .array(["g", "t"]))
    }
}
