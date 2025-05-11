//
//  HeartBeatView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct HeartBeatView: View {
    @Binding var bpm: Double
    @State private var scale: CGFloat = 1.0
    @State private var timer: Timer?
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 100))
            .foregroundColor(.red)
            .scaleEffect(scale)
            .accessibilityIdentifier("ecg_heartbeat")
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
    
    private func startHeartbeat() {
        // Start with initial beat
        animateSingleBeat()
        
        // Set up timer
        restartHeartbeat()
    }
    
    private func restartHeartbeat() {
        // Stop any existing timer
        timer?.invalidate()
        
        // Calculate interval between beats
        let interval = 60.0 / bpm
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            animateSingleBeat()
        }
    }
    
    private func animateSingleBeat() {
        // Quick expansion
        withAnimation(.easeOut(duration: 0.1)) {
            scale = 1.2
        }
        
        // Quick contraction
        withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
            scale = 1.0
        }
    }
}
