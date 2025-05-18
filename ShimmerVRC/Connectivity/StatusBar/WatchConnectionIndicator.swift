//
//  WatchConnectionIndicator.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/17/25.
//

import SwiftUI

struct WatchConnectionIndicator: View {
    var watchConnected: Bool
    var watchWorkoutActive: Bool
    @Binding var animateConnecting: Bool
    
    var body: some View {
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
    }
}
