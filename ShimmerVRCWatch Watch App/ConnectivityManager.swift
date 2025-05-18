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
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer
    func updateApplicationContext(_ applicationContext: [String: Any]) throws
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
    
    // Message queue for reliable delivery
    private var messageQueue = [(message: [String: Any], attempts: Int)]()
    private var isProcessingQueue = false
    private let maxAttempts = 5
    private let retryInterval: TimeInterval = 2.0
    private var pendingUserInfoTransfers = Set<WCSessionUserInfoTransfer>()
    
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
            print("📱 Setting up WCSession, current state: \(wcSession.activationState.description)")
            // Ensure delegate is set BEFORE activation
            wcSession.delegate = self
        }
        
        print("📱 Activating WCSession")
        session.activate()
        
        // Start periodic reachability check
        startReachabilityMonitoring()
    }
    
    /// Sends heart rate data to the paired iPhone
    /// - Parameter heartRate: The heart rate value in beats per minute
    func sendHeartRate(_ heartRate: Double) {
        // For heart rate data, use transferUserInfo which is more reliable for background delivery
        print("📱 Sending heart rate via transferUserInfo: \(heartRate) BPM")
        
        // Create a simpler int-based heart rate message
        let userInfo = ["hr": Int(heartRate)]
        
        // If we're in a test environment, just simulate it
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            simulateSendHeartRate(heartRate)
            return
        }
        
        // Use the user info transfer for better reliability
        if let wcSession = session as? WCSession {
            let transfer = wcSession.transferUserInfo(userInfo)
            pendingUserInfoTransfers.insert(transfer)
            
            // Track usage statistics
            messagesSent += 1
            lastSentTimestamp = Date()
            print("📱 Queued heart rate transfer")
        } else {
            // Fall back to message queue if needed
            enqueueMessage(userInfo)
        }
    }
    
    /// Sends a generic message to the paired iPhone
    /// - Parameter message: The message dictionary to send
    func sendMessage(_ message: [String: Any]) {
        // In test mode, just process directly
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // For testing without actual WCSession
            self.messagesSent += 1
            self.lastSentTimestamp = Date()
            print("Test mode: Simulated sending message: \(message)")
            return
        }
        
        // For workout status messages, use application context
        if let status = message["workoutStatus"] as? String {
            updateWorkoutStatus(status)
            return
        }
        
        // For other messages, use the queue system
        enqueueMessage(message)
    }
    
    /// Adds a message to the queue for reliable delivery
    /// - Parameter message: The message to queue
    private func enqueueMessage(_ message: [String: Any]) {
        // Always track attempts for analytics
        sendAttempts += 1
        
        print("📱 Enqueuing message for delivery: \(message)")
        messageQueue.append((message: message, attempts: 0))
        
        // Start processing the queue
        processMessageQueue()
    }
    
    /// Processes the message queue for reliable delivery
    private func processMessageQueue() {
        // Only process if we're not already processing and have messages
        guard !isProcessingQueue, !messageQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let (message, attempts) = messageQueue.removeFirst()
        
        // Print detailed session state information for debugging
        if let wcSession = session as? WCSession {
            print("📱 WCSession state before processing queue: \(wcSession.activationState.description), isReachable: \(wcSession.isReachable)")
        }
        
        // If unreachable, queue message for retry
        guard session.isReachable else {
            // Update history for debugging
            updateReachabilityHistory(false)
            print("📱 iPhone is not reachable, queuing message for retry: \(message)")
            
            if attempts < maxAttempts {
                messageQueue.append((message: message, attempts: attempts + 1))
                
                // Schedule retry with backoff
                let delay = min(pow(2.0, Double(attempts)), 30.0) // Exponential backoff capped at 30s
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.isProcessingQueue = false
                    self.processMessageQueue()
                }
            } else {
                print("📱 Maximum retry attempts reached for message: \(message)")
                if self.lastError == nil {
                    self.lastError = "Message delivery failed after \(maxAttempts) attempts"
                }
                self.isProcessingQueue = false
                self.processMessageQueue() // Continue with next message
            }
            return
        }
        
        // Update history for debugging
        updateReachabilityHistory(true)
        
        print("📱 Processing queued message: \(message)")
        
        // Try sending with sendMessage first
        if let wcSession = session as? WCSession {
            wcSession.sendMessage(message, replyHandler: { [weak self] response in
                guard let self = self else { return }
                
                // Success! Message delivered
                print("📱 Message delivered successfully, response: \(response)")
                
                DispatchQueue.main.async {
                    self.messagesSent += 1
                    self.lastSentTimestamp = Date()
                    self.lastError = nil
                    
                    // Process next message
                    self.isProcessingQueue = false
                    self.processMessageQueue()
                }
            }, errorHandler: { [weak self] error in
                guard let self = self else { return }
                
                print("📱 Error sending queued message: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("📱 Error details - code: \(nsError.code), domain: \(nsError.domain)")
                }
                
                // Try transferUserInfo as backup mechanism
                print("📱 Falling back to transferUserInfo for message delivery")
                let transfer = wcSession.transferUserInfo(message)
                self.pendingUserInfoTransfers.insert(transfer)
                
                DispatchQueue.main.async {
                    self.messagesSent += 1
                    self.lastSentTimestamp = Date()
                    
                    // No error set because we're falling back to another method
                    
                    // Process next message
                    self.isProcessingQueue = false
                    self.processMessageQueue()
                }
            })
        } else {
            // Default implementation if no WCSession (for mocking in tests)
            DispatchQueue.main.async {
                self.isProcessingQueue = false
                self.processMessageQueue()
            }
        }
    }
    
    /// Updates workout status using application context
    /// - Parameter status: The workout status to update
    private func updateWorkoutStatus(_ status: String) {
        print("📱 Updating workout status via application context: \(status)")
        
        if let wcSession = session as? WCSession {
            do {
                try wcSession.updateApplicationContext(["workoutStatus": status])
                print("📱 Successfully updated application context with workout status")
                
                DispatchQueue.main.async {
                    self.messagesSent += 1
                    self.lastSentTimestamp = Date()
                    self.lastError = nil
                }
            } catch {
                print("📱 Error updating application context: \(error.localizedDescription)")
                
                // Fall back to message queue
                enqueueMessage(["workoutStatus": status])
            }
        } else {
            // Fall back to message queue for testing
            enqueueMessage(["workoutStatus": status])
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
        self.messagesSent += 1
        self.lastSentTimestamp = Date()
        print("Simulated sending heart rate: \(heartRate) BPM")
    }
    
    /// Cleanup resources when the object is deallocated
    deinit {
        // Cancel any background tasks
        pendingUserInfoTransfers.removeAll()
        
        // Cancel any timers from Combine
        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
    }
    

}

