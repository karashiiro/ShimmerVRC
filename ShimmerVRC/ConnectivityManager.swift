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
import Network

/// State management for connections
class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    // Singleton instance
    // Background task identifier for keeping app alive
    internal var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskRefreshTimer: Timer?
    // isInBackground is internal for testing
    internal var isInBackground = false
    private var lastSentHeartRate: Double = 0
    private var foregroundThreshold: Double = 1.0  // 1 BPM change in foreground
    private var backgroundThreshold: Double = 3.0  // 3 BPM change in background
    private var lastSendTime: Date = Date()
    
    // Timer for periodic connectivity checking
    private var connectionMonitorTimer: Timer?
    
    // Reconnection properties
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts = 5
    
    // Network path monitor
    private var pathMonitor: NWPathMonitor?
    private var isNetworkAvailable = true
    
    // OSC client for sending heart rate data
    private var oscClient: OSCClientProtocol
    static let shared = ConnectivityManager()
    
    // Connection state
    @Published var connectionState: ConnectionState = .disconnected
    @Published var watchConnected = false
    @Published var oscConnected = false
    @Published var watchWorkoutActive = false
    @Published var lastError: String?
    @Published var currentError: HeartRateConnectionError?
    
    // Heart rate data
    @Published var bpm: Double? = nil  // nil means no heart rate data available
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
        
        // Start network monitoring
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    /// Set up network path monitoring
    private func setupNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newNetworkStatus = path.status == .satisfied
            let networkStatusChanged = newNetworkStatus != self.isNetworkAvailable
            self.isNetworkAvailable = newNetworkStatus
            
            DispatchQueue.main.async {
                if networkStatusChanged {
                    if !self.isNetworkAvailable {
                        // Network was lost
                        self.handleNetworkLost()
                    } else {
                        // Network is back
                        self.handleNetworkRestored()
                    }
                }
            }
        }
        
        // Start monitoring on a background queue
        let monitorQueue = DispatchQueue(label: "com.shimmerVRC.networkMonitor")
        pathMonitor?.start(queue: monitorQueue)
    }
    
    private func handleNetworkLost() {
        // Only update state if we were successfully connected
        if self.connectionState == .connected || self.connectionState == .connecting {
            self.currentError = .networkUnavailable
            self.lastError = self.currentError?.localizedDescription
            self.connectionState = .error
            self.notifyConnectionError()
            
            // Cancel any reconnection attempts
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
        }
    }
    
    private func handleNetworkRestored() {
        // If we were in an error state due to network and we have connection settings,
        // attempt to reconnect
        if self.connectionState == .error && self.currentError == .networkUnavailable {
            // Reset error state
            self.currentError = nil
            self.lastError = nil
            
            // Attempt reconnection if we have previous connection settings
            if !self.targetHost.isEmpty && self.targetPort > 0 && self.targetPort <= 65535 {
                self.reconnectAttempts = 0 // Reset attempts counter
                self.connect(to: self.targetHost, port: self.targetPort)
            }
        }
    }
    
    deinit {
        // Clean up the path monitor
        pathMonitor?.cancel()
        reconnectTimer?.invalidate()
        connectionMonitorTimer?.invalidate()
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
                let wasConnected = self.watchConnected
                self.watchConnected = session.isReachable
                
                // If watch became unreachable, reset heart rate data
                if wasConnected && !self.watchConnected {
                    self.bpm = nil
                    self.watchWorkoutActive = false
                }
            case .inactive, .notActivated:
                print("WCSession not activated: \(error?.localizedDescription ?? "Unknown error")")
                self.watchConnected = false
                self.bpm = nil
                self.watchWorkoutActive = false
            @unknown default:
                print("WCSession unknown state")
                self.watchConnected = false
                self.bpm = nil
                self.watchWorkoutActive = false
            }
        }
    }
    
    /// Called when the reachability of the counterpart app changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let wasConnected = self.watchConnected
            self.watchConnected = session.isReachable
            
            // If watch became unreachable, reset heart rate data
            if wasConnected && !self.watchConnected {
                self.bpm = nil
                self.watchWorkoutActive = false
            }
        }
    }
    
    /// Called when a message is received from the counterpart app
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        processWatchMessage(message)
        
        // If we're in the background, refresh the background task to extend lifetime
        if isInBackground {
            startBackgroundTask()
        }
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
                    if self.oscConnected && self.connectionState == .connected {
                        self.forwardHeartRateToOSC(heartRate)
                    }
                }
            }
        }
    }
    
    /// Required for iOS - Called when the session becomes inactive
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.watchConnected = false
            self.bpm = nil
            self.watchWorkoutActive = false
        }
    }
    
    /// Required for iOS - Called when the session is deactivated
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for next connection
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.watchConnected = false
            self.bpm = nil
            self.watchWorkoutActive = false
            
            // Reactivate the session (required for iOS when switching to a new watch)
            WCSession.default.activate()
        }
    }
    
    // MARK: - Watch Control Methods
    
    /// Starts the workout on the Apple Watch
    func startWorkout() {
        guard WCSession.default.isReachable else {
            currentError = .watchUnreachable
            lastError = currentError?.localizedDescription
            return
        }
        
        // Send command to watch
        WCSession.default.sendMessage(["command": "startWorkout"], replyHandler: { response in
            print("Watch responded to start workout: \(response)")
        }, errorHandler: { error in
            DispatchQueue.main.async { [weak self] in
                self?.currentError = .oscSendFailure(message: error.localizedDescription) 
                self?.lastError = "Failed to start workout: \(error.localizedDescription)"
            }
        })
    }
    
    /// Stops the workout on the Apple Watch
    func stopWorkout() {
        guard WCSession.default.isReachable else {
            currentError = .watchUnreachable
            lastError = currentError?.localizedDescription
            return
        }
        
        // Send command to watch
        WCSession.default.sendMessage(["command": "stopWorkout"], replyHandler: { response in
            print("Watch responded to stop workout: \(response)")
        }, errorHandler: { error in
            DispatchQueue.main.async { [weak self] in
                self?.currentError = .oscSendFailure(message: error.localizedDescription) 
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
        guard !host.isEmpty else {
        currentError = .hostUnreachable(host: "Empty hostname")
        lastError = currentError?.localizedDescription
        connectionState = .error
            notifyConnectionError()
            return
        }
        
        guard port > 0 && port <= 65535 else {
            currentError = .portInvalid(port: port)
            lastError = currentError?.localizedDescription
            connectionState = .error
            notifyConnectionError()
            return
        }
        
        // Save configuration
        targetHost = host
        targetPort = port
        saveConfiguration()
        
        // Create a timeout for the connection attempt
        let connectionTimeout = DispatchWorkItem { [weak self] in
            guard let self = self, self.connectionState == .connecting else { return }
            
            self.currentError = .connectionTimeout
            self.lastError = self.currentError?.localizedDescription
            self.connectionState = .error
            self.oscConnected = false
            self.notifyConnectionError()
            
            // Schedule reconnection attempt
            self.scheduleReconnect(host: host, port: port)
        }
        
        // Schedule timeout (5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: connectionTimeout)
        
        // Test connection by sending a ping
        do {
            try oscClient.sendPing(to: host, port: UInt16(port))
            
            // Cancel the timeout since we succeeded
            connectionTimeout.cancel()
            
            // If we get here, the message was sent successfully
            // Note: This doesn't guarantee the target received it, just that it was sent
            oscConnected = true
            connectionState = .connected
            currentError = nil
            lastError = nil
            reconnectAttempts = 0 // Reset reconnection attempts on success
            
            // Start background tasks to keep app alive
            registerBackgroundTask()
            
            // Start connectivity monitoring
            startConnectionMonitoring()
            
            // Notify connection success
            notifyConnectionSuccess()
            
        } catch {
            // Cancel the timeout since we already failed
            connectionTimeout.cancel()
            
            oscConnected = false
            currentError = .oscSendFailure(message: error.localizedDescription)
            lastError = currentError?.localizedDescription
            connectionState = .error
            notifyConnectionError()
            
            // Schedule reconnection attempt
            scheduleReconnect(host: host, port: port)
        }
    }
    
    /// Disconnects from the current OSC target
    func disconnect() {
        oscConnected = false
        connectionState = .disconnected
        currentError = nil
        lastError = nil
        
        // Stop monitoring
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = nil
        
        // Cancel any reconnection attempts
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        
        // End background task
        endBackgroundTask()
        
        // Notify disconnection
        notifyDisconnection()
    }
    
    // MARK: - OSC Methods
    
    /// Forwards heart rate data via OSC
    /// - Parameter heartRate: The heart rate value to send
    func forwardHeartRateToOSC(_ heartRate: Double) {
        guard oscConnected && connectionState == .connected else { return }
        
        do {
            try forwardWithOptimization(heartRate)
        } catch {
            print("Failed to send heart rate: \(error.localizedDescription)")
            currentError = .oscSendFailure(message: error.localizedDescription)
            lastError = currentError?.localizedDescription
            connectionState = .error
            oscConnected = false
            notifyConnectionError()
            
            // Stop monitoring since we're in an error state
            connectionMonitorTimer?.invalidate()
            
            // Attempt reconnection if network is available
            if isNetworkAvailable && !targetHost.isEmpty {
                scheduleReconnect(host: targetHost, port: targetPort)
            }
        }
    }
    
    /// Forwards heart rate with optimization for background mode
    /// - Parameter bpm: The heart rate to send
    /// - Throws: Error if sending fails
    private func forwardWithOptimization(_ bpm: Double) throws {
        let now = Date()
        let threshold = isInBackground ? backgroundThreshold : foregroundThreshold
        let timeSinceLastSend = now.timeIntervalSince(lastSendTime)
        
        // In foreground: Send if value changed significantly or every 1 second minimum
        // In background: Send if value changed significantly or every 3 seconds minimum
        let minInterval = isInBackground ? 3.0 : 1.0
        
        if abs(bpm - lastSentHeartRate) >= threshold || timeSinceLastSend >= minInterval {
            try oscClient.sendHeartRate(bpm, to: targetHost, port: UInt16(targetPort))
            lastSentHeartRate = bpm
            lastSendTime = now
        }
    }
    
    /// Registers a background task to keep the app running
    private func registerBackgroundTask() {
        endBackgroundTask() // End any existing task first
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("Background task expiring")
            self?.endBackgroundTask()
        }
        
        print("Background task started with ID: \(backgroundTask)")
    }
    
    /// Ends the current background task
    internal func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    /// Setup periodic background task refresh to extend background execution time
    private func setupBackgroundTaskRefresh() {
        // Cancel existing timer
        backgroundTaskRefreshTimer?.invalidate()
        
        // Create a timer that periodically refreshes our background task
        // Run every 2 minutes to refresh the background execution allowance
        backgroundTaskRefreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            print("Refreshing background task")
            self?.startBackgroundTask()
        }
    }
    
    /// Start a new background task
    internal func startBackgroundTask() {
        // End any existing task
        endBackgroundTask()
        
        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // This is the expiration handler
            print("Background task expiration handler called")
            self?.endBackgroundTask()
        }
        
        print("Background task started with ID: \(backgroundTask)")
    }
    
    /// Clean up background resources
    private func cleanupBackgroundResources() {
        backgroundTaskRefreshTimer?.invalidate()
        backgroundTaskRefreshTimer = nil
        endBackgroundTask()
    }
    
    /// Starts a timer to periodically check connection health
    private func startConnectionMonitoring() {
        connectionMonitorTimer?.invalidate()
        
        // Create a timer with longer interval in background
        let interval = isInBackground ? 30.0 : 10.0
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.connectionState == .connected else { return }
            
            // Check if we've received a message recently (only if watch is connected and we're in foreground)
            if !self.isInBackground && self.watchConnected, 
               let lastTime = self.lastMessageTime, 
               Date().timeIntervalSince(lastTime) > 30.0 {
                self.currentError = .watchConnectionLost
                self.lastError = self.currentError?.localizedDescription
                // Don't change connection state as OSC might still be valid
            }
            
            // Send keep-alive ping (with reduced frequency in background)
            if !self.isInBackground || self.needsKeepAlive() {
                do {
                    try self.oscClient.sendPing(to: self.targetHost, port: UInt16(self.targetPort))
                } catch {
                    self.currentError = .oscSendFailure(message: error.localizedDescription)
                    self.lastError = self.currentError?.localizedDescription
                    self.connectionState = .error
                    self.oscConnected = false
                    self.notifyConnectionError()
                    self.connectionMonitorTimer?.invalidate()
                    self.connectionMonitorTimer = nil
                    
                    // Attempt reconnection if network is available
                    if self.isNetworkAvailable && !self.targetHost.isEmpty {
                        self.scheduleReconnect(host: self.targetHost, port: self.targetPort)
                    }
                }
            }
        }
    }
    
    /// Determines if a keep-alive ping is needed in background mode
    private func needsKeepAlive() -> Bool {
        // Only send keep-alive in background if it's been a while
        guard let lastTime = lastMessageTime else { return true }
        return Date().timeIntervalSince(lastTime) > 60.0 // 1 minute
    }
    
    /// Schedules a reconnection attempt with exponential backoff
    private func scheduleReconnect(host: String, port: Int) {
        guard reconnectAttempts < maxReconnectAttempts else {
            // Max attempts reached - notify and reset
            reconnectAttempts = 0
            currentError = .maxRetriesExceeded
            lastError = currentError?.localizedDescription
            connectionState = .disconnected
            notifyConnectionError()
            return
        }
        
        // Cancel any existing reconnect timer
        reconnectTimer?.invalidate()
        
        // Calculate delay with exponential backoff: 1s, 2s, 4s, 8s, 16s
        let backoffInterval = pow(2.0, Double(reconnectAttempts))
        let maxInterval = 30.0 // Cap at 30 seconds
        let delay = min(backoffInterval, maxInterval)
        
        connectionState = .connecting
        
        // Schedule the reconnection attempt
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            self.reconnectAttempts += 1
            self.notifyReconnecting(attempt: self.reconnectAttempts, maxAttempts: self.maxReconnectAttempts)
            self.connect(to: host, port: port)
        }
    }
    
    // MARK: - Notification Methods
    
    /// Notifies UI of a successful connection
    private func notifyConnectionSuccess() {
        NotificationCenter.default.post(
            name: .heartRateConnected,
            object: nil,
            userInfo: [
                "host": targetHost,
                "port": targetPort
            ]
        )
    }
    
    /// Notifies UI of a connection error
    private func notifyConnectionError() {
        NotificationCenter.default.post(
            name: .heartRateConnectionError,
            object: nil,
            userInfo: [
                "error": lastError ?? "Unknown error",
                "errorType": String(describing: currentError)
            ]
        )
    }
    
    /// Notifies UI of a reconnection attempt
    private func notifyReconnecting(attempt: Int, maxAttempts: Int) {
        NotificationCenter.default.post(
            name: .heartRateReconnecting,
            object: nil,
            userInfo: [
                "attempt": attempt,
                "maxAttempts": maxAttempts,
                "host": targetHost,
                "port": targetPort
            ]
        )
    }
    
    /// Notifies UI of a disconnection
    private func notifyDisconnection() {
        NotificationCenter.default.post(
            name: .heartRateDisconnected,
            object: nil
        )
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
    
    // MARK: - Background Lifecycle Methods
    
    /// Called when the app enters background
    func applicationDidEnterBackground() {
        print("App entered background - starting background tasks")
        isInBackground = true
        startBackgroundTask()
        setupBackgroundTaskRefresh()
        
        // Restart connection monitoring with longer intervals
        startConnectionMonitoring()
    }
    
    /// Called when the app will enter foreground
    func applicationWillEnterForeground() {
        print("App entering foreground - cleaning up background resources")
        isInBackground = false
        cleanupBackgroundResources()
        
        // Restart connection monitoring with normal intervals
        startConnectionMonitoring()
    }
    
    /// Called when the app will terminate
    func applicationWillTerminate() {
        print("App terminating - cleaning up resources")
        cleanupBackgroundResources()
    }
}
