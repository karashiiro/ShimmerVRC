//
//  ConnectivityManagerTests.swift
//  ShimmerVRCWatch Watch AppTests
//
//  Created by karashiiro on 5/11/25.
//

import XCTest
@testable import ShimmerVRCWatch_Watch_App

class MockWCSession: WatchConnectivityProtocol {
    var isReachable: Bool = true
    var activateWasCalled = false
    var lastMessageSent: [String: Any]?
    
    func activate() {
        activateWasCalled = true
    }
    
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
        lastMessageSent = message
    }
}

class ConnectivityManagerTests: XCTestCase {
    func testInitialization_ActivatesSession() {
        // Arrange
        let mockSession = MockWCSession()
        
        // Act
        let _ = ConnectivityManager(session: mockSession)
        
        // Assert
        XCTAssertTrue(mockSession.activateWasCalled, "WCSession should be activated during initialization")
    }
    
    func testSendHeartRate_SendsCorrectMessage() {
        // Arrange
        let mockSession = MockWCSession()
        let manager = ConnectivityManager(session: mockSession)
        let heartRate: Double = 75.0
        
        // Act
        manager.sendHeartRate(heartRate)
        
        // Assert
        XCTAssertNotNil(mockSession.lastMessageSent, "A message should have been sent")
        XCTAssertEqual(mockSession.lastMessageSent?["heartRate"] as? Double, heartRate, "Heart rate should be sent correctly")
    }
    
    func testSendHeartRate_WhenNotReachable_DoesNotSendMessage() {
        // Arrange
        let mockSession = MockWCSession()
        mockSession.isReachable = false
        let manager = ConnectivityManager(session: mockSession)
        
        // Act
        manager.sendHeartRate(75.0)
        
        // Assert
        XCTAssertNil(mockSession.lastMessageSent, "No message should be sent when iPhone is not reachable")
        XCTAssertNotNil(manager.lastError, "Error should be set when iPhone is not reachable")
    }
}
