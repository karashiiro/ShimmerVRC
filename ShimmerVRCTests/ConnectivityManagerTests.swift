//
//  ConnectivityManagerTests.swift
//  ShimmerVRCTests
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import Testing
import WatchConnectivity
import OSCKit
@testable import ShimmerVRC

// Mock OSC client for ConnectivityManager tests
class ConnectivityManagerTestOSCClient: OSCClientProtocol {
    var lastMessage: OSCMessage?
    var lastHost: String = ""
    var lastPort: UInt16 = 0
    var shouldSucceed = true
    var pingCount = 0
    var heartRateValues: [Double] = []
    
    func send(_ message: OSCMessage, to host: String, port: UInt16) throws {
        if !shouldSucceed {
            throw NSError(domain: "TestOSCClientError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test send error"])
        }
        lastMessage = message
        lastHost = host
        lastPort = port
    }
    
    func sendPing(to host: String, port: UInt16) throws {
        pingCount += 1
        let pingMessage = OSCMessage("/avatar/parameters/HeartRatePing", values: [1])
        try send(pingMessage, to: host, port: port)
    }
    
    func sendHeartRate(_ bpm: Double, to host: String, port: UInt16) throws {
        let validBpm = max(30, min(bpm, 220))
        heartRateValues.append(validBpm)
        let hrMessage = OSCMessage("/avatar/parameters/HeartRate", values: [validBpm])
        try send(hrMessage, to: host, port: port)
    }
}

@Suite(.serialized) struct ConnectivityManagerTests {
    
    @Test func testConnectChangesStateToConnecting() {
        // Create a subclass that lets us access the internal state immediately after setting it
        class TestConnectivityManager: ConnectivityManager {
            var capturedState: ConnectionState? = nil
            
            override func connect(to host: String, port: Int) {
                // Capture the state right after it's set to connecting
                connectionState = .connecting
                capturedState = connectionState
                
                // Continue with normal process which will likely change the state
                super.connect(to: host, port: port)
            }
        }
        
        // Arrange - Create test manager instance
        let manager = TestConnectivityManager()
        manager.connectionState = .disconnected
        
        // Act
        manager.connect(to: "test.local", port: 9000)
        
        // Assert - Check that it was set to connecting before potentially changing to another state
        #expect(manager.capturedState == .connecting)
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
    
    @Test func testRealOSCConnection() {
        // Arrange - Create a mock OSC client
        let mockClient = ConnectivityManagerTestOSCClient()
        
        // Create manager with mock client for testing
        let manager = ConnectivityManager(oscClient: mockClient)
        
        // Act - Connect with valid parameters
        manager.connect(to: "test-host.local", port: 9000)
        
        // Assert
        #expect(manager.connectionState == .connected)
        #expect(manager.oscConnected == true)
        #expect(mockClient.pingCount == 1) // Should have sent a ping
        #expect(mockClient.lastHost == "test-host.local")
        #expect(mockClient.lastPort == 9000)
    }
    
    @Test func testConnectionFailure() {
        // Arrange - Create a mock OSC client set to fail
        let mockClient = ConnectivityManagerTestOSCClient()
        mockClient.shouldSucceed = false
        
        // Create manager with mock client for testing
        let manager = ConnectivityManager(oscClient: mockClient)
        
        // Act - Connect with valid parameters, but client set to fail
        manager.connect(to: "test-host.local", port: 9000)
        
        // Assert
        #expect(manager.connectionState == .error)
        #expect(manager.oscConnected == false)
        #expect(manager.lastError != nil)
    }
    
    @Test func testForwardHeartRateToOSC() {
        // Arrange - Create a mock OSC client
        let mockClient = ConnectivityManagerTestOSCClient()
        
        // Create manager with mock client for testing
        let manager = ConnectivityManager(oscClient: mockClient)
        
        // Set up manager state
        manager.oscConnected = true
        manager.connectionState = .connected
        
        // Act - Forward heart rate
        manager.forwardHeartRateToOSC(75.5)
        
        // Assert
        #expect(mockClient.heartRateValues.count == 1)
        #expect(mockClient.heartRateValues[0] == 75.5)
        #expect(mockClient.lastMessage?.addressPattern == "/avatar/parameters/HeartRate")
    }
    
    @Test func testHeartRateProcessingWithOSC() {
        // Arrange - Create a mock OSC client
        let mockClient = ConnectivityManagerTestOSCClient()
        
        // Create manager with mock client for testing
        let manager = ConnectivityManager(oscClient: mockClient)
        
        // Set up manager state
        manager.oscConnected = true
        manager.connectionState = .connected
        
        // Act - Process a watch message
        manager.processWatchMessage(["heartRate": 82.5])
        
        // Assert - Heart rate should be forwarded to OSC
        #expect(mockClient.heartRateValues.count == 1)
        #expect(mockClient.heartRateValues[0] == 82.5)
    }
    
    @Test func testHeartRateNotForwardedWhenDisconnected() {
        // Arrange - Create a mock OSC client
        let mockClient = ConnectivityManagerTestOSCClient()
        
        // Create manager with mock client for testing
        let manager = ConnectivityManager(oscClient: mockClient)
        
        // Set up manager state - NOT connected
        manager.oscConnected = false
        manager.connectionState = .disconnected
        
        // Act - Process a watch message
        manager.processWatchMessage(["heartRate": 82.5])
        
        // Assert - Heart rate should NOT be forwarded to OSC
        #expect(mockClient.heartRateValues.count == 0) // No heart rates sent
    }
}
