//
//  MainView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var lifecycleObserver: AppLifecycleObserver
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
                Text(connectivityManager.bpm != nil ? "\(Int(connectivityManager.bpm!)) BPM" : "-- BPM")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(connectivityManager.bpm != nil ? .primary : .secondary)
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
        // For testing: enable/disable test mode
        
        // If we're in a unit/UI test, allow test mode
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            if connectivityManager.connectionState == .connected {
                // Stop simulated data
                connectivityManager.disconnect()
            } else {
                // Start simulated data for tests only
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
        } else {
            // In the real app, we don't want mock data - toggle visual styles only
            if connectivityManager.bpm != nil {
                // Clear heart rate data
                connectivityManager.bpm = nil
            } else {
                // Show a sample heart rate (but don't simulate continuous updates)
                connectivityManager.bpm = 75.0
            }
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
    @State private var isReconnecting = false
    @State private var reconnectAttempt = 0
    @State private var maxReconnectAttempts = 5
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
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
                
                // Connection state text with reconnection info
                HStack(spacing: 4) {
                    Text(connectionStateText)
                        .font(.caption)
                        .foregroundColor(connectionStateColor)
                    
                    if isReconnecting {
                        Text("(\(reconnectAttempt)/\(maxReconnectAttempts))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .accessibilityIdentifier("reconnect_indicator")
                    }
                }
            }
            
            // Error message (shown only when there's an error)
            if let error = errorMessage, connectionState == .error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    .lineLimit(2)
                    .accessibilityIdentifier("error_message")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .animation(.easeInOut(duration: 0.3), value: isReconnecting)
        .onAppear {
            setupNotificationObservers()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // Helper computed properties
    var connectionStateText: String {
        switch connectionState {
        case .disconnected:
            return "Not Connected"
        case .connecting:
            return isReconnecting ? "Reconnecting..." : "Connecting..."
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
    
    // Set up notification observers for connection events
    private func setupNotificationObservers() {
        // Observe reconnection attempts
        NotificationCenter.default.addObserver(
            forName: .heartRateReconnecting,
            object: nil,
            queue: .main
        ) { notification in
            if let attempt = notification.userInfo?["attempt"] as? Int,
               let maxAttempts = notification.userInfo?["maxAttempts"] as? Int {
                self.isReconnecting = true
                self.reconnectAttempt = attempt
                self.maxReconnectAttempts = maxAttempts
            }
        }
        
        // Observe connection success
        NotificationCenter.default.addObserver(
            forName: .heartRateConnected,
            object: nil,
            queue: .main
        ) { _ in
            self.isReconnecting = false
            self.errorMessage = nil
        }
        
        // Observe disconnection
        NotificationCenter.default.addObserver(
            forName: .heartRateDisconnected,
            object: nil,
            queue: .main
        ) { _ in
            self.isReconnecting = false
            self.errorMessage = nil
        }
        
        // Observe connection errors
        NotificationCenter.default.addObserver(
            forName: .heartRateConnectionError,
            object: nil,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?["error"] as? String {
                self.errorMessage = error
            }
        }
    }
}

// Development preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
