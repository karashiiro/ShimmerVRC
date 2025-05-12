//
//  ShimmerVRCApp.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

@main
struct ShimmerVRCApp: App {
    var body: some Scene {
        WindowGroup {
            // Launch different views based on launch arguments
            if CommandLine.arguments.contains("--test-ecg") {
                ECGTestHarness()
            } else if CommandLine.arguments.contains("--ui-testing") {
                // Special mode for UI testing with more reliable elements
                MainView()
                    .onAppear {
                        // Force ConnectivityManager to deterministic behavior for testing
                        let manager = ConnectivityManager.shared
                        manager.simulationDelay = 0.5
                        manager.simulationSuccessRate = 1.0
                        
                        // Set a default host for testing
                        manager.targetHost = "test.local"
                    }
            } else {
                MainView()
            }
        }
    }
}
