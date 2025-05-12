//
//  UITestHelpers.swift
//  ShimmerVRCUITests
//
//  Created by karashiiro on 5/11/25.
//

import XCTest

// Utility extensions for UI testing
extension XCUIElement {
    
    /// More reliable way to wait for element visibility
    func waitForVisibilityWithTimeout(_ timeout: TimeInterval) -> Bool {
        let startTime = Date()
        while !isHittable {
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return true
    }
    
    /// Safer way to tap that handles elements that might not be easily accessible
    func safeTap() {
        if isHittable {
            tap()
        } else {
            // Try scrolling to make the element visible
            XCUIApplication().swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            
            if isHittable {
                tap()
            } else {
                // Last resort - use coordinates
                coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
    }
    
    /// Check if the element label contains the given text
    func labelContains(_ text: String) -> Bool {
        return (label.range(of: text, options: .caseInsensitive) != nil)
    }
}

extension XCUIApplication {
    
    /// Find a button that contains text in its label 
    func findButtonContaining(_ text: String) -> XCUIElement? {
        let buttons = buttons.allElementsBoundByIndex
        for button in buttons {
            if button.labelContains(text) {
                return button
            }
        }
        return nil
    }
    
    /// Find any element that contains the text
    func findElementWithText(_ text: String) -> XCUIElement? {
        // Check static texts
        let staticTexts = self.staticTexts.allElementsBoundByIndex
        for staticText in staticTexts {
            if staticText.labelContains(text) {
                return staticText
            }
        }
        
        // Check buttons
        let buttons = self.buttons.allElementsBoundByIndex
        for button in buttons {
            if button.labelContains(text) {
                return button
            }
        }
        
        // Check other elements
        let others = self.otherElements.allElementsBoundByIndex
        for other in others {
            if other.labelContains(text) {
                return other
            }
        }
        
        return nil
    }
    
    /// Print a summary of all UI elements for debugging
    func printUIHierarchy() {
        print("=== UI HIERARCHY ===")
        let allElements = descendants(matching: .any).allElementsBoundByIndex
        for (index, element) in allElements.enumerated() {
            print("\(index): \(element.debugDescription)")
        }
        print("=== END HIERARCHY ===")
    }
}

// Test helper extension for XCTestCase
extension XCTestCase {
    
    /// Skip test with a message
    func skipTest(message: String) throws {
        throw XCTSkip(message)
    }
    
    /// Helper to tap a button by text, with better error handling
    func tapButton(app: XCUIApplication, withText text: String) -> Bool {
        if let button = app.findButtonContaining(text) {
            button.safeTap()
            return true
        }
        
        // Debug output in case we can't find the button
        print("Could not find button with text: \(text)")
        app.printUIHierarchy()
        return false
    }
    
    /// Helper to enter text in a text field, with better error handling
    func enterText(app: XCUIApplication, inField identifier: String, text: String) -> Bool {
        let textField = app.textFields[identifier]
        if textField.waitForExistence(timeout: 2) {
            textField.tap()
            textField.typeText(text)
            
            // Dismiss keyboard if visible
            if app.keyboards.count > 0 {
                app.keyboards.buttons["Return"].tap()
            }
            return true
        }
        
        // Try by placeholder text
        for field in app.textFields.allElementsBoundByIndex {
            if field.placeholderValue == identifier {
                field.tap()
                field.typeText(text)
                
                // Dismiss keyboard if visible
                if app.keyboards.count > 0 {
                    app.keyboards.buttons["Return"].tap()
                }
                return true
            }
        }
        
        // Debug output
        print("Could not find text field: \(identifier)")
        app.printUIHierarchy()
        return false
    }
}

extension XCUIElement {
    /// Attempt to clear the text in a text field
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        // Tap to position cursor at the end
        self.tap()
        
        // Delete characters
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
