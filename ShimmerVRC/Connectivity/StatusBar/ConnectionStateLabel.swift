//
//  ConnectionStateLabel.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/17/25.
//

import SwiftUI

struct ConnectionStateLabel: View {
    var oscConnected: Bool
    var connectionState: ConnectivityManager.ConnectionState
    @Binding var animateConnecting: Bool
    @Binding var isReconnecting: Bool
    @Binding var reconnectAttempt: Int
    @Binding var maxReconnectAttempts: Int
    
    var body: some View {
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
}
