//
//  ECGTestHarness.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI

struct ECGTestHarness: View {
    @State private var testBPM: Double? = 70
    @State private var bpmInput: String = "70"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("ECG Test Harness")
                    .font(.title)
                    .padding(.top)
                
                // Test controls
                VStack(spacing: 10) {
                    Text("Set Heart Rate")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        TextField("BPM", text: $bpmInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                            .accessibilityIdentifier("test_bpm_input")
                        
                        // Clear button for UI tests
                        Button("Clear") {
                            bpmInput = ""
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("clear_bpm_button")
                        
                        Button("Set BPM") {
                            if let bpm = Double(bpmInput) {
                                if bpm > 300 {
                                    testBPM = 300
                                    bpmInput = "300" // Update input field
                                }
                                else if bpm < 0 {
                                    testBPM = 0
                                    bpmInput = "0" // Update input field
                                }
                                else {
                                    testBPM = bpm
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("set_bpm_button")
                    }
                    
                    Text("Current BPM: \(Int(testBPM == nil ? 0 : testBPM!))")
                        .font(.headline)
                        .accessibilityIdentifier("current_bpm_display")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Divider()
                
                // ECG view under test
                ECGHeartbeatView(bpm: $testBPM)
                    .padding()
                
                // Debug info
                VStack(spacing: 5) {
                    Text("Debug Info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Test harness is active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("BPM Input: '\(bpmInput)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Test BPM: \(testBPM)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Spacer()
            }
            .padding()
        }
    }
}

// Preview for development
#Preview {
    ECGTestHarness()
}
