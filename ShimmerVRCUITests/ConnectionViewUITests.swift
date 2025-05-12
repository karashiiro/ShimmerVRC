//
//  ConnectionViewUITests.swift
//  ShimmerVRCUITests
//
//  Created by karashiiro on 5/11/25.
//

import XCTest

class ConnectionViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Launch with special flags for UI testing
        app.launchArguments = ["--ui-testing"]
        app.launch()
        
        // Give UI time to fully load
        Thread.sleep(forTimeInterval: 1)
        
        // Print UI hierarchy for debugging
        print("Initial UI Hierarchy:")
        app.printUIHierarchy()
        
        // Navigate to ConnectionView using our helper
        XCTAssertTrue(tapButton(app: app, withText: "Connect"), "Should find and tap Connect button")
        
        // Wait for navigation
        Thread.sleep(forTimeInterval: 1)
        
        // Print UI hierarchy after navigation
        print("UI Hierarchy after navigation:")
        app.printUIHierarchy()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - Basic UI Tests
    
    func testBasicUIPresence() throws {
        // This is a simple test to verify the app doesn't crash and basic UI is present
        XCTAssertTrue(app.navigationBars.count > 0, "Should have a navigation bar")
        XCTAssertTrue(app.textFields.count > 0, "Should have text fields")
        XCTAssertTrue(app.buttons.count > 0, "Should have buttons")
    }
}
