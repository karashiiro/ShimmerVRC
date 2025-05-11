//
//  ConnectivityManagerTests.swift
//  ShimmerVRCTests
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import Testing
@testable import ShimmerVRC

struct ConnectivityManagerTests {
    
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
        // Arrange - Create a new instance for this test
        let manager = ConnectivityManager()
        let testHost = "test-host-\(Int.random(in: 1000...9999)).local"
        let testPort = Int.random(in: 1000...9000)
        
        // Act - Save configuration
        manager.targetHost = testHost
        manager.targetPort = testPort
        manager.saveConfiguration()
        
        // Create a new instance to test loading
        let newManager = ConnectivityManager()
        newManager.loadSavedConfiguration()
        
        // Assert
        #expect(newManager.targetHost == testHost)
        #expect(newManager.targetPort == testPort)
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
}
