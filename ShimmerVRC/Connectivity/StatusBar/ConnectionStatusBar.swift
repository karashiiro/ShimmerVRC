//
//  ConnectionStatusBar.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/13/25.
//

import SwiftUI

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
                    WatchConnectionIndicator(
                        watchConnected: watchConnected,
                        watchWorkoutActive: watchWorkoutActive,
                        animateConnecting: $animateConnecting)
                    
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
                    OSCConnectionIndicator(
                        oscConnected: oscConnected,
                        connectionState: connectionState,
                        animateConnecting: $animateConnecting)
                    
                    Text("VRChat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Connection state text with reconnection info
                ConnectionStateLabel(
                    oscConnected: oscConnected,
                    connectionState: connectionState,
                    animateConnecting: $animateConnecting,
                    isReconnecting: $isReconnecting,
                    reconnectAttempt: $reconnectAttempt,
                    maxReconnectAttempts: $maxReconnectAttempts)
            }
            
            if let error = errorMessage, connectionState == .error, isShowingError {
                ConnectionErrorLabel(errorMessage: error)
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
