//
//  ECGWaveform.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ECGWaveform: Shape {
    // The phase variable controls the horizontal scrolling of the waveform
    var phase: CGFloat
    
    // Make the shape animatable
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = rect.midY
        
        // Fixed values for amplitudes to ensure consistency
        let baselineY = midY
        let pWaveHeight = height * 0.08
        let qWaveDepth = height * 0.12
        let rWavePeak = height * 0.4
        let sWaveDepth = height * 0.2
        let tWaveHeight = height * 0.15
        
        // Set starting point
        path.move(to: CGPoint(x: 0, y: baselineY))
        
        // Define the period of one complete heartbeat (PQRST) as a proportion of the width
        let beatWidth = width / 5 // Show 5 complete beats across the view width
        
        // Calculate the offset based on phase (0-1 range)
        let offset = phase * beatWidth
        
        // Draw multiple beats to fill the width with a smooth continuous pattern
        for beat in -1...5 {
            let beatStart = CGFloat(beat) * beatWidth - offset
            
            // Only draw visible beats
            if beatStart + beatWidth < 0 || beatStart > width {
                continue
            }
            
            // P-Wave (small upward curve)
            let pStart = beatStart
            let pPeak = beatStart + beatWidth * 0.05
            let pEnd = beatStart + beatWidth * 0.1
            
            if pStart >= 0 {
                path.addLine(to: CGPoint(x: pStart, y: baselineY))
            }
            
            // Draw P-Wave with quadratic curves for smoother appearance
            if pStart < width && pEnd > 0 {
                let visiblePStart = max(pStart, 0)
                
                if visiblePStart > pStart {
                    // If we're starting mid-wave, calculate the appropriate y-value
                    let progress = (visiblePStart - pStart) / (pPeak - pStart)
                    let y = baselineY - pWaveHeight * sin(progress * .pi/2)
                    path.move(to: CGPoint(x: visiblePStart, y: y))
                }
                
                // P-wave ascending
                for x in stride(from: max(pStart, 0), to: min(pPeak, width), by: 1) {
                    let progress = (x - pStart) / (pPeak - pStart)
                    let y = baselineY - pWaveHeight * sin(progress * .pi/2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // P-wave descending
                for x in stride(from: max(pPeak, 0), to: min(pEnd, width), by: 1) {
                    let progress = (x - pPeak) / (pEnd - pPeak)
                    let y = baselineY - pWaveHeight * cos(progress * .pi/2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // PQ Segment (flat)
            let pqEnd = beatStart + beatWidth * 0.2
            if pEnd < width && pqEnd > 0 {
                path.addLine(to: CGPoint(x: min(pqEnd, width), y: baselineY))
            }
            
            // QRS Complex
            let qStart = pqEnd
            let qEnd = qStart + beatWidth * 0.03
            let rPeak = qEnd + beatWidth * 0.03
            let sEnd = rPeak + beatWidth * 0.03
            
            // Q-Wave (small dip)
            if qStart < width && qEnd > 0 {
                for x in stride(from: max(qStart, 0), to: min(qEnd, width), by: 1) {
                    let progress = (x - qStart) / (qEnd - qStart)
                    let y = baselineY + qWaveDepth * sin(progress * .pi/2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // R-Wave (sharp upward spike)
            if qEnd < width && rPeak > 0 {
                for x in stride(from: max(qEnd, 0), to: min(rPeak, width), by: 1) {
                    let progress = (x - qEnd) / (rPeak - qEnd)
                    let y = baselineY + qWaveDepth - (qWaveDepth + rWavePeak) * progress
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // S-Wave (downward then return to baseline)
            if rPeak < width && sEnd > 0 {
                for x in stride(from: max(rPeak, 0), to: min(sEnd, width), by: 1) {
                    let progress = (x - rPeak) / (sEnd - rPeak)
                    let y = baselineY - rWavePeak + (rWavePeak + sWaveDepth) * sin(progress * .pi/2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // ST Segment (flat or slight elevation)
            let stEnd = sEnd + beatWidth * 0.1
            if sEnd < width && stEnd > 0 {
                path.addLine(to: CGPoint(x: min(stEnd, width), y: baselineY - height * 0.02))
            }
            
            // T-Wave (rounded upward deflection)
            let tStart = stEnd
            let tPeak = tStart + beatWidth * 0.1
            let tEnd = tStart + beatWidth * 0.2
            
            if tStart < width && tEnd > 0 {
                // T-wave ascending
                for x in stride(from: max(tStart, 0), to: min(tPeak, width), by: 1) {
                    let progress = (x - tStart) / (tPeak - tStart)
                    let y = baselineY - height * 0.02 - tWaveHeight * sin(progress * .pi/2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // T-wave descending
                for x in stride(from: max(tPeak, 0), to: min(tEnd, width), by: 1) {
                    let progress = (x - tPeak) / (tEnd - tPeak)
                    let y = baselineY - height * 0.02 - tWaveHeight * cos(progress * .pi/2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // TP Segment (flat until next beat)
            if tEnd < width {
                path.addLine(to: CGPoint(x: min(beatStart + beatWidth, width), y: baselineY))
            }
        }
        
        return path
    }
}

// Preview
struct ECGWaveform_Previews: PreviewProvider {
    static var previews: some View {
        ECGWaveform(phase: 0)
            .stroke(Color.red, lineWidth: 2)
            .frame(height: 100)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
