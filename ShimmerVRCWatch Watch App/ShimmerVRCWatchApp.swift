//
//  ShimmerVRCWatchApp.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

@main
struct ShimmerVRCWatch_Watch_AppApp: App {
    // Initialize the connectivity manager
    @StateObject private var connectivityManager = ConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
