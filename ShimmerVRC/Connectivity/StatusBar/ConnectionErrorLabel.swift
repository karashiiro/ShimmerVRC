//
//  ConnectionErrorLabel.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/17/25.
//

import SwiftUI

struct ConnectionErrorLabel: View {
    var errorMessage: String
    
    var body: some View {
        Text(errorMessage)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.9))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .accessibilityIdentifier("error_message")
    }
}
