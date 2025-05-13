//
//  ConnectionRecoveryUITests.swift
//  ShimmerVRCUITests
//
//  Created by karashiiro on 5/12/25.
//

import XCTest

class ConnectionRecoveryUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Enable UI testing mode
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }
    
    func testErrorMessageDisplayed() throws {
        // Tap connect button to show connection sheet
        app.buttons["connect_button"].tap()
        
        // Enter invalid host (just a space)
        let hostField = app.textFields["host_field"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 2))
        hostField.tap()
        hostField.typeText(" ")
        
        // Try to connect
        app.buttons["connect_button_sheet"].tap()
        
        // Verify error message is displayed
        let errorText = app.staticTexts.matching(identifier: "error_message").firstMatch
        XCTAssertTrue(errorText.waitForExistence(timeout: 2))
        XCTAssertTrue(errorText.label.contains("Cannot reach host"))
    }
    
    func testReconnectionIndicatorShown() throws {
        // Need to use a specialized debug mode for this test
        // Would be better to use mock injection but that's not easily available in UI tests
        
        // Tap connect button to show connection sheet
        app.buttons["connect_button"].tap()
        
        // Enter test reconnection mode host
        let hostField = app.textFields["host_field"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 2))
        hostField.tap()
        hostField.typeText("test-reconnect.local")
        
        // Try to connect
        app.buttons["connect_button_sheet"].tap()
        
        // Verify reconnection indicator is shown
        let reconnectIndicator = app.staticTexts.matching(identifier: "reconnect_indicator").firstMatch
        XCTAssertTrue(reconnectIndicator.waitForExistence(timeout: 5))
        
        // Should show attempts
        XCTAssertTrue(reconnectIndicator.label.contains("/"))
    }
}
