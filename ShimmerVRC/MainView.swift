
//
//  MainView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var connectivityManager = ConnectivityManager.shared
    @State private var showingSettings = false
    @State private var showingConnectionSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Status bar for connections
                ConnectionStatusBar(
                    watchConnected: connectivityManager.watchConnected,
                    oscConnected: connectivityManager.oscConnected,
                    connectionState: connectivityManager.connectionState,
                    watchWorkoutActive: connectivityManager.watchWorkoutActive
                )
                .padding(.horizontal)
                
                // Main heart rate visualization
                ECGHeartbeatView(bpm: $connectivityManager.bpm)
                    .padding()
                
                // Heart rate display
                Text("\(Int(connectivityManager.bpm)) BPM")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("bpm_display")
                
                Spacer()
                
                // Message statistics (when connected)
                if connectivityManager.connectionState == .connected {
                    HStack {
                        if let lastTime = connectivityManager.lastMessageTime {
                            Text("Last update: \(timeAgoString(from: lastTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(connectivityManager.messageCount) messages sent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Bottom action buttons
                HStack(spacing: 30) {
                    // Connect button
                    Button(action: {
                        showingConnectionSheet = true
                    }) {
                        VStack {
                            Image(systemName: "network")
                                .font(.system(size: 24))
                            Text("Connect")
                                .font(.caption)
                        }
                    }
                    .accessibilityLabel("Connect to VRChat")
                    .accessibilityIdentifier("connect_button")
                    .sheet(isPresented: $showingConnectionSheet) {
                        ConnectionView()
                    }
                    
                    // Start/Stop button for watch workout control
                    Button(action: {
                        if connectivityManager.watchConnected {
                            if connectivityManager.watchWorkoutActive {
                                // If workout is active, stop it
                                connectivityManager.stopWorkout()
                            } else {
                                // If workout is not active, start it
                                connectivityManager.startWorkout()
                            }
                        } else {
                            // Alert user that watch is not connected
                            // In a real app, you'd show an alert here
                            print("Watch not connected, cannot control workout")
                        }
                    }) {
                        VStack {
                            Image(systemName: connectivityManager.watchWorkoutActive ? "stop.circle" : "play.circle")
                                .font(.system(size: 24))
                            Text(connectivityManager.watchWorkoutActive ? "Stop" : "Start")
                                .font(.caption)
                        }
                        .foregroundColor(connectivityManager.watchConnected ? .primary : .secondary)
                    }
                    .accessibilityIdentifier("start_stop_button")
                    
                    // Settings button
                    Button(action: {
                        showingSettings = true
                    }) {
                        VStack {
                            Image(systemName: "gear")
                                .font(.system(size: 24))
                            Text("Settings")
                                .font(.caption)
                        }
                    }
                    .accessibilityIdentifier("settings_button")
                    .sheet(isPresented: $showingSettings) {
                        SettingsView()
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Heart Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Toggle test mode (for development)
                        toggleTestMode()
                    }) {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .accessibilityIdentifier("test_mode_button")
                }
            }
        }
    }
    
    private func toggleTestMode() {
        // For testing: simulate heart rate changes
        if connectivityManager.connectionState == .connected {
            // Stop simulated data
            connectivityManager.disconnect()
        } else {
            // Start simulated data
            connectivityManager.watchConnected = true
            
            // Simulate changing heart rate
            let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                connectivityManager.bpm = Double.random(in: 60...120)
                connectivityManager.lastMessageTime = Date()
                connectivityManager.messageCount += 1
            }
            
            // Keep reference to timer somewhere (not implemented here for simplicity)
            _ = timer
        }
    }
    
    // Format time ago string from date
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}

// Connection status bar component
struct ConnectionStatusBar: View {
    var watchConnected: Bool
    var oscConnected: Bool
    var connectionState: ConnectivityManager.ConnectionState
    var watchWorkoutActive: Bool = false // Add this parameter with a default value
    
    var body: some View {
        HStack {
            // Watch connection status with workout indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(watchConnected ? (watchWorkoutActive ? Color.green : Color.orange) : Color.red)
                    .frame(width: 8, height: 8)
                Text("Watch")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if watchConnected && watchWorkoutActive {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.pink)
                }
            }
            
            Divider()
                .frame(height: 15)
                .padding(.horizontal, 8)
            
            // OSC connection status
            HStack(spacing: 5) {
                Circle()
                    .fill(oscConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("VRChat")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connection state text
            Text(connectionStateText)
                .font(.caption)
                .foregroundColor(connectionStateColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // Helper computed properties
    var connectionStateText: String {
        switch connectionState {
        case .disconnected:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error:
            return "Error"
        }
    }
    
    var connectionStateColor: Color {
        switch connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// Settings view placeholder
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("General")) {
                    NavigationLink(destination: Text("Display settings go here")) {
                        Label("Display", systemImage: "display")
                    }
                    
                    NavigationLink(destination: Text("About this app")) {
                        Label("About", systemImage: "info.circle")
                    }
                }
                
                Section(header: Text("Advanced")) {
                    NavigationLink(destination: Text("Background mode settings")) {
                        Label("Background Mode", systemImage: "iphone.and.arrow.forward")
                    }
                    
                    NavigationLink(destination: Text("Workout configuration")) {
                        Label("Workout Settings", systemImage: "heart.circle")
                    }
                    
                    NavigationLink(destination: Text("OSC protocol settings")) {
                        Label("OSC Configuration", systemImage: "network")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// Development preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
