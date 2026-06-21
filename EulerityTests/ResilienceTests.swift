//
//  ResilienceTests.swift
//  EulerityTests
//
//  M7 — a deliberately hostile payload pushed end-to-end (parse → factory → view
//  model). Proves the engine drops/degrades bad fields, keeps the good ones, resolves
//  a partially-bad theme, and still Saves — without ever crashing.
//

import XCTest
@testable import Eulerity

@MainActor
final class ResilienceTests: XCTestCase {

    /// Mirrors the bundled `form_edgecases.json` used by the in-app demo switch.
    private let hostile = """
    {
      "theme": {
        "background_color": "#FFF7ED",
        "text_color": "#7C2D12",
        "border_color": "#FDBA74",
        "error_color": "#GGGGGG"
      },
      "form_title": "Edge Cases (Hostile Payload)",
      "fields": [
        { "id": "name", "order": 1, "type": "TEXT", "subtype": "PLAIN", "label": "Campaign Name",
          "max_length": 20, "required": true, "error_message": "Name is required." },
        "this element is not an object",
        { "id": "future", "order": 2, "type": "DATE_PICKER", "label": "Launch Date" },
        { "order": 3, "type": "TEXT", "label": "Field with no id" },
        { "id": "name", "order": 4, "type": "TOGGLE", "label": "Duplicate id" },
        { "id": "empty_dd", "order": 5, "type": "DROPDOWN", "label": "No options" },
        { "id": "networks", "order": 6, "type": "DROPDOWN", "allow_multiple": true,
          "default_values": ["ghost", "net_meta"],
          "options": [ { "id": "net_google", "label": "Google" }, { "label": "no id" }, { "id": "net_meta", "label": "Meta" } ] },
        { "id": "budget", "order": "not-a-number", "type": "TEXT", "subtype": "NUMBER", "label": "Budget", "required": true },
        { "id": "weird", "order": 7, "type": "TEXT", "subtype": "HOLOGRAM", "label": "Unknown subtype", "max_length": 0 },
        { "id": "legal", "order": 8, "type": "CHECKBOX", "label": "Accept terms", "required": true,
          "clickable_text_color": "#GG00FF" },
        { "id": "notify", "order": 9, "type": "TOGGLE", "label": "Email me" }
      ]
    }
    """

    private func hostileVM() throws -> FormViewModel {
        let schema = try FormParser.parse(Data(hostile.utf8)).get()
        let vm = FormViewModel()
        vm.apply(schema)
        return vm
    }

    func testSurvivorsAndOrder() throws {
        let vm = try hostileVM()
        // Dropped: non-object, DATE_PICKER, no-id, duplicate "name", empty dropdown.
        // Kept and sorted by (order ?? .max, sourceIndex) — budget's bad order sinks last.
        XCTAssertEqual(vm.fields.map(\.id), ["name", "networks", "weird", "legal", "notify", "budget"])
        XCTAssertFalse(vm.diagnostics.isEmpty)
    }

    func testPartiallyBadThemeResolves() throws {
        let vm = try hostileVM()
        XCTAssertNil(vm.theme.error, "invalid #GGGGGG → nil channel (UI uses adaptive fallback)")
        XCTAssertNotNil(vm.theme.background, "valid channels still parse")
    }

    func testDropdownCleanedUp() throws {
        let vm = try hostileVM()
        guard case .dropdown(let dd)? = vm.fields.first(where: { $0.id == "networks" })?.kind else {
            return XCTFail("networks dropdown missing")
        }
        XCTAssertEqual(dd.options.map(\.id), ["net_google", "net_meta"], "option with no id dropped")
        XCTAssertEqual(dd.defaultSelection, ["net_meta"], "unknown default 'ghost' filtered")
    }

    func testDegradedTextField() throws {
        let vm = try hostileVM()
        guard case .text(let model)? = vm.fields.first(where: { $0.id == "weird" })?.kind else {
            return XCTFail("weird field missing")
        }
        XCTAssertEqual(model.subtype, .plain, "unknown subtype degraded")
        XCTAssertNil(model.maxLength, "max_length 0 ignored")
    }

    func testSaveBlocksThenSucceeds() throws {
        let vm = try hostileVM()
        guard case .invalid(let errors) = vm.save() else { return XCTFail("expected invalid") }
        XCTAssertNotNil(errors["name"])
        XCTAssertNotNil(errors["budget"])
        XCTAssertNotNil(errors["legal"])

        vm.setText("Promo", for: "name")
        vm.setText("50.00", for: "budget")  // decimal accepted (D15/D20)
        vm.setBool(true, for: "legal")
        guard case .valid(let pairs) = vm.save() else { return XCTFail("expected valid") }
        XCTAssertEqual(pairs.count, vm.fields.count)
    }

    /// Also proves `form_edgecases.json` is actually bundled (loaded from `.main` in the
    /// hosted test process).
    func testBundledEdgeCasesPayloadLoads() throws {
        let data = try BundleFormProvider(resourceName: "form_edgecases").loadForm()
        let schema = try FormParser.parse(data).get()
        let vm = FormViewModel()
        vm.apply(schema)
        XCTAssertEqual(vm.fields.count, 6)
        XCTAssertFalse(vm.diagnostics.isEmpty)
    }
}
