//
//  ConnectivityManager.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import WatchConnectivity
import Combine

// Protocol for easier unit testing
protocol WatchConnectivityProtocol {
    var isReachable: Bool { get }
    func activate()
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?, errorHandler: ((Error) -> Void)?)
}

// WCSession conformance to protocol
extension WCSession: WatchConnectivityProtocol {}

class ConnectivityManager: NSObject, ObservableObject {
    static let shared = ConnectivityManager()
    
    private let session: WatchConnectivityProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties for UI binding and monitoring
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var messagesSent: Int = 0
    @Published var lastSentTimestamp: Date?
    
    // Debug properties (can be removed in production)
    @Published var reachabilityHistory: [Bool] = []
    @Published var sendAttempts: Int = 0
    
    init(session: WatchConnectivityProtocol = WCSession.default) {
        self.session = session
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            lastError = "WCSession is not supported"
            return
        }
        
        if let wcSession = session as? WCSession {
            wcSession.delegate = self
        }
        
        session.activate()
        
        // Start periodic reachability check
        startReachabilityMonitoring()
    }
    
    /// Sends heart rate data to the paired iPhone
    /// - Parameter heartRate: The heart rate value in beats per minute
    func sendHeartRate(_ heartRate: Double) {
        sendMessage(["heartRate": heartRate])
    }
    
    /// Sends a generic message to the paired iPhone
    /// - Parameter message: The message dictionary to send
    func sendMessage(_ message: [String: Any]) {
        // Always track attempts for analytics
        sendAttempts += 1
        
        // If unreachable, queue message or log the failure
        guard session.isReachable else {
            // Update history for debugging
            updateReachabilityHistory(false)
            if sendAttempts % 10 == 0 { // Only log every 10th attempt to reduce noise
                lastError = "iPhone is not reachable"
            }
            return
        }
        
        // Update history for debugging
        updateReachabilityHistory(true)
        
        // Send the message to iPhone
        session.sendMessage(message, replyHandler: { [weak self] _ in
            // Optional: Handle successful message delivery
            DispatchQueue.main.async {
                self?.messagesSent += 1
                self?.lastSentTimestamp = Date()
                self?.lastError = nil // Clear any previous errors
            }
        }) { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = "Error sending message: \(error.localizedDescription)"
            }
        }
    }
    
    /// Updates the reachability history array for debugging purposes
    private func updateReachabilityHistory(_ isReachable: Bool) {
        // Add new value to history
        var newHistory = self.reachabilityHistory
        newHistory.append(isReachable)
        
        // Keep only last 20 values
        if newHistory.count > 20 {
            newHistory.removeFirst(newHistory.count - 20)
        }
        
        self.reachabilityHistory = newHistory
    }
    
    /// Starts a timer to periodically check the reachability of the iPhone
    private func startReachabilityMonitoring() {
        // Check reachability every 3 seconds
        Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let wcSession = self.session as? WCSession else { return }
                
                let isReachable = wcSession.isReachable
                self.isConnected = isReachable
                
                // Update reachability history
                self.updateReachabilityHistory(isReachable)
            }
            .store(in: &cancellables)
    }
    
    /// Simulation function for testing
    func simulateSendHeartRate(_ heartRate: Double) {
        // For testing without actual WCSession
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            self.messagesSent += 1
            self.lastSentTimestamp = Date()
            print("Simulated sending heart rate: \(heartRate) BPM")
        } else {
            sendHeartRate(heartRate)
        }
    }
}

extension ConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable
            if let error = error {
                self.lastError = "Activation error: \(error.localizedDescription)"
            }
        }
    }
    
    // Called when reachability changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            self.updateReachabilityHistory(session.isReachable)
            
            if session.isReachable {
                // Clear error when connection established
                if self.lastError == "iPhone is not reachable" {
                    self.lastError = nil
                }
            }
        }
    }
    
    // Required for WCSessionDelegate conformance on watchOS
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle commands from the iPhone
        DispatchQueue.main.async { [weak self] in
            if let command = message["command"] as? String {
                print("Received command from iPhone: \(command)")
                
                switch command {
                case "startWorkout":
                    // Get the workout manager
                    let workoutManager = WorkoutManager.shared
                    
                    // Start the workout
                    if !workoutManager.isWorkoutActive {
                        workoutManager.requestAuthorization() // Ensure we're authorized
                        workoutManager.startWorkout()
                        
                        // Reply with success and status
                        replyHandler(["status": "success", "action": "started", "isActive": workoutManager.isWorkoutActive])
                    } else {
                        // Already running
                        replyHandler(["status": "success", "action": "none", "message": "Workout already active", "isActive": true])
                    }
                    
                case "stopWorkout":
                    // Get the workout manager
                    let workoutManager = WorkoutManager.shared
                    
                    // Stop the workout
                    if workoutManager.isWorkoutActive {
                        workoutManager.stopWorkout()
                        
                        // Reply with success and status
                        replyHandler(["status": "success", "action": "stopped", "isActive": workoutManager.isWorkoutActive])
                    } else {
                        // Already stopped
                        replyHandler(["status": "success", "action": "none", "message": "No active workout", "isActive": false])
                    }
                    
                default:
                    // Unknown command
                    replyHandler(["status": "error", "message": "Unknown command: \(command)"])
                }
            } else {
                // No command specified
                replyHandler(["status": "error", "message": "No command specified"])
            }
        }
    }
    
    // Handle messages without reply handlers
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Forward to the handler with reply
        self.session(session, didReceiveMessage: message) { _ in 
            // No reply needed
        }
    }
}
