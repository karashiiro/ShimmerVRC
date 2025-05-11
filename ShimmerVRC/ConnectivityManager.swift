//
//  ConnectivityManager.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import SwiftUI
import Combine

/// State management for connections
class ConnectivityManager: ObservableObject {
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
    
    init() {
        // This is made internal for testing purposes
        // This will be expanded in Phase 2.2 & 2.3
        // For now, this is just a placeholder
        
        // Load saved configuration if any
        loadSavedConfiguration()
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
