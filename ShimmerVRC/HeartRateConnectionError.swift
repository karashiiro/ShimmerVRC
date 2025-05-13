//
//  HeartRateConnectionError.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/12/25.
//

import Foundation

/// Custom error types for heart rate monitoring connections
enum HeartRateConnectionError: Error, Equatable {
    case watchConnectionLost
    case watchUnreachable
    case networkUnavailable
    case hostUnreachable(host: String)
    case portInvalid(port: Int)
    case oscSendFailure(message: String)
    case connectionTimeout
    case maxRetriesExceeded
    case invalidHostOrPort
    
    /// User-friendly error message
    var localizedDescription: String {
        switch self {
        case .watchConnectionLost:
            return "Connection to Apple Watch was lost. Ensure your watch is nearby and both devices have Bluetooth enabled."
        case .watchUnreachable:
            return "Apple Watch is not reachable. Check that your watch is nearby and Bluetooth is enabled."
        case .networkUnavailable:
            return "Network connection is unavailable. Please check your Wi-Fi or cellular connection."
        case .hostUnreachable(let host):
            return "Cannot reach host: \(host). Verify the host is online and on the same network."
        case .portInvalid(let port):
            return "Invalid port number: \(port). Port must be between 1 and 65535."
        case .oscSendFailure(let message):
            return "Failed to send data: \(message)"
        case .connectionTimeout:
            return "Connection timed out. The server may be offline or unreachable."
        case .maxRetriesExceeded:
            return "Maximum reconnection attempts exceeded. Please try connecting again manually."
        case .invalidHostOrPort:
            return "Invalid host or port. Please check your connection settings."
        }
    }
}

/// Extension for Notification.Name constants
extension Notification.Name {
    static let heartRateConnected = Notification.Name("heartRateConnected")
    static let heartRateConnectionError = Notification.Name("heartRateConnectionError")
    static let heartRateReconnecting = Notification.Name("heartRateReconnecting")
    static let heartRateDisconnected = Notification.Name("heartRateDisconnected")
}
