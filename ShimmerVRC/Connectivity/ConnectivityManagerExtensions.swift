//
//  ConnectivityManagerExtensions.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/14/25.
//

import Foundation
import WatchConnectivity

// Extensions for additional WatchConnectivity delegate methods
extension ConnectivityManager {
    /// Called when user info transfer is received
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("📱 Received user info from watch: \(userInfo)")
        
        // Handle heart rate data
        if let heartRate = userInfo["hr"] as? Int {
            print("📱 Processing heart rate from UserInfo: \(heartRate) BPM")
            
            // Update heart rate data directly
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.bpm = Double(heartRate)
                self.messageCount += 1
                self.lastMessageTime = Date()
                
                // Forward to OSC if connected
                if self.oscConnected && self.connectionState == .connected {
                    self.forwardHeartRateToOSC(Double(heartRate))
                }
            }
        }
        
        // Handle workout status
        if let status = userInfo["workoutStatus"] as? String {
            print("📱 Received workout status via UserInfo: \(status)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                switch status {
                case "started":
                    self.watchWorkoutActive = true
                case "stopped":
                    self.watchWorkoutActive = false
                default:
                    print("📱 Unknown workout status: \(status)")
                }
            }
        }
    }
    
    /// Called when application context is received
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context from watch: \(applicationContext)")
        
        // Special handling for workout status updates
        if let status = applicationContext["workoutStatus"] as? String {
            print("📱 Received workout status via app context: \(status)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                switch status {
                case "started":
                    self.watchWorkoutActive = true
                case "stopped":
                    self.watchWorkoutActive = false
                default:
                    print("📱 Unknown workout status: \(status)")
                }
            }
        }
    }
}
