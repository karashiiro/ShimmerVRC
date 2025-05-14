//
//  SettingsView.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/12/25.
//

import SwiftUI

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
                
                Section(header: Text("Watch").accessibility(identifier: "section_watch")) {
                    NavigationLink(destination: Text("Workout settings go here")) {
                        Label("Workout Settings", systemImage: "heart.circle")
                    }
                    
                    NavigationLink(destination: Text("Data settings go here")) {
                        Label("Heart Rate Data", systemImage: "waveform.path.ecg")
                    }
                }
                
                Section(header: Text("App").accessibility(identifier: "section_app")) {
                    NavigationLink(destination: Text("Display settings go here")) {
                        Label("Display", systemImage: "display")
                    }
                    
                    NavigationLink(destination: Text("About this app")) {
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
                    Text("\(connectivityManager.targetPort)")
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
