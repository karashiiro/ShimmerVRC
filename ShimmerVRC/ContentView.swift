//
//  ContentView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var bpm: Double = 60.0
    
    var body: some View {
        VStack {
            ECGHeartbeatView(bpm: $bpm)
            
            // BPM Display
            Text("\(Int(bpm)) BPM")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // BPM slider for testing
            VStack(spacing: 10) {
                Text("Adjust Heart Rate")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 15) {
                    // Min BPM label
                    Text("40")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // The slider itself
                    Slider(
                        value: $bpm,
                        in: 40...180,
                        step: 1
                    )
                    .accentColor(.red)
                    
                    // Max BPM label
                    Text("180")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 30)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
