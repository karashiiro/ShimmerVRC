//
//  ConnectionView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import SwiftUI
import Combine

struct ConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connectivityManager = ConnectivityManager.shared
    @StateObject private var hostDiscovery = HostDiscovery()
    @State private var host = ""
    @State private var port = "9000"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Discovered Devices").accessibility(identifier: "discovered_devices_header")) {
                    if hostDiscovery.isSearching && hostDiscovery.hosts.isEmpty {
                        HStack {
                            Text("Searching for devices...")
                                .accessibility(identifier: "searching_text")
                            Spacer()
                            ProgressView()
                        }
                        .accessibility(identifier: "searching_devices_row")
                    } else if hostDiscovery.hosts.isEmpty {
                        Text("No devices found")
                            .foregroundColor(.secondary)
                            .accessibility(identifier: "no_devices_text")
                    } else {
                        ForEach(hostDiscovery.hosts, id: \.self) { h in
                            HStack {
                                Text(h)
                                    .accessibility(identifier: "device_\(h.replacingOccurrences(of: ".", with: "_"))")
                                // TODO: Fix the data model to use actual hostnames here so this isn't broken
                                    .onTapGesture { host = h }
                                Spacer()
                                if host == h { 
                                    Image(systemName: "checkmark")
                                        .accessibility(identifier: "checkmark_\(h.replacingOccurrences(of: ".", with: "_"))")
                                }
                            }
                            .accessibility(identifier: "device_row_\(h.replacingOccurrences(of: ".", with: "_"))")
                        }
                    }
                    
                    Button(action: { hostDiscovery.startBrowsing() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .accessibility(identifier: "refresh_button")
                }
                
                Section(header: Text("Connection Settings").accessibility(identifier: "connection_settings_header")) {
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("host_field")
                        .accessibility(identifier: "host_field")
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                        .accessibility(identifier: "port_field")
                    
                    Toggle("Remember settings", isOn: .constant(true))
                        .accessibility(identifier: "remember_settings_toggle")
                }
                
                // Connection status info
                if connectivityManager.connectionState != .disconnected {
                    Section(header: Text("Connection Status").accessibility(identifier: "connection_status_header")) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(statusText)
                                .foregroundColor(statusColor)
                                .accessibility(identifier: "connection_status_text")
                        }
                        .accessibility(identifier: "connection_status_row")
                        
                        if connectivityManager.connectionState == .error, 
                           let error = connectivityManager.lastError {
                            HStack {
                                Text("Error")
                                Spacer()
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                                    .accessibility(identifier: "error_text")
                            }
                            .accessibility(identifier: "error_row")
                        }
                    }
                }
                
                // Action buttons
                Section {
                    if connectivityManager.connectionState == .connected {
                        Button("Disconnect") {
                            connectivityManager.disconnect()
                        }
                        .accessibility(identifier: "disconnect_button")
                    } else {
                        Button("Connect") {
                            guard !host.isEmpty, let portValue = Int(port) else { return }
                            connectivityManager.connect(to: host, port: portValue)
                        }
                        .accessibilityLabel("Connect to VRChat")
                        .accessibilityIdentifier("connect_button_sheet")
                        .disabled(host.isEmpty || connectivityManager.connectionState == .connecting)
                    }
                    
                    // Only show "Done" when connected
                    if connectivityManager.connectionState == .connected {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibility(identifier: "done_button")
                    }
                }
                .accessibility(identifier: "action_buttons_section")
            }
            .navigationTitle("Connect to VRChat")
            .accessibility(identifier: "connect_form")
            .onAppear {
                // Start device discovery
                hostDiscovery.startBrowsing()
                
                // Initialize with saved values
                host = connectivityManager.targetHost
                port = String(connectivityManager.targetPort)
            }
            .onDisappear {
                // Clean up discovery when view disappears
                hostDiscovery.stopBrowsing()
            }
        }
        .accessibility(identifier: "connect_view")
    }
    
    // Helper computed properties
    private var statusText: String {
        switch connectivityManager.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
    
    private var statusColor: Color {
        switch connectivityManager.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
    

}

struct ConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionView()
    }
}
