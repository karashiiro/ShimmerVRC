//
//  OSCConnectionIndicator.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/17/25.
//

import SwiftUI

struct OSCConnectionIndicator: View {
    var oscConnected: Bool
    var connectionState: ConnectivityManager.ConnectionState
    @Binding var animateConnecting: Bool
    
    var body: some View {
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
    }
}
