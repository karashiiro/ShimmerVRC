//
//  ShimmerVRCWatchApp.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

@main
struct ShimmerVRCWatch_Watch_AppApp: App {
    // Initialize managers
    @StateObject private var connectivityManager = ConnectivityManager.shared
    @StateObject private var workoutManager = WorkoutManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
                .environmentObject(workoutManager)
        }
    }
}
