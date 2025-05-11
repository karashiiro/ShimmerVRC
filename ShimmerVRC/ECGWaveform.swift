//
//  ECGWaveform.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ECGWaveform: Shape {
    var phase: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        
        // Create a simple repeating pattern
        for x in stride(from: 0, through: rect.width, by: 1) {
            let t = CGFloat(x) / rect.width
            let y = midY + sin(t * 4 * .pi - phase) * 20
            
            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
