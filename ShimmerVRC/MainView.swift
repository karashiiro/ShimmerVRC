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
    @State private var showConnectionSuccess = false
    @State private var showConnectionError = false
    
    var showTestButton = false
    
    // For haptic feedback
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Status bar for connections
                    ConnectionStatusBar(
                        watchConnected: connectivityManager.watchConnected,
                        oscConnected: connectivityManager.oscConnected,
                        connectionState: connectivityManager.connectionState,
                        watchWorkoutActive: connectivityManager.watchWorkoutActive
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // Heart rate container with animations
                    VStack {
                        // Main heart rate visualization
                        ECGHeartbeatView(bpm: $connectivityManager.bpm)
                            .padding(.vertical, 10)
                        
                        // Heart rate display with animations
                        HStack(alignment: .lastTextBaseline) {
                            Text(connectivityManager.bpm != nil ? "\(Int(connectivityManager.bpm!))" : "--")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(heartRateColor)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: connectivityManager.bpm)
                            
                            Text("BPM")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(.leading, -4)
                        }
                        .padding(.top, -20)
                        .padding(.bottom, 16)
                        .accessibilityIdentifier("bpm_display")
                    }
                    .frame(maxHeight: .infinity)
                    
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
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Bottom action buttons
                    HStack(spacing: 0) {
                        // Connect button
                        ActionButton(
                            title: "Connect",
                            icon: "network",
                            active: connectivityManager.connectionState == .connected,
                            action: {
                                showingConnectionSheet = true
                            }
                        )
                        .accessibilityLabel("Connect to VRChat")
                        .accessibilityIdentifier("connect_button")
                        .sheet(isPresented: $showingConnectionSheet) {
                            ConnectionView()
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        // Start/Stop button for watch workout control
                        ActionButton(
                            title: connectivityManager.watchWorkoutActive ? "Stop" : "Start",
                            icon: connectivityManager.watchWorkoutActive ? "stop.circle" : "play.circle",
                            active: connectivityManager.watchWorkoutActive,
                            enabled: connectivityManager.watchConnected,
                            action: {
                                if connectivityManager.watchConnected {
                                    if connectivityManager.watchWorkoutActive {
                                        // If workout is active, stop it
                                        connectivityManager.stopWorkout()
                                    } else {
                                        // If workout is not active, start it
                                        connectivityManager.startWorkout()
                                    }
                                    // Provide haptic feedback
                                    feedbackGenerator.prepare()
                                    feedbackGenerator.notificationOccurred(.success)
                                } else {
                                    // Provide error feedback
                                    feedbackGenerator.prepare()
                                    feedbackGenerator.notificationOccurred(.error)
                                }
                            }
                        )
                        .accessibilityIdentifier("start_stop_button")
                        
                        Divider()
                            .frame(height: 30)
                        
                        // Settings button
                        ActionButton(
                            title: "Settings",
                            icon: "gear",
                            action: {
                                showingSettings = true
                            }
                        )
                        .accessibilityIdentifier("settings_button")
                        .sheet(isPresented: $showingSettings) {
                            SettingsView()
                        }
                    }
                    .padding(.bottom, 8) // Add padding to prevent clipping at bottom of screen
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -3)
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                
                // Connection success overlay
                if showConnectionSuccess {
                    StatusOverlay(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        message: "Connected successfully"
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
                
                // Connection error overlay
                if showConnectionError {
                    StatusOverlay(
                        icon: "exclamationmark.triangle.fill",
                        color: .red,
                        message: connectivityManager.lastError ?? "Connection failed"
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("Heart Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showTestButton {
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
            .onAppear {
                // Initialize the feedback generator
                feedbackGenerator.prepare()
                
                // Set up notification observers
                setupNotificationObservers()
            }
            .onDisappear {
                // Clean up notification observers
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private var heartRateColor: Color {
        guard let bpm = connectivityManager.bpm else {
            return .secondary
        }
        
        if bpm < 60 {
            return .blue
        } else if bpm < 100 {
            return .green
        } else if bpm < 140 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func setupNotificationObservers() {
        // Observe connection success
        NotificationCenter.default.addObserver(
            forName: .heartRateConnected,
            object: nil,
            queue: .main
        ) { _ in
            // Show success overlay
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showConnectionSuccess = true
            }
            
            // Provide success haptic feedback
            self.feedbackGenerator.notificationOccurred(.success)
            
            // Hide after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.showConnectionSuccess = false
                }
            }
        }
        
        // Observe connection errors
        NotificationCenter.default.addObserver(
            forName: .heartRateConnectionError,
            object: nil,
            queue: .main
        ) { _ in
            // Show error overlay
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showConnectionError = true
            }
            
            // Provide error haptic feedback
            self.feedbackGenerator.notificationOccurred(.error)
            
            // Hide after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    self.showConnectionError = false
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

// Development preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(showTestButton: true)
    }
}
