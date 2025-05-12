//
//  ConnectivityManagerTests.swift
//  ShimmerVRCTests
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import Testing
import WatchConnectivity
@testable import ShimmerVRC

@Suite(.serialized) struct ConnectivityManagerTests {
    
    @Test func testConnectChangesStateToConnecting() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.connectionState = .disconnected
        
        // Act
        manager.connect(to: "test.local", port: 9000)
        
        // Assert
        #expect(manager.connectionState == .connecting)
    }
    
    @Test func testConnectValidatesEmptyHost() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.connectionState = .disconnected
        
        // Act
        manager.connect(to: "", port: 9000)
        
        // Assert
        #expect(manager.connectionState == .error)
        #expect(manager.lastError != nil)
        
        // Check error message
        if let error = manager.lastError {
            #expect(error.contains("Invalid host"))
        }
    }
    
    @Test func testConnectValidatesInvalidPort() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.connectionState = .disconnected
        
        // Act - Port 0 is invalid
        manager.connect(to: "test.local", port: 0)
        
        // Assert
        #expect(manager.connectionState == .error)
        #expect(manager.lastError != nil)
        
        // Create a new instance for the second test
        let manager2 = ConnectivityManager()
        manager2.connectionState = .disconnected
        
        // Act - Port > 65535 is invalid
        manager2.connect(to: "test.local", port: 70000)
        
        // Assert
        #expect(manager2.connectionState == .error)
        #expect(manager2.lastError != nil)
    }
    
    @Test func testDisconnectChangesState() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.connectionState = .connected
        manager.oscConnected = true
        
        // Act
        manager.disconnect()
        
        // Assert
        #expect(manager.connectionState == .disconnected)
        #expect(manager.oscConnected == false)
    }
    
    @Test func testSaveLoadConfiguration() {
        let testSuffix = Int.random(in: 10000...99999)
        let testHost = "test-host-\(testSuffix).local"
        let testPort = Int.random(in: 1000...9000)
        
        // Set values directly in UserDefaults
        UserDefaults.standard.set(testHost, forKey: "testSaveLoadHost")
        UserDefaults.standard.set(testPort, forKey: "testSaveLoadPort")
        
        // Immediately read them back
        let readHost = UserDefaults.standard.string(forKey: "testSaveLoadHost")
        let readPort = UserDefaults.standard.integer(forKey: "testSaveLoadPort")
        
        // Verify values match
        #expect(readHost == testHost)
        #expect(readPort == testPort)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "testSaveLoadHost")
        UserDefaults.standard.removeObject(forKey: "testSaveLoadPort")
    }
    
    @Test func testDefaultPortValue() {
        // Arrange - Clear any saved port
        UserDefaults.standard.removeObject(forKey: "lastPort")
        
        // Act - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.loadSavedConfiguration()
        
        // Assert - Should default to 9000
        #expect(manager.targetPort == 9000)
    }
    
    @Test func testSaveLoadDirect() {
        // Arrange - Create a new instance for this test
        // Using a unique identifier to avoid test interference
        let testId = Int.random(in: 10000...99999)
        let testHost = "direct-test-\(testId).local"
        let testPort = 8000 + (testId % 1000) // Generate a port between 8000-8999
        
        // Act - Set properties on manager and save directly
        let manager = ConnectivityManager()
        manager.targetHost = testHost
        manager.targetPort = testPort
        manager.saveConfiguration()
        
        // Read the values directly from UserDefaults to verify they were saved
        let savedHost = UserDefaults.standard.string(forKey: "lastHost")
        let savedPort = UserDefaults.standard.integer(forKey: "lastPort")
        
        // Assert the values were saved correctly
        #expect(savedHost == testHost)
        #expect(savedPort == testPort)
    }
    
    @Test func testPublishPropertiesInitialState() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        
        // Assert initial state
        #expect(manager.connectionState == .disconnected)
        #expect(manager.watchConnected == false)
        #expect(manager.oscConnected == false)
        #expect(manager.bpm == 60.0)
        #expect(manager.messageCount == 0)
        #expect(manager.lastMessageTime == nil)
        #expect(manager.lastError == nil)
    }
    
    @Test func testSimulatedConnectionSuccess() async {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.connectionState = .disconnected
        
        // Set simulation parameters for deterministic testing
        manager.simulationDelay = 0.5 // Shorter delay for testing
        manager.simulationSuccessRate = 1.0 // 100% success rate
        
        // Act - Start connection
        manager.connect(to: "test-simulation.local", port: 9000)
        
        // Assert initial state
        #expect(manager.connectionState == .connecting)
        
        // Wait for simulated connection to complete
        try! await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Assert final state - should be connected
        #expect(manager.connectionState == .connected)
        #expect(manager.oscConnected == true)
        
        // Cleanup
        manager.disconnect()
        #expect(manager.connectionState == .disconnected)
    }
    
    @Test func testSimulatedConnectionFailure() async {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.connectionState = .disconnected
        
        // Set simulation parameters for deterministic testing
        manager.simulationDelay = 0.5 // Shorter delay for testing
        manager.simulationSuccessRate = 0.0 // 0% success rate (always fail)
        
        // Act - Start connection
        manager.connect(to: "test-simulation.local", port: 9000)
        
        // Assert initial state
        #expect(manager.connectionState == .connecting)
        
        // Wait for simulated connection to complete
        try! await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Assert final state - should be error
        #expect(manager.connectionState == .error)
        #expect(manager.lastError != nil)
        
        // Cleanup
        manager.disconnect()
        #expect(manager.connectionState == .disconnected)
    }
    
    @Test func testWatchMessageProcessing() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        
        // Initial state
        #expect(manager.bpm == 60.0) // Default value
        #expect(manager.messageCount == 0)
        #expect(manager.lastMessageTime == nil)
        
        // Create mock message
        let mockHeartRateMessage = ["heartRate": 85.5]
        
        // Act - Use the processWatchMessage method directly instead of the session method
        manager.processWatchMessage(mockHeartRateMessage)
        
        // Assert - Data should be processed
        #expect(manager.bpm == 85.5)
        #expect(manager.messageCount == 1)
        #expect(manager.lastMessageTime != nil)
        
        // Test with a second message
        let secondMockMessage = ["heartRate": 90.0]
        manager.processWatchMessage(secondMockMessage)
        
        #expect(manager.bpm == 90.0)
        #expect(manager.messageCount == 2)
    }
    
    @Test func testIgnoresNonHeartRateMessages() {
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        manager.bpm = 70.0 // Set initial value
        manager.messageCount = 0
        
        // Create mock message with incorrect format
        let invalidMessage = ["someOtherData": "not heart rate"]
        
        // Act - Use the processWatchMessage method directly
        manager.processWatchMessage(invalidMessage)
        
        // Assert - Data should not be processed
        #expect(manager.bpm == 70.0) // Should remain unchanged
        #expect(manager.messageCount == 0) // No message counted
        #expect(manager.lastMessageTime == nil) // Time not updated
    }
}
