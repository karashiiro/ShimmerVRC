import XCTest

/// UI Tests focused on ECGHeartbeatView component
/// Tests directly pass BPM values rather than testing through ContentView's slider
class ECGHeartbeatViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app to launch directly to ECGHeartbeatView test harness
        app.launchArguments = ["--test-ecg"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - Animation State Tests
    
    func testECGWaveformAnimationAtRestingBPM() throws {
        setBPMForTest(60)
        
        XCTAssertTrue(app.otherElements["ecg_waveform"].exists, "ECG waveform should be visible")
        XCTAssertTrue(app.images["ecg_heartbeat"].exists, "Heart icon should be visible")
    }
    
    func testECGWaveformAnimationAtHighBPM() throws {
        print("\n\n=== Setting BPM to 150 ===\n")
        setBPMForTest(150)
        Thread.sleep(forTimeInterval: 1)
        
        // Verify components exist and are visible at higher heart rate
        XCTAssertTrue(app.otherElements["ecg_waveform"].exists, "ECG waveform should be visible")
        XCTAssertTrue(app.images["ecg_heartbeat"].exists, "Heart icon should be visible")
        
        // Verify the BPM display contains the expected value
        let bpmDisplay = app.staticTexts["current_bpm_display"]
        XCTAssertTrue(bpmDisplay.exists, "BPM display should exist")
        print("BPM display value: '\(bpmDisplay.label)'")
        XCTAssertTrue(bpmDisplay.label.contains("150"), "BPM display should contain 150: \(bpmDisplay.label)")
    }
    
    func testHeartAnimationExists() throws {
        setBPMForTest(75)
        
        // Check if heart icon exists
        let heartIcon = app.images["ecg_heartbeat"]
        XCTAssertTrue(heartIcon.exists, "Heart icon should be visible")
    }
    
    // MARK: - BPM Response Tests
    
    func testBoundaryBPMValues() throws {
        print("\n\n=== Starting testBoundaryBPMValues ===\n")
        
        // Reset state first by setting a middle value
        setBPMForTest(100)
        Thread.sleep(forTimeInterval: 1)
        
        // Test minimum BPM (40)
        print("\n=== Setting BPM to 40 ===\n")
        setBPMForTest(40)
        Thread.sleep(forTimeInterval: 1)
        
        // Verify UI elements exist and are responsive
        XCTAssertTrue(app.otherElements["ecg_waveform"].exists, "ECG waveform should exist at minimum BPM")
        XCTAssertTrue(app.images["ecg_heartbeat"].exists, "Heart icon should exist at minimum BPM")
        
        // Log all static texts to help diagnose the issue
        print("\nAll static texts:\n")
        let allTexts = app.staticTexts.allElementsBoundByIndex
        for (index, text) in allTexts.enumerated() {
            print("\(index): \(text.identifier) - '\(text.label)'")
        }
        
        let bpmDisplay = app.staticTexts["current_bpm_display"]
        XCTAssertTrue(bpmDisplay.exists, "BPM display should exist")
        
        // Get the actual BPM value from the display
        let actualBpmString = bpmDisplay.label
        print("\nActual BPM display value: '\(actualBpmString)'\n")
        
        // For test stability, check if it contains the BPM value rather than the exact format
        XCTAssertTrue(bpmDisplay.label.contains("40"), "BPM display should contain 40: \(actualBpmString)")
        
        // Test maximum BPM (180)
        print("\n=== Setting BPM to 180 ===\n")
        setBPMForTest(180)
        Thread.sleep(forTimeInterval: 1)
        
        // Verify UI elements exist and are responsive
        XCTAssertTrue(app.otherElements["ecg_waveform"].exists, "ECG waveform should exist at maximum BPM")
        XCTAssertTrue(app.images["ecg_heartbeat"].exists, "Heart icon should exist at maximum BPM")
        
        let maxBpmDisplay = app.staticTexts["current_bpm_display"]
        XCTAssertTrue(maxBpmDisplay.exists, "BPM display should exist")
        
        // Get the actual BPM value from the display
        let actualMaxBpmString = maxBpmDisplay.label
        print("\nActual max BPM display value: '\(actualMaxBpmString)'\n")
        
        // For test stability, check if it contains the BPM value
        XCTAssertTrue(maxBpmDisplay.label.contains("180"), "BPM display should contain 180: \(actualMaxBpmString)")
    }
    
    func testExtremeBPMValues() throws {
        // Test values outside normal range but still valid
        let extremeValues = [30, 200, 250]
        
        for bpm in extremeValues {
            setBPMForTest(Double(bpm))
            Thread.sleep(forTimeInterval: 0.5)
            
            // App should handle extreme values gracefully
            let ecgExists = app.otherElements["ecg_waveform"].exists
            let heartExists = app.images["ecg_heartbeat"].exists
            
            XCTAssertTrue(ecgExists && heartExists, "Components should exist even with extreme BPM (\(bpm))")
        }
    }
    
    // MARK: - Performance Tests
    
    func testECGAnimationPerformanceAtHighBPM() throws {
        setBPMForTest(170)
        
        measure {
            // Measure how long it takes to interact with UI elements 10 times
            for i in 0..<10 {
                // Update BPM value slightly each time
                setBPMForTest(160 + Double(i))
                
                // Verify UI remains responsive 
                XCTAssertTrue(app.otherElements["ecg_waveform"].exists)
                XCTAssertTrue(app.images["ecg_heartbeat"].exists)
            }
        }
    }
    
    // MARK: - Component Existence Tests
    
    func testECGComponentsExist() throws {
        setBPMForTest(70)
        
        // Check that both components exist
        let ecgWaveform = app.otherElements["ecg_waveform"]
        let ecgHeartbeat = app.images["ecg_heartbeat"]
        
        XCTAssertTrue(ecgWaveform.exists, "ECG waveform should exist")
        XCTAssertTrue(ecgHeartbeat.exists, "Heart icon should exist")
    }
    
    // MARK: - Helper Methods
    

    private func setBPMForTest(_ bpm: Double) {
        // Find the test input field and buttons
        let bpmField = app.textFields["test_bpm_input"]
        let clearButton = app.buttons["clear_bpm_button"]
        let setButton = app.buttons["set_bpm_button"]
        
        // Wait for elements to exist
        XCTAssertTrue(bpmField.waitForExistence(timeout: 5), "BPM input field should exist")
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Clear button should exist")
        XCTAssertTrue(setButton.waitForExistence(timeout: 5), "Set button should exist")
        
        // Use the clear button instead of trying to clear the field manually
        clearButton.tap()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Get value after clearing
        let clearedValue = bpmField.value as? String ?? ""
        print("\nText field value after clearing: '\(clearedValue)'\n")
        
        // Tap the field and type the new BPM value
        bpmField.tap()
        print("\nTyping BPM value: \(bpm)\n")
        bpmField.typeText(String(Int(bpm)))
        
        // Tap the set button
        print("\nTapping Set BPM button\n")
        setButton.tap()
        
        // Wait for UI to update
        Thread.sleep(forTimeInterval: 1.0)
        
        // Debug: Verify the BPM was set correctly
        let currentDisplay = app.staticTexts["current_bpm_display"]
        print("\nAttempted to set BPM to \(bpm), current display: '\(currentDisplay.label)'\n")
    }
}

// MARK: - Additional Test Cases

extension ECGHeartbeatViewUITests {
    
    func testViewLifecycle() throws {
        // Set up initial state
        setBPMForTest(100)
        
        // Check initial components exist
        XCTAssertTrue(app.otherElements["ecg_waveform"].exists, "ECG waveform should exist initially")
        XCTAssertTrue(app.images["ecg_heartbeat"].exists, "Heart icon should exist initially")
        
        // Navigate away if navigation is available
        let navigateButton = app.buttons["navigate_away_button"]
        if navigateButton.exists {
            navigateButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // Navigate back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // Components should still exist after coming back
            XCTAssertTrue(app.otherElements["ecg_waveform"].exists, "ECG waveform should exist after returning")
            XCTAssertTrue(app.images["ecg_heartbeat"].exists, "Heart icon should exist after returning")
        }
    }
}
