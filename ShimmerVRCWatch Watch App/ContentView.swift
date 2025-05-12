//
//  ContentView.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var connectivityManager: ConnectivityManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Display heart rate
            Text("\(Int(workoutManager.currentHeartRate))")
                .font(.system(size: 48))
                .fontWeight(.bold)
                .foregroundColor(heartRateColor)
                .accessibilityLabel("Heart rate")
                .accessibilityValue("\(Int(workoutManager.currentHeartRate)) beats per minute")
            
            Text("BPM")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Status indicators
            VStack(spacing: 8) {
                // Authorization status
                HStack {
                    Circle()
                        .fill(workoutManager.isAuthorized ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(workoutManager.isAuthorized ? "Authorized" : "Not Authorized")
                        .font(.caption2)
                }
                
                // Connection status
                HStack {
                    Circle()
                        .fill(connectivityManager.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(connectivityManager.isConnected ? "Connected" : "Not Connected")
                        .font(.caption2)
                }
            }
            
            // Start/Stop button
            Button(action: {
                if workoutManager.isWorkoutActive {
                    workoutManager.stopWorkout()
                } else {
                    workoutManager.startWorkout()
                }
            }) {
                Text(workoutManager.isWorkoutActive ? "Stop Workout" : "Start Workout")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(workoutManager.isWorkoutActive ? .red : .green)
            .disabled(!workoutManager.isAuthorized)
            
            // Error display (if any)
            if let error = workoutManager.lastError ?? connectivityManager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            // Request authorization when view appears
            workoutManager.requestAuthorization()
        }
    }
    
    // Heart rate color based on value
    private var heartRateColor: Color {
        if workoutManager.currentHeartRate == 0 {
            return .gray  // Not measuring
        } else if workoutManager.currentHeartRate < 60 {
            return .blue  // Low
        } else if workoutManager.currentHeartRate < 100 {
            return .green // Normal
        } else if workoutManager.currentHeartRate < 140 {
            return .orange // Elevated
        } else {
            return .red   // High
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutManager.shared)
        .environmentObject(ConnectivityManager.shared)
}
