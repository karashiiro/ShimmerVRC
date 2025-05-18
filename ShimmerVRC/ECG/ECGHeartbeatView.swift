//
//  ECGHeartbeatView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ECGHeartbeatView: View {
    @Binding var bpm: Double?
    @State private var phase = 0.0
    @State private var timer: Timer?
    
    // Default animation speed when no heart rate is available
    private let defaultBpm: Double = 60.0
    
    var body: some View {
        VStack(spacing: 30) {
            // Heart animation
            HeartBeatView(bpm: $bpm)
            
            // ECG Waveform - edge to edge
            ECGWaveform(phase: CGFloat(phase))
                .stroke(
                    bpm != nil ? 
                        Color.red.opacity(0.9) : 
                        Color.gray.opacity(0.5), 
                    lineWidth: 2.0
                )
                .shadow(color: 
                    bpm != nil ? 
                        Color.red.opacity(0.3) : 
                        Color.clear, 
                    radius: 1, x: 0, y: 0
                )
                .frame(height: 80)
                .accessibilityIdentifier("ecg_waveform")
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        // Stop any existing timer
        stopAnimation()
        
        // Create a new timer that updates the phase
        // The speed is proportional to the heart rate
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Calculate appropriate speed from heart rate
            let heartRate = bpm ?? defaultBpm
            
            // Adjust speed based on heart rate (higher BPM = faster movement)
            let speed = 0.005 * (heartRate / 60.0)
            phase += speed
            
            // Keep phase in the 0-1 range (wrapping)
            if phase >= 1.0 {
                phase -= 1.0
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

// Preview for SwiftUI canvas
struct ECGHeartbeatView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var testBpm: Double? = 72.0
        
        var body: some View {
            VStack {
                ECGHeartbeatView(bpm: $testBpm)
                
                Button("Toggle BPM") {
                    testBpm = testBpm == nil ? 72.0 : nil
                }
                
                Slider(value: Binding(
                    get: { testBpm ?? 60.0 },
                    set: { testBpm = $0 }
                ), in: 40...180)
                .disabled(testBpm == nil)
                .padding()
                
                Text("BPM: \(testBpm != nil ? "\(Int(testBpm!))" : "None")")
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
