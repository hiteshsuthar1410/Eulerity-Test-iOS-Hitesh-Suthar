//
//  FormFlowUITests.swift
//  EulerityUITests
//
//  M7 — drives the real interactive flow (Save → inline errors, valid Save → success
//  confirmation) that unit tests can't exercise on a device.
//

import XCTest

final class FormFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Empty required fields → tapping Save surfaces the field's error message inline.
    func testEmptySaveSurfacesRequiredError() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["save_button"].tap()
        XCTAssertTrue(app.staticTexts["Name is required."].waitForExistence(timeout: 3),
                      "Saving an empty required field should show its error message")
    }

    /// Filling the required fields and saving shows the "Submitted" confirmation alert.
    func testValidSaveShowsConfirmation() {
        let app = XCUIApplication()
        app.launch()

        let name = app.textFields["campaign_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Summer Sale")

        let budget = app.textFields["daily_budget"]
        budget.tap()
        budget.typeText("50")

        app.buttons["accept_legal_checkbox"].tap() // ad_networks already has its default

        app.buttons["save_button"].tap()

        XCTAssertTrue(app.alerts["Submitted"].waitForExistence(timeout: 3),
                      "A valid Save should present the Submitted confirmation")
    }
}
