//
//  ShimmerVRCApp.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI
import UIKit

// Add lifecycle observer to handle app state changes
class AppLifecycleObserver: NSObject, ObservableObject {
    @Published var isActive = true
    
    override init() {
        super.init()
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(self, 
            selector: #selector(appDidEnterBackground), 
            name: UIApplication.didEnterBackgroundNotification, 
            object: nil)
            
        NotificationCenter.default.addObserver(self, 
            selector: #selector(appWillEnterForeground), 
            name: UIApplication.willEnterForegroundNotification, 
            object: nil)
            
        NotificationCenter.default.addObserver(self, 
            selector: #selector(appWillTerminate), 
            name: UIApplication.willTerminateNotification, 
            object: nil)
    }
    
    @objc func appDidEnterBackground() {
        isActive = false
        ConnectivityManager.shared.applicationDidEnterBackground()
    }
    
    @objc func appWillEnterForeground() {
        isActive = true
        ConnectivityManager.shared.applicationWillEnterForeground()
    }
    
    @objc func appWillTerminate() {
        ConnectivityManager.shared.applicationWillTerminate()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct ShimmerVRCApp: App {
    @StateObject private var connectivityManager = ConnectivityManager.shared
    @StateObject private var lifecycleObserver = AppLifecycleObserver()

    var body: some Scene {
        WindowGroup {
            // Add environment object for lifecycle state
            // Launch different views based on launch arguments
            if CommandLine.arguments.contains("--test-ecg") {
                ECGTestHarness()
                    .environmentObject(lifecycleObserver)
            } else if CommandLine.arguments.contains("--ui-testing") {
                // Special mode for UI testing with more reliable elements
                MainView()
                    .environmentObject(lifecycleObserver)
                    .onAppear {
                        // Force ConnectivityManager to deterministic behavior for testing
                        connectivityManager.simulationDelay = 0.5
                        connectivityManager.simulationSuccessRate = 1.0
                        
                        // Set a default host for testing
                        connectivityManager.targetHost = "test.local"
                    }
            } else {
                MainView()
                    .environmentObject(lifecycleObserver)
            }
        }
    }
}
