//
//  ECGHeartbeatView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ECGHeartbeatView: View {
    @Binding var bpm: Double?
    @State private var phase: CGFloat = 0
    @State private var timer: Timer?
    
    // Default animation speed when no heart rate is available
    private let defaultBpm: Double = 60.0
    
    var body: some View {
        VStack(spacing: 30) {
            // Heart animation
            HeartBeatView(bpm: $bpm)
            
            // ECG Waveform
            ECGWaveform(phase: phase)
                .stroke(bpm != nil ? Color.red : Color.gray.opacity(0.5), lineWidth: 2)
                .frame(height: 80)
                .clipped() // Keep waveform within bounds
                .accessibilityIdentifier("ecg_waveform")
        }
        .onAppear {
            animateWaveform()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func animateWaveform() {
        // Stop any existing animation
        timer?.invalidate()
        
        // Create timer for continuous animation
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            // Calculate animation speed based on BPM or use default
            // Higher BPM = faster waveform scrolling
            let activeBpm = bpm ?? defaultBpm
            let speed = 0.02 * (activeBpm / 60.0)
            
            // Update phase to make waveform scroll
            withAnimation(.linear(duration: 1/60)) {
                phase += speed
                
                // Keep phase in reasonable range
                if phase > .pi * 2 {
                    phase -= .pi * 2
                }
            }
        }
    }
}
