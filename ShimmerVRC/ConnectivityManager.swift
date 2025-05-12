//
//  ConnectivityManager.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import SwiftUI
import Combine
import WatchConnectivity

/// State management for connections
class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    // Connection state
    @Published var connectionState: ConnectionState = .disconnected
    @Published var watchConnected = false
    @Published var oscConnected = false
    @Published var lastError: String?
    
    // Heart rate data
    @Published var bpm: Double = 60.0
    @Published var lastMessageTime: Date?
    @Published var messageCount: Int = 0
    
    // Configuration
    @Published var targetHost: String = ""
    @Published var targetPort: Int = 9000
    
    // Testing properties
    var simulationDelay: TimeInterval = 2.0
    var simulationSuccessRate: Double = 0.8
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error
    }
    
    override init() {
        super.init()
        
        // Set up and activate WatchConnectivity session
        activateWCSession()
        
        // Load saved configuration if any
        loadSavedConfiguration()
    }
    
    // MARK: - WatchConnectivity Setup
    
    /// Activates the WatchConnectivity session if supported
    private func activateWCSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate Methods
    
    /// Called when the session activation state changes
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch activationState {
            case .activated:
                print("WCSession activated successfully")
                self.watchConnected = session.isReachable
            case .inactive, .notActivated:
                print("WCSession not activated: \(error?.localizedDescription ?? "Unknown error")")
                self.watchConnected = false
            @unknown default:
                print("WCSession unknown state")
                self.watchConnected = false
            }
        }
    }
    
    /// Called when the reachability of the counterpart app changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConnected = session.isReachable
        }
    }
    
    /// Called when a message is received from the counterpart app
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        processWatchMessage(message)
    }
    
    /// Processes a heart rate message - separate method to allow direct calls in tests
    func processWatchMessage(_ message: [String : Any]) {
        if let heartRate = message["heartRate"] as? Double {
            // For tests, update the value directly without dispatch
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                self.bpm = heartRate
                self.messageCount += 1
                self.lastMessageTime = Date()
                print("Test mode: Processed heart rate: \(heartRate) BPM")
            } else {
                // Normal app operation - use async dispatch
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.bpm = heartRate
                    self.messageCount += 1
                    self.lastMessageTime = Date()
                    print("Received heart rate from Watch: \(heartRate) BPM")
                }
            }
        }
    }
    
    /// Required for iOS - Called when the session becomes inactive
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConnected = false
        }
    }
    
    /// Required for iOS - Called when the session is deactivated
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for next connection
        DispatchQueue.main.async { [weak self] in
            self?.watchConnected = false
            
            // Reactivate the session (required for iOS when switching to a new watch)
            WCSession.default.activate()
        }
    }
    
    // MARK: - Public Methods
    
    /// Attempts to connect to the specified OSC target
    func connect(to host: String, port: Int) {
        // Update state
        connectionState = .connecting
        lastError = nil
        
        // Validate inputs
        guard !host.isEmpty, port > 0 && port <= 65535 else {
            lastError = "Invalid host or port"
            connectionState = .error
            return
        }
        
        // Save configuration
        targetHost = host
        targetPort = port
        saveConfiguration()
        
        // Simulate connection
        // This will be replaced with actual OSC client setup in Phase 2.3
        simulateConnection()
    }
    
    /// Disconnects from the current OSC target
    func disconnect() {
        oscConnected = false
        connectionState = .disconnected
    }
    
    // MARK: - Methods for Simulation
    
    func simulateConnection() {
        // This simulates the connection process for UI development
        // Will be replaced with real implementation
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + simulationDelay) { [weak self] in
            guard let self = self else { return }
            
            // Determine success based on configured success rate
            let success = Double.random(in: 0...1) < self.simulationSuccessRate
            
            if success {
                self.oscConnected = true
                self.connectionState = .connected
            } else {
                self.lastError = "Failed to connect to host"
                self.connectionState = .error
            }
        }
    }
    
    // MARK: - Configuration Methods
    
    func saveConfiguration() {
        // Save the current configuration
        UserDefaults.standard.set(targetHost, forKey: "lastHost")
        UserDefaults.standard.set(targetPort, forKey: "lastPort")
    }
    
    func loadSavedConfiguration() {
        // Load previously saved configuration
        if let savedHost = UserDefaults.standard.string(forKey: "lastHost") {
            targetHost = savedHost
        }
        
        targetPort = UserDefaults.standard.integer(forKey: "lastPort")
        if targetPort == 0 {
            // Default VRChat port
            targetPort = 9000
        }
    }
}
