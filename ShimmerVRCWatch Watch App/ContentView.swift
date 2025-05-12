//
//  ContentView.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isRunning = false
    @State private var heartRate: Double = 0
    @EnvironmentObject private var connectivityManager: ConnectivityManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Display heart rate
            Text("\(Int(heartRate))")
                .font(.system(size: 48))
                .fontWeight(.bold)
            
            Text("BPM")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Connection status indicator
            HStack {
                Circle()
                    .fill(connectivityManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(connectivityManager.isConnected ? "Connected" : "Not Connected")
                    .font(.caption2)
            }
            
            // Start/Stop button
            Button(action: {
                isRunning.toggle()
                // Will implement actual workout start/stop in next step
            }) {
                Text(isRunning ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isRunning ? .red : .green)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(ConnectivityManager.shared)
}
