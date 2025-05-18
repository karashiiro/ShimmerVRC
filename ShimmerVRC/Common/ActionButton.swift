//
//  ActionButton.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/17/25.
//

import SwiftUI

struct ActionButton: View {
    var title: String
    var icon: String
    var active: Bool = false
    var enabled: Bool = true
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        active ? Color.accentColor :
                            (enabled ? Color.primary : Color.secondary)
                    )
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(
                        active ? Color.accentColor :
                            (enabled ? Color.primary : Color.secondary)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
    }
}
