//
//  ConnectionStatusBar.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/13/25.
//

import SwiftUI

// Enhanced Connection status bar component
struct ConnectionStatusBar: View {
    var watchConnected: Bool
    var oscConnected: Bool
    var connectionState: ConnectivityManager.ConnectionState
    var watchWorkoutActive: Bool = false
    @State private var isReconnecting = false
    @State private var reconnectAttempt = 0
    @State private var maxReconnectAttempts = 5
    @State private var errorMessage: String? = nil
    @State private var isShowingError = false
    @State private var animateConnecting = false
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Watch connection status with workout indicator
                HStack(spacing: 5) {
                    // Animated indicator for watch connection
                    ZStack {
                        Circle()
                            .fill(watchConnected ? (watchWorkoutActive ? Color.green : Color.orange) : Color.red)
                            .frame(width: 10, height: 10)
                        
                        // Pulsing effect when active
                        if watchWorkoutActive {
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                                .frame(width: 14, height: 14)
                                .scaleEffect(animateConnecting ? 1.5 : 1.0)
                                .opacity(animateConnecting ? 0.0 : 1.0)
                        }
                    }
                    
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
                
                // OSC connection status with animation
                HStack(spacing: 5) {
                    ZStack {
                        // Status indicator
                        Circle()
                            .fill(oscConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        // Animated ring for connecting state
                        if connectionState == .connecting {
                            Circle()
                                .stroke(Color.orange.opacity(0.7), lineWidth: 2)
                                .frame(width: 14, height: 14)
                                .scaleEffect(animateConnecting ? 1.5 : 1.0)
                                .opacity(animateConnecting ? 0.0 : 1.0)
                        }
                    }
                    
                    Text("VRChat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Connection state text with reconnection info
                HStack(spacing: 4) {
                    if connectionState == .connecting || connectionState == .error {
                        Image(systemName: connectionState == .connecting ? "arrow.clockwise" : "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundColor(connectionStateColor)
                            .rotationEffect(
                                connectionState == .connecting && animateConnecting ? 
                                    .degrees(360) : .degrees(0)
                            )
                    }
                    
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
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(connectionStateColor.opacity(0.1))
                )
            }
            
            // Error message (shown only when there's an error)
            if let error = errorMessage, connectionState == .error, isShowingError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.9))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .accessibilityIdentifier("error_message")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .animation(.spring(response: 0.3), value: watchConnected)
        .animation(.spring(response: 0.3), value: oscConnected)
        .animation(.spring(response: 0.3), value: connectionState)
        .animation(.spring(response: 0.3), value: isShowingError)
        .animation(.spring(response: 0.3), value: isReconnecting)
        .onAppear {
            setupNotificationObservers()
            startConnectingAnimation()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: connectionState) {
            // Show error messages when entering error state
            if connectionState == .error {
                withAnimation {
                    isShowingError = true
                }
            } else {
                withAnimation {
                    isShowingError = false
                }
            }
            
            // Start/stop connecting animation
            if connectionState == .connecting {
                startConnectingAnimation()
            }
        }
    }
    
    // Start connecting pulse animation
    private func startConnectingAnimation() {
        guard connectionState == .connecting else { return }
        
        // Continuously animate the connecting indicator
        withAnimation(
            Animation.easeInOut(duration: 1.0)
                .repeatForever(autoreverses: false)
        ) {
            animateConnecting = true
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
                withAnimation {
                    self.isReconnecting = true
                    self.reconnectAttempt = attempt
                    self.maxReconnectAttempts = maxAttempts
                }
            }
        }
        
        // Observe connection success
        NotificationCenter.default.addObserver(
            forName: .heartRateConnected,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                self.isReconnecting = false
                self.errorMessage = nil
                self.isShowingError = false
            }
        }
        
        // Observe disconnection
        NotificationCenter.default.addObserver(
            forName: .heartRateDisconnected,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                self.isReconnecting = false
                self.errorMessage = nil
                self.isShowingError = false
            }
        }
        
        // Observe connection errors
        NotificationCenter.default.addObserver(
            forName: .heartRateConnectionError,
            object: nil,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?["error"] as? String {
                withAnimation {
                    self.errorMessage = error
                    self.isShowingError = true
                }
            }
        }
    }
}

// Preview
struct ConnectionStatusBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ConnectionStatusBar(
                watchConnected: true,
                oscConnected: true,
                connectionState: .connected,
                watchWorkoutActive: true
            )
            .previewDisplayName("Connected")
            
            ConnectionStatusBar(
                watchConnected: true,
                oscConnected: false,
                connectionState: .connecting,
                watchWorkoutActive: true
            )
            .previewDisplayName("Connecting")
            
            ConnectionStatusBar(
                watchConnected: true,
                oscConnected: false,
                connectionState: .error,
                watchWorkoutActive: false
            )
            .previewDisplayName("Error")
            
            ConnectionStatusBar(
                watchConnected: false,
                oscConnected: false,
                connectionState: .disconnected,
                watchWorkoutActive: false
            )
            .previewDisplayName("Disconnected")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
