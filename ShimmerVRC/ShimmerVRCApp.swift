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
            // Show test harness only when running ECG tests
            if CommandLine.arguments.contains("test-ecg-view") {
                ECGTestHarness()
            } else {
                ContentView()
            }
        }
    }
}
