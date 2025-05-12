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
        
        // Capture two screenshots with delay to verify animation
        let screenshot1 = captureApp()
        Thread.sleep(forTimeInterval: 0.5)
        let screenshot2 = captureApp()
        
        // Verify waveform is animating
        XCTAssertNotEqual(screenshot1.pngRepresentation, 
                         screenshot2.pngRepresentation, 
                         "ECG waveform should be animating at resting BPM")
    }
    
    func testECGWaveformAnimationAtHighBPM() throws {
        setBPMForTest(150)
        
        // Verify faster animation at higher BPM
        let screenshot1 = captureApp()
        Thread.sleep(forTimeInterval: 0.2) // Shorter delay due to faster animation
        let screenshot2 = captureApp()
        
        XCTAssertNotEqual(screenshot1.pngRepresentation, 
                         screenshot2.pngRepresentation, 
                         "ECG waveform should animate faster at high BPM")
    }
    
    func testHeartAnimationExists() throws {
        setBPMForTest(75)
        
        // Check if heart icon exists
        let heartIcon = app.images["ecg_heartbeat"]
        XCTAssertTrue(heartIcon.exists, "Heart icon should be visible")
    }
    
    // MARK: - BPM Response Tests
    
    func testBoundaryBPMValues() throws {
        // Test minimum BPM (40)
        setBPMForTest(40)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(validateECGIsAnimating(), "ECG should animate properly at minimum BPM")
        
        // Test maximum BPM (180)
        setBPMForTest(180)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(validateECGIsAnimating(), "ECG should animate properly at maximum BPM")
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
            // Measure how long it takes to update ECG 10 times
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 0.1)
                _ = captureApp()
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
        // Find the test input field directly
        let bpmField = app.textFields["test_bpm_input"]
        let setButton = app.buttons["set_bpm_button"]
        
        // Wait for elements to exist
        XCTAssertTrue(bpmField.waitForExistence(timeout: 5), "BPM input field should exist")
        XCTAssertTrue(setButton.waitForExistence(timeout: 5), "Set button should exist")
        
        // Tap the field and clear existing text
        bpmField.tap()
        bpmField.tap() // Tap twice to select all
        
        // Type the new BPM value
        bpmField.typeText(String(Int(bpm)))
        
        // Tap the set button
        setButton.tap()
        
        // Wait for UI to update
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    private func captureApp() -> XCUIScreenshot {
        return app.screenshot()
    }
    
    private func validateECGIsAnimating() -> Bool {
        let screenshot1 = captureApp()
        Thread.sleep(forTimeInterval: 0.3)
        let screenshot2 = captureApp()
        
        return screenshot1.pngRepresentation != screenshot2.pngRepresentation
    }
}

// MARK: - Additional Test Cases

extension ECGHeartbeatViewUITests {
    
    func testViewLifecycle() throws {
        // Set up initial state
        setBPMForTest(100)
        
        // Check initial animation
        XCTAssertTrue(validateECGIsAnimating(), "ECG should be animating initially")
        
        // Navigate away if navigation is available
        let navigateButton = app.buttons["navigate_away_button"]
        if navigateButton.exists {
            navigateButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // Navigate back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // ECG should restart animation after view reappears
            XCTAssertTrue(validateECGIsAnimating(), "ECG should restart animation after view reappears")
        }
    }
}
