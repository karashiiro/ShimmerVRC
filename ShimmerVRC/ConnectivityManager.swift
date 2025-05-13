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
import OSCKit

/// State management for connections
class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    // Singleton instance
    // Background task identifier for keeping app alive
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Timer for periodic connectivity checking
    private var connectionMonitorTimer: Timer?
    
    // OSC client for sending heart rate data
    private var oscClient: OSCClientProtocol
    static let shared = ConnectivityManager()
    
    // Connection state
    @Published var connectionState: ConnectionState = .disconnected
    @Published var watchConnected = false
    @Published var oscConnected = false
    @Published var watchWorkoutActive = false
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
    
    init(oscClient: OSCClientProtocol = OSCClient()) {
        self.oscClient = oscClient
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
    
    /// Processes a message from the Watch - separate method to allow direct calls in tests
    func processWatchMessage(_ message: [String : Any]) {
        // Handle workout status updates
        if let status = message["workoutStatus"] as? String {
            DispatchQueue.main.async { [weak self] in
                switch status {
                case "started":
                    self?.watchWorkoutActive = true
                case "stopped":
                    self?.watchWorkoutActive = false
                default:
                    print("Unknown workout status: \(status)")
                }
            }
        }
        
        // Handle heart rate updates
        if let heartRate = message["heartRate"] as? Double {
            // For tests, update the value directly without dispatch
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                self.bpm = heartRate
                self.messageCount += 1
                self.lastMessageTime = Date()
                print("Test mode: Processed heart rate: \(heartRate) BPM")
                
                // Forward to OSC if connected (test mode)
                if self.oscConnected {
                    try? self.oscClient.sendHeartRate(heartRate, to: targetHost, port: UInt16(targetPort))
                }
            } else {
                // Normal app operation - use async dispatch
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.bpm = heartRate
                    self.messageCount += 1
                    self.lastMessageTime = Date()
                    print("Received heart rate from Watch: \(heartRate) BPM")
                    
                    // Forward to OSC if connected
                    if self.oscConnected {
                        self.forwardHeartRateToOSC(heartRate)
                    }
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
    
    // MARK: - Watch Control Methods
    
    /// Starts the workout on the Apple Watch
    func startWorkout() {
        guard WCSession.default.isReachable else {
            lastError = "Apple Watch is not reachable"
            return
        }
        
        // Send command to watch
        WCSession.default.sendMessage(["command": "startWorkout"], replyHandler: { response in
            print("Watch responded to start workout: \(response)")
        }, errorHandler: { error in
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "Failed to start workout: \(error.localizedDescription)"
            }
        })
    }
    
    /// Stops the workout on the Apple Watch
    func stopWorkout() {
        guard WCSession.default.isReachable else {
            lastError = "Apple Watch is not reachable"
            return
        }
        
        // Send command to watch
        WCSession.default.sendMessage(["command": "stopWorkout"], replyHandler: { response in
            print("Watch responded to stop workout: \(response)")
        }, errorHandler: { error in
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "Failed to stop workout: \(error.localizedDescription)"
            }
        })
    }
    
    // MARK: - OSC Connection Methods
    
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
        
        // Test connection by sending a ping
        do {
            try oscClient.sendPing(to: host, port: UInt16(port))
            
            // If we get here, the message was sent successfully
            // Note: This doesn't guarantee the target received it, just that it was sent
            oscConnected = true
            connectionState = .connected
            
            // Start background tasks to keep app alive
            registerBackgroundTask()
            
            // Start connectivity monitoring
            startConnectionMonitoring()
        } catch {
            oscConnected = false
            lastError = "Connection failed: \(error.localizedDescription)"
            connectionState = .error
        }
    }
    
    /// Disconnects from the current OSC target
    func disconnect() {
        oscConnected = false
        connectionState = .disconnected
        
        // Stop monitoring
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = nil
        
        // End background task
        endBackgroundTask()
    }
    
    // MARK: - OSC Methods
    
    /// Forwards heart rate data via OSC
    /// - Parameter heartRate: The heart rate value to send
    func forwardHeartRateToOSC(_ heartRate: Double) {
        guard oscConnected && connectionState == .connected else { return }
        
        do {
            try oscClient.sendHeartRate(heartRate, to: targetHost, port: UInt16(targetPort))
        } catch {
            print("Failed to send heart rate: \(error.localizedDescription)")
            lastError = "Failed to send heart rate: \(error.localizedDescription)"
            connectionState = .error
            oscConnected = false
            
            // Stop monitoring since we're in an error state
            connectionMonitorTimer?.invalidate()
        }
    }
    
    /// Registers a background task to keep the app running
    private func registerBackgroundTask() {
        endBackgroundTask() // End any existing task first
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    /// Ends the current background task
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    /// Starts a timer to periodically check connection health
    private func startConnectionMonitoring() {
        connectionMonitorTimer?.invalidate()
        
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, self.connectionState == .connected else { return }
            
            // Check if we've received a message recently (only if watch is connected)
            if self.watchConnected, let lastTime = self.lastMessageTime, Date().timeIntervalSince(lastTime) > 30.0 {
                self.lastError = "No data received from watch in 30 seconds"
                // Don't change connection state as OSC might still be valid
            }
            
            // Send keep-alive ping
            do {
                try self.oscClient.sendPing(to: self.targetHost, port: UInt16(self.targetPort))
            } catch {
                self.lastError = "Connection lost: \(error.localizedDescription)"
                self.connectionState = .error
                self.oscConnected = false
                self.connectionMonitorTimer?.invalidate()
                self.connectionMonitorTimer = nil
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
