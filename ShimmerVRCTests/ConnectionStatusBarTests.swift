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
    
    @Test func testDisconnectedState() throws {
        // Create the status bar in disconnected state
        let view = ConnectionStatusBar(
            watchConnected: false,
            oscConnected: false,
            connectionState: .disconnected
        )
        
        // Assert text and colors are correct for disconnected state
        let statusText = extractStatusText(from: view)
        let statusColor = extractStatusColor(from: view)
        
        #expect(statusText == "Not Connected")
        #expect(statusColor == .gray)
    }
    
    @Test func testConnectingState() throws {
        // Create the status bar in connecting state
        let view = ConnectionStatusBar(
            watchConnected: true,
            oscConnected: false,
            connectionState: .connecting
        )
        
        // Assert text and colors are correct for connecting state
        let statusText = extractStatusText(from: view)
        let statusColor = extractStatusColor(from: view)
        
        #expect(statusText == "Connecting...")
        #expect(statusColor == .orange)
    }
    
    @Test func testConnectedState() throws {
        // Create the status bar in connected state
        let view = ConnectionStatusBar(
            watchConnected: true,
            oscConnected: true,
            connectionState: .connected
        )
        
        // Assert text and colors are correct for connected state
        let statusText = extractStatusText(from: view)
        let statusColor = extractStatusColor(from: view)
        
        #expect(statusText == "Connected")
        #expect(statusColor == .green)
    }
    
    @Test func testErrorState() throws {
        // Create the status bar in error state
        let view = ConnectionStatusBar(
            watchConnected: true,
            oscConnected: false,
            connectionState: .error
        )
        
        // Assert text and colors are correct for error state
        let statusText = extractStatusText(from: view)
        let statusColor = extractStatusColor(from: view)
        
        #expect(statusText == "Error")
        #expect(statusColor == .red)
    }
    
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
            // A more comprehensive test would examine the actual rendered circles, but that's difficult
            // to do in unit tests without UI testing
            
            #expect(view.watchConnected == combo.watchConnected)
            #expect(view.oscConnected == combo.oscConnected)
        }
    }
    
    // Helper functions for testing SwiftUI views
    private func extractStatusText(from view: ConnectionStatusBar) -> String {
        return view.connectionStateText
    }
    
    private func extractStatusColor(from view: ConnectionStatusBar) -> Color {
        return view.connectionStateColor
    }
}
