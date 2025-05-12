//
//  ShimmerVRCApp.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

@main
struct ShimmerVRCApp: App {
    @StateObject private var connectivityManager = ConnectivityManager.shared

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
                        connectivityManager.simulationDelay = 0.5
                        connectivityManager.simulationSuccessRate = 1.0
                        
                        // Set a default host for testing
                        connectivityManager.targetHost = "test.local"
                    }
            } else {
                MainView()
            }
        }
    }
}
