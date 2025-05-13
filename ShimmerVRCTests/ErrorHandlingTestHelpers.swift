//
//  ErrorHandlingTestHelpers.swift
//  ShimmerVRCTests
//
//  Created by karashiiro on 5/12/25.
//

import Foundation
import OSCKit
@testable import ShimmerVRC

// Extensions to ConnectivityManager for testing
extension ConnectivityManager {
    // These methods are for testing purposes only
    
    // Test helper to trigger reconnection with a custom implementation
    func testTriggerReconnect(host: String, port: Int) {
        // Since we can't access private methods, we'll implement a simplified version for testing
        // This simulates what the private scheduleReconnect method would do
        connectionState = .connecting
        
        // Post notification
        NotificationCenter.default.post(
            name: .heartRateReconnecting,
            object: nil,
            userInfo: [
                "attempt": 1,
                "maxAttempts": 5,
                "host": host,
                "port": port
            ]
        )
        
        // Attempt connection
        connect(to: host, port: port)
    }
    
    // Test helper to directly set error state
    func testSetError(_ error: HeartRateConnectionError) {
        currentError = error
        lastError = error.localizedDescription
        connectionState = .error
        
        // Post notification
        NotificationCenter.default.post(
            name: .heartRateConnectionError,
            object: nil,
            userInfo: [
                "error": error.localizedDescription,
                "errorType": String(describing: error)
            ]
        )
    }
    
    // Test helper to simulate network changes
    func testSimulateNetworkChange(available: Bool) {
        if available {
            // Simulate network restoration
            if connectionState == .error && currentError == .networkUnavailable {
                // Reset error state
                currentError = nil
                lastError = nil
                
                // Attempt reconnection if we have previous connection settings
                if !targetHost.isEmpty && targetPort > 0 && targetPort <= 65535 {
                    connect(to: targetHost, port: targetPort)
                }
            }
        } else {
            // Simulate network loss
            if connectionState == .connected || connectionState == .connecting {
                currentError = .networkUnavailable
                lastError = currentError?.localizedDescription
                connectionState = .error
                
                // Post notification
                NotificationCenter.default.post(
                    name: .heartRateConnectionError,
                    object: nil,
                    userInfo: [
                        "error": currentError?.localizedDescription ?? "Network unavailable",
                        "errorType": String(describing: currentError)
                    ]
                )
            }
        }
    }
}

// Extensions to HeartRateConnectionError for better testing
extension HeartRateConnectionError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .watchConnectionLost:
            return "watchConnectionLost"
        case .watchUnreachable:
            return "watchUnreachable"
        case .networkUnavailable:
            return "networkUnavailable"
        case .hostUnreachable(let host):
            return "hostUnreachable(\(host))"
        case .portInvalid(let port):
            return "portInvalid(\(port))"
        case .oscSendFailure(let message):
            return "oscSendFailure(\(message))"
        case .connectionTimeout:
            return "connectionTimeout"
        case .maxRetriesExceeded:
            return "maxRetriesExceeded"
        case .invalidHostOrPort:
            return "invalidHostOrPort"
        }
    }
}
