//
//  OSCClientProtocol.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import OSCKit

/// Protocol for OSC client abstraction to enable dependency injection and testing
protocol OSCClientProtocol {
    /// Send an OSC message to a specific host and port
    /// - Parameters:
    ///   - message: The OSC message to send
    ///   - host: The host to send the message to
    ///   - port: The port to send the message to
    /// - Throws: Error if the message cannot be sent
    func send(_ message: OSCMessage, to host: String, port: UInt16) throws
    
    /// Send a simple ping to test connectivity
    /// - Parameters:
    ///   - host: The host to send the ping to
    ///   - port: The port to send the ping to
    /// - Throws: Error if the ping cannot be sent
    func sendPing(to host: String, port: UInt16) throws
    
    /// Send a heart rate value to the target
    /// - Parameters:
    ///   - bpm: The heart rate value in beats per minute
    ///   - host: The host to send the heart rate to
    ///   - port: The port to send the heart rate to
    /// - Throws: Error if the message cannot be sent
    func sendHeartRate(_ bpm: Double, to host: String, port: UInt16) throws
}

/// Concrete implementation of OSCClientProtocol using OSCKit's OSCClient
class OSCClient: OSCClientProtocol {
    // OSCKit client
    private let oscClient = OSCKit.OSCClient()
    
    /// Initialize a new OSC client
    init() {
        // Start the client if needed
        try? oscClient.start()
    }
    
    /// Send an OSC message to a specific host and port
    /// - Parameters:
    ///   - message: The OSC message to send
    ///   - host: The host to send the message to
    ///   - port: The port to send the message to
    /// - Throws: Error if the message cannot be sent
    func send(_ message: OSCMessage, to host: String, port: UInt16) throws {
        try oscClient.send(message, to: host, port: port)
    }
    
    /// Send a simple ping message to test connectivity
    /// - Parameters:
    ///   - host: The host to send the ping to
    ///   - port: The port to send the ping to
    /// - Throws: Error if the ping cannot be sent
    func sendPing(to host: String, port: UInt16) throws {
        let pingMessage = OSCMessage("/avatar/parameters/HeartRatePing", values: [1])
        try send(pingMessage, to: host, port: port)
    }
    
    /// Send a heart rate value to the target
    /// - Parameters:
    ///   - bpm: The heart rate value in beats per minute
    ///   - host: The host to send the heart rate to
    ///   - port: The port to send the heart rate to
    /// - Throws: Error if the message cannot be sent
    func sendHeartRate(_ bpm: Double, to host: String, port: UInt16) throws {
        // Validate BPM range
        let validBpm = max(30, min(bpm, 220)) // Clamp to reasonable physiological range
        
        // Create OSC message with VRChat-compatible address pattern
        let hrMessage = OSCMessage("/avatar/parameters/HeartRate", values: [validBpm])
        try send(hrMessage, to: host, port: port)
    }
}
