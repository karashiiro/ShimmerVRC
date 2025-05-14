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
        let settingsButton = app.buttons["settings_button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2), "Settings button should exist")
        settingsButton.tap()
        
        // Verify settings view appears with a wait
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings navigation bar should appear")
        
        // Wait to ensure the view is fully loaded
        sleep(1)
        
        // DEBUG: Print the entire UI hierarchy to see what's available
        print("\n\n----------- UI HIERARCHY -----------")
        print(app.debugDescription)
        print("------------------------------------\n\n")
        
        let connectionSection = app.staticTexts["section_connection"]
        let watchSection = app.staticTexts["section_watch"]
        let appSection = app.staticTexts["section_app"]
        
        // Allow more time for sections to appear
        XCTAssertTrue(connectionSection.waitForExistence(timeout: 5), "Connection settings section should exist")
        XCTAssertTrue(watchSection.waitForExistence(timeout: 5), "Watch settings section should exist")
        XCTAssertTrue(appSection.waitForExistence(timeout: 5), "App settings section should exist")
        
        // As a fallback, check that the settings view has some expected content
        let hasNavigationLinks = app.buttons["VRChat Connection"].exists && 
                                app.buttons["Workout Settings"].exists && 
                                app.buttons["Display"].exists
        
        XCTAssertTrue(hasNavigationLinks, "Settings should have expected navigation links")
        
        // Dismiss settings
        let doneButton = app.buttons["Done"]
        doneButton.tap()
        
        // Verify we're back to main view
        let heartRateTitle = app.navigationBars["Heart Rate"]
        XCTAssertTrue(heartRateTitle.waitForExistence(timeout: 2), "Should return to main view")
    }
    
    func testConnectionNavigation() throws {
        // Tap connect button
        let connectButton = app.buttons["connect_button"]
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
        let bpmDisplay = app.staticTexts["bpm_display"]
        XCTAssertTrue(bpmDisplay.exists, "BPM display should exist")
        
        // Check status bar elements
        XCTAssertTrue(app.staticTexts["Watch"].exists, "Watch status should exist")
        XCTAssertTrue(app.staticTexts["VRChat"].exists, "VRChat status should exist")
        
        // Check bottom action buttons
        let connectButton = app.buttons["connect_button"]
        let startStopButton = app.buttons["start_stop_button"]
        let settingsButton = app.buttons["settings_button"]
        
        XCTAssertTrue(connectButton.exists, "Connect button should exist")
        XCTAssertTrue(startStopButton.exists, "Start/Stop button should exist") 
        XCTAssertTrue(settingsButton.exists, "Settings button should exist")
    }
}
