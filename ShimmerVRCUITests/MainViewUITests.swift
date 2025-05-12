//
//  MainViewUITests.swift
//  ShimmerVRCUITests
//
//  Created by karashiiro on 5/11/25.
//

import XCTest

class MainViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app to launch directly to MainView (default)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testSettingsNavigation() throws {
        // Tap settings button
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).element
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2), "Settings button should exist")
        settingsButton.tap()
        
        // Verify settings view appears
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 2), "Settings navigation bar should appear")
        
        // Verify settings sections exist
        let generalSection = app.staticTexts["General"]
        let advancedSection = app.staticTexts["Advanced"]
        XCTAssertTrue(generalSection.exists, "General settings section should exist")
        XCTAssertTrue(advancedSection.exists, "Advanced settings section should exist")
        
        // Dismiss settings
        let doneButton = app.buttons["Done"]
        doneButton.tap()
        
        // Verify we're back to main view
        let heartRateTitle = app.navigationBars["Heart Rate"]
        XCTAssertTrue(heartRateTitle.waitForExistence(timeout: 2), "Should return to main view")
    }
    
    func testConnectionNavigation() throws {
        // Tap connect button
        let connectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Connect'")).element
        XCTAssertTrue(connectButton.waitForExistence(timeout: 2), "Connect button should exist")
        connectButton.tap()
        
        // Verify connection view appears
        let connectionNav = app.navigationBars["Connect to VRChat"]
        XCTAssertTrue(connectionNav.waitForExistence(timeout: 2), "Connection navigation bar should appear")
        
        // Check for host/port fields
        let hostField = app.textFields["Host"]
        let portField = app.textFields["Port"]
        XCTAssertTrue(hostField.exists, "Host field should exist")
        XCTAssertTrue(portField.exists, "Port field should exist")
    }
    
    // MARK: - UI Element Tests
    
    func testUIElementsExist() throws {
        // Check for main UI elements
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'BPM'")).element.exists,
                     "BPM display should exist")
        
        // Check status bar elements
        XCTAssertTrue(app.staticTexts["Watch"].exists, "Watch status should exist")
        XCTAssertTrue(app.staticTexts["VRChat"].exists, "VRChat status should exist")
        
        // Check bottom action buttons
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Connect'")).element.exists,
                     "Connect button should exist")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start' OR label CONTAINS 'Stop'")).element.exists,
                     "Start/Stop button should exist")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).element.exists,
                     "Settings button should exist")
    }
}
