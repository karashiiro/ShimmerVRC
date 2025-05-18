//
//  ConnectionStatusBarTests.swift
//  ShimmerVRCTests
//
//  Created by karashiiro on 5/11/25.
//

import Testing
import SwiftUI
@testable import ShimmerVRC

@MainActor
struct ConnectionStatusBarTests {
    @Test func testConnectionIndicators() throws {
        // Test different combinations of connection states
        let combinations: [(watchConnected: Bool, oscConnected: Bool)] = [
            (false, false),
            (true, false),
            (false, true),
            (true, true)
        ]
        
        for combo in combinations {
            let view = ConnectionStatusBar(
                watchConnected: combo.watchConnected,
                oscConnected: combo.oscConnected,
                connectionState: .disconnected
            )
            
            // This test is primarily to ensure the view doesn't crash with different combinations
            #expect(view.watchConnected == combo.watchConnected)
            #expect(view.oscConnected == combo.oscConnected)
        }
    }
}
