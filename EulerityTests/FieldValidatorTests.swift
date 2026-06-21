//
//  FieldValidatorTests.swift
//  EulerityTests
//
//  M3 — required / numeric (D15) / regex rules and their precedence.
//

import XCTest
@testable import Eulerity

final class FieldValidatorTests: XCTestCase {

    // MARK: - Builders

    private func textField(required: Bool = false,
                           subtype: FieldSubtype = .plain,
                           regex: String? = nil,
                           message: String? = nil) -> RenderableField {
        RenderableField(id: "t", order: nil, sourceIndex: 0, label: nil,
                        isRequired: required, supportingText: nil, errorMessage: message,
                        kind: .text(.init(subtype: subtype, placeholder: nil, maxLength: nil, regex: regex)))
    }

    private func dropdownField(required: Bool) -> RenderableField {
        RenderableField(id: "d", order: nil, sourceIndex: 0, label: nil,
                        isRequired: required, supportingText: nil, errorMessage: nil,
                        kind: .dropdown(.init(options: [.init(id: "a", label: "A")],
                                              allowMultiple: true, defaultSelection: [])))
    }

    private func checkboxField(required: Bool) -> RenderableField {
        RenderableField(id: "c", order: nil, sourceIndex: 0, label: nil,
                        isRequired: required, supportingText: nil, errorMessage: nil,
                        kind: .checkbox(.init(defaultOn: false, metadata: [], clickableColor: nil)))
    }

    // MARK: - Required

    func testRequiredTextEmptyFails() {
        XCTAssertNotNil(FieldValidator.validate(textField(required: true), value: .text("   ")))
    }

    func testRequiredTextFilledPasses() {
        XCTAssertNil(FieldValidator.validate(textField(required: true), value: .text("hi")))
    }

    func testOptionalEmptyPasses() {
        XCTAssertNil(FieldValidator.validate(textField(required: false), value: .text("")))
    }

    func testRequiredDropdownEmptyFails() {
        XCTAssertNotNil(FieldValidator.validate(dropdownField(required: true), value: .selection([])))
    }

    func testRequiredCheckboxMustBeChecked() {
        XCTAssertNotNil(FieldValidator.validate(checkboxField(required: true), value: .bool(false)))
        XCTAssertNil(FieldValidator.validate(checkboxField(required: true), value: .bool(true)))
    }

    func testCustomErrorMessageUsed() {
        let field = textField(required: true, message: "Name is required.")
        XCTAssertEqual(FieldValidator.validate(field, value: .text("")), "Name is required.")
    }

    // MARK: - Numeric (D15)

    func testNumberAcceptsValidNumbers() {
        let field = textField(subtype: .number)
        XCTAssertNil(FieldValidator.validate(field, value: .text("50")))
        XCTAssertNil(FieldValidator.validate(field, value: .text("-3.5")))
    }

    func testNumberRejectsJunk() {
        let field = textField(subtype: .number)
        XCTAssertNotNil(FieldValidator.validate(field, value: .text("50abc")))
        XCTAssertNotNil(FieldValidator.validate(field, value: .text("inf")))
        XCTAssertNotNil(FieldValidator.validate(field, value: .text("nan")))
    }

    func testEmptyNumberSkippedWhenOptional() {
        XCTAssertNil(FieldValidator.validate(textField(subtype: .number), value: .text("")))
    }

    func testRequiredBeatsNumeric() {
        // Empty required NUMBER → the *required* message, not the numeric one.
        let field = textField(required: true, subtype: .number, message: "Required!")
        XCTAssertEqual(FieldValidator.validate(field, value: .text("")), "Required!")
    }

    // MARK: - Regex

    func testRegexMatchPasses() {
        let field = textField(regex: "^[A-Z]{3}$")
        XCTAssertNil(FieldValidator.validate(field, value: .text("ABC")))
    }

    func testRegexMismatchFails() {
        let field = textField(regex: "^[A-Z]{3}$")
        XCTAssertNotNil(FieldValidator.validate(field, value: .text("ABCD")))
        XCTAssertNotNil(FieldValidator.validate(field, value: .text("ab")))
    }

    func testEmptyValueSkipsRegexWhenOptional() {
        XCTAssertNil(FieldValidator.validate(textField(regex: "^[A-Z]{3}$"), value: .text("")))
    }

    func testUncompilableRegexIsSkipped() {
        // A broken server pattern must not lock the user out.
        let field = textField(regex: "([")
        XCTAssertNil(FieldValidator.validate(field, value: .text("anything")))
    }
}
