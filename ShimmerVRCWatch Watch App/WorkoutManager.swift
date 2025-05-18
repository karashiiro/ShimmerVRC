//
//  WorkoutManager.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import HealthKit
import Combine

// Protocol for easier testing
protocol HealthStoreProtocol {
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>, completion: @escaping (Bool, Error?) -> Void)
}

// Create a wrapper for HKHealthStore that conforms to our protocol
class HealthStoreWrapper: HealthStoreProtocol {
    let healthStore = HKHealthStore()
    
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>, completion: @escaping (Bool, Error?) -> Void) {
        healthStore.requestAuthorization(toShare: toShare, read: read, completion: completion)
    }
    
    func createWorkoutSession(configuration: HKWorkoutConfiguration) throws -> HKWorkoutSession {
        return try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
    }
}

/// Manages an HKWorkoutSession and sends live heart rate to the iPhone.
class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    // Dependencies
    private let healthStoreWrapper: HealthStoreWrapper
    private let connectivityManager: ConnectivityManager
    
    // Workout session objects
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // Published properties for UI binding
    @Published var isAuthorized = false
    @Published var isWorkoutActive = false
    @Published var currentHeartRate: Double = 0
    @Published var lastError: String?
    
    // Heart rate throttling properties
    private var lastSentHeartRate: Double = 0
    private var lastSentTime: Date?
    private let heartRateChangeThreshold: Double = 1.0 // Only send if changed by 1 BPM
    private let minimumSendInterval: TimeInterval = 1.0 // 1 second between updates
    
    /// Initialize with injectable dependencies for testability.
    init(healthStoreWrapper: HealthStoreWrapper = HealthStoreWrapper(),
         connectivityManager: ConnectivityManager = ConnectivityManager.shared) {
        self.healthStoreWrapper = healthStoreWrapper
        self.connectivityManager = connectivityManager
        super.init()
        
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "HealthKit is not available on this device"
            return
        }
    }
    
    /// Requests authorization to read heart rate and write workouts.
    func requestAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let workoutType = HKQuantityType.workoutType()
        
        let typesToRead: Set<HKObjectType> = [heartRateType]
        let typesToShare: Set<HKSampleType> = [workoutType]
        
        healthStoreWrapper.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if let error = error {
                    self.lastError = "Authorization failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Starts an indoor workout session to enable high-frequency HR sampling.
    func startWorkout() {
        guard isAuthorized else {
            lastError = "HealthKit authorization required"
            return
        }
        
        // Create workout configuration
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor
        
        do {
            // Create session and builder
            session = try healthStoreWrapper.createWorkoutSession(configuration: config)
            builder = session?.associatedWorkoutBuilder()
            
            // Get the actual HKHealthStore for the data source
            let healthStore = healthStoreWrapper.healthStore
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            session?.delegate = self
            builder?.delegate = self
            
            // Start session
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                DispatchQueue.main.async {
                    if !success {
                        self.lastError = "Failed to begin workout collection: \(error?.localizedDescription ?? "Unknown error")"
                        return
                    }
                    
                    self.isWorkoutActive = true
                    
                    // Notify iPhone that workout started
                    self.connectivityManager.sendMessage(["workoutStatus": "started"])
                }
            }
        } catch {
            lastError = "Workout session creation failed: \(error.localizedDescription)"
        }
    }
    
    /// Ends the active workout session and stops data collection.
    func stopWorkout() {
        guard isWorkoutActive, let session = session else {
            return
        }
        
        // End the session
        session.end()
        
        // For testing - notify connector if it exists
        if let connector = NSClassFromString("ShimmerVRCWatch_Watch_AppTests.WorkoutSessionConnector") as? NSObject.Type,
           connector.responds(to: NSSelectorFromString("notifySessionEnd")) {
            _ = connector.perform(NSSelectorFromString("notifySessionEnd"))
        }
        
        // Reset state and notify iPhone
        DispatchQueue.main.async {
            self.isWorkoutActive = false
            
            // Send status update to iPhone
            self.connectivityManager.sendMessage(["workoutStatus": "stopped"])
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    /// Handles workout session state changes.
    func workoutSession(_ session: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            if toState == .ended {
                // End collection and finalize the workout
                self.builder?.endCollection(withEnd: date) { success, error in
                    if !success {
                        self.lastError = "Failed to end collection: \(error?.localizedDescription ?? "Unknown error")"
                    }
                    
                    self.builder?.finishWorkout { workout, error in
                        if let error = error {
                            self.lastError = "Failed to finish workout: \(error.localizedDescription)"
                        }
                        
                        // Reset state
                        DispatchQueue.main.async {
                            self.isWorkoutActive = false
                        }
                    }
                }
            }
        }
    }
    
    func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.lastError = "Workout session failed: \(error.localizedDescription)"
            self.isWorkoutActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    /// Called when new sample data is available; extracts heart rate and forwards to iPhone.
    func workoutBuilder(_ builder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Extract heart rate
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let statistics = builder.statistics(for: hrType),
              let heartRateSample = statistics.mostRecentQuantity() else {
            print("⌚️ No heart rate sample available in collected data")
            return
        }
        
        // Convert to BPM
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let bpm = heartRateSample.doubleValue(for: heartRateUnit)
        
        // Update UI always
        DispatchQueue.main.async {
            self.currentHeartRate = bpm
        }
        
        // Apply throttling to reduce battery impact and network traffic
        let now = Date()
        let shouldSendDueToTime = lastSentTime == nil || now.timeIntervalSince(lastSentTime!) >= minimumSendInterval
        let heartRateChangedEnough = abs(bpm - lastSentHeartRate) >= heartRateChangeThreshold
        
        guard shouldSendDueToTime && heartRateChangedEnough else {
            // Skip this update - not significant enough change or too soon
            return
        }
        
        print("⌚️ Collected heart rate: \(bpm) BPM - sending to iPhone")
        
        // Update tracking properties
        lastSentTime = now
        lastSentHeartRate = bpm
        
        // Forward to iPhone with a simpler message format
        DispatchQueue.main.async {
            print("⌚️ Forwarding heart rate to iPhone: \(bpm) BPM")
            self.connectivityManager.sendHeartRate(bpm)
        }
    }
    
    func workoutBuilderDidCollectEvent(_ builder: HKLiveWorkoutBuilder) {
        // Not needed for heart rate streaming
    }
}
