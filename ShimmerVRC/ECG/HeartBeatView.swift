//
//  HeartBeatView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct HeartBeatView: View {
    @Binding var bpm: Double?
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var timer: Timer?
    
    // Default animation when no heart rate is available
    private let defaultBpm: Double = 60.0
    
    var body: some View {
        ZStack {
            // Pulsing background glow (only when heart rate is available)
            if bpm != nil {
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.red.opacity(0.3))
                    .scaleEffect(scale * 1.2)
                    .opacity(opacity * 0.5)
            }
            
            // Main heart
            Image(systemName: "heart.fill")
                .font(.system(size: 100))
                .foregroundStyle(bpm != nil ? heartGradient : inactiveGradient)
                .scaleEffect(scale)
                .shadow(color: 
                    bpm != nil ? 
                        Color.red.opacity(0.4) : 
                        Color.clear,
                    radius: 5
                )
                .accessibilityIdentifier("ecg_heartbeat")
        }
        .onAppear {
            startHeartbeat()
        }
        .onChange(of: bpm) {
            restartHeartbeat()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // Computed properties for gradients
    private var heartGradient: LinearGradient {
        let heartRate = bpm ?? defaultBpm
        
        if heartRate < 60 {
            // Slow heart rate - cooler colors
            return LinearGradient(
                colors: [Color.blue, Color.red.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if heartRate > 100 {
            // Elevated heart rate - more intense colors
            return LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Normal heart rate
            return LinearGradient(
                colors: [Color.red.opacity(0.9), Color.red],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // Gradient for inactive state
    private var inactiveGradient: LinearGradient {
        return LinearGradient(
            colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func startHeartbeat() {
        // Start with initial beat
        animateSingleBeat()
        
        // Set up timer
        restartHeartbeat()
    }
    
    private func restartHeartbeat() {
        // Stop any existing timer
        timer?.invalidate()
        
        // Calculate interval between beats using actual BPM or default
        let activeBpm = bpm ?? defaultBpm
        let interval = 60.0 / activeBpm
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            animateSingleBeat()
        }
    }
    
    private func animateSingleBeat() {
        // Quick expansion and fade-in of glow
        withAnimation(.easeOut(duration: 0.15)) {
            scale = 1.25
            opacity = 1.0
        }
        
        // Quick contraction with subtle bounce effect
        withAnimation(
            .interactiveSpring(
                response: 0.3,
                dampingFraction: 0.7,
                blendDuration: 0.3
            ).delay(0.15)
        ) {
            scale = 1.0
        }
        
        // Slower fade-out of glow
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            opacity = 0.0
        }
    }
}

// Preview
struct HeartBeatView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var testBpm: Double? = 72.0
        
        var body: some View {
            VStack {
                HeartBeatView(bpm: $testBpm)
                
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
