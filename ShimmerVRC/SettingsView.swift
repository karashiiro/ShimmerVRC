//
//  SettingsView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/12/25.
//

import SwiftUI

// TODO: Add settings here
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connectivityManager = ConnectivityManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Connection").accessibility(identifier: "section_connection")) {
                    NavigationLink(destination: ConnectionSettingsView()) {
                        Label("VRChat Connection", systemImage: "network")
                    }
                    
                    Toggle("Auto-reconnect", isOn: .constant(true))
                        .tint(.blue)
                }

                Section(header: Text("App").accessibility(identifier: "section_app")) {
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct AboutView: View {
    var body: some View {
        HStack {
            Text("Shimmer v1.0.0")
                .font(.headline)
        }
        .navigationTitle("About")
    }
}

struct ConnectionSettingsView: View {
    @StateObject private var connectivityManager = ConnectivityManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Default Connection")) {
                HStack {
                    Text("Host")
                    Spacer()
                    Text(connectivityManager.targetHost)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Port")
                    Spacer()
                    Text(String(connectivityManager.targetPort))
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Connection Behavior")) {
                NavigationLink(destination: Text("Advanced OSC settings")) {
                    Label("OSC Configuration", systemImage: "gear")
                }
                
                NavigationLink(destination: Text("Background mode settings")) {
                    Label("Background Mode", systemImage: "iphone.and.arrow.forward")
                }
            }
        }
        .navigationTitle("Connection Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