extension ConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📱 WCSession activation completed - state: \(activationState.description), isReachable: \(session.isReachable)")
        
        if let error = error {
            print("📱 Activation error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("📱 Activation error details - code: \(nsError.code), domain: \(nsError.domain)")
                print("📱 Activation error userInfo: \(nsError.userInfo)")
            }
        }
        
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable
            if let error = error {
                self.lastError = "Activation error: \(error.localizedDescription)"
            }
        }
    }
    
    // Called when reachability changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 WCSession reachability changed: isReachable = \(session.isReachable), state = \(session.activationState.description)")
        
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            self.updateReachabilityHistory(session.isReachable)
            
            if session.isReachable {
                print("📱 iPhone is now reachable")
                // Clear error when connection established
                if self.lastError == "iPhone is not reachable" {
                    self.lastError = nil
                }
            } else {
                print("📱 iPhone is now unreachable")
            }
        }
    }
    
    // Required for WCSessionDelegate conformance on watchOS
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle commands from the iPhone
        DispatchQueue.main.async {
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
        print("📱 Received message without reply handler: \(message)")
        // Forward to the handler with reply
        self.session(session, didReceiveMessage: message) { response in 
            print("📱 Sending empty response for message without reply handler: \(response)")
        }
    }
    
    // Handle user info transfers completed
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        DispatchQueue.main.async {
            // Remove from tracked transfers
            if let index = self.pendingUserInfoTransfers.firstIndex(of: userInfoTransfer) {
                self.pendingUserInfoTransfers.remove(at: index)
            }
        }
        
        if let error = error {
            print("📱 UserInfo transfer failed: \(error.localizedDescription)")
            // Handle the error - maybe queue as a regular message instead
            DispatchQueue.main.async {
                self.enqueueMessage(userInfoTransfer.userInfo)
            }
        } else {
            print("📱 UserInfo transfer completed successfully")
        }
    }
    
    // Handle receiving application context updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context: \(applicationContext)")
        
        // Process just like a regular message
        DispatchQueue.main.async {
            // Handle status updates
            if let status = applicationContext["workoutStatus"] as? String {
                print("📱 Received workout status via app context: \(status)")
                
                // Forward to workout manager if needed
                let workoutManager = WorkoutManager.shared
                
                switch status {
                case "started":
                    if !workoutManager.isWorkoutActive {
                        workoutManager.requestAuthorization()
                        workoutManager.startWorkout()
                    }
                case "stopped":
                    if workoutManager.isWorkoutActive {
                        workoutManager.stopWorkout()
                    }
                default:
                    print("📱 Unknown workout status: \(status)")
                }
            }
        }
    }
}
