//
//  HostDiscovery.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import Network
import Combine

/// Class for discovering hosts on the local network via mDNS
class HostDiscovery: ObservableObject {
    @Published var hosts: [String] = []
    @Published var isSearching: Bool = false
    @Published var discoveryError: String? = nil
    
    private var browsers: [NWBrowser] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Service types to search for - VRChat and other common OSC-related services
    private let serviceTypes = [
        "_osc._udp",
        "_oscjson._tcp",
        "_http._tcp",
        "_vrcosc._udp",
        "_vrcosc._tcp",
        "_services._dns-sd._udp"
    ]
    
    /// Start discovery of hosts on the local network
    func startBrowsing() {
        // Reset state
        stopBrowsing()
        isSearching = true
        hosts = []
        discoveryError = nil
        
        print("Starting mDNS host discovery for \(serviceTypes.count) service types")
        
        // Create parameters that enable peer-to-peer discovery
        let params = NWParameters()
        params.includePeerToPeer = true
        
        // Create browsers for each service type
        for serviceType in serviceTypes {
            print("Starting browser for service type: \(serviceType)")
            
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)
            
            // Handle results
            browser.browseResultsChangedHandler = { [weak self] results, changes in
                guard let self = self else { return }
                
                print("Found \(results.count) results for \(serviceType)")
                
                let newHosts = results.compactMap { result -> String? in
                    if case let .service(name, type, domain, _) = result.endpoint {
                        print("Found service: \(name) (\(type).\(domain))")
                        return name
                    }
                    return nil
                }
                
                if !newHosts.isEmpty {
                    DispatchQueue.main.async {
                        // Add new hosts without duplicates
                        let combinedHosts = Set(self.hosts).union(Set(newHosts))
                        self.hosts = Array(combinedHosts).sorted()
                    }
                }
            }
            
            // Handle state changes
            browser.stateUpdateHandler = { [weak self] state in
                switch state {
                case .setup:
                    print("\(serviceType) browser: setup")
                case .ready:
                    print("\(serviceType) browser: ready")
                case .cancelled:
                    print("\(serviceType) browser: cancelled")
                case .failed(let error):
                    print("\(serviceType) browser failed: \(error)")
                    DispatchQueue.main.async {
                        self?.discoveryError = "Browser failed: \(error)"
                    }
                default:
                    break
                }
            }
            
            // Start browsing and store the browser
            browser.start(queue: .main)
            browsers.append(browser)
        }
        
        // Set a timeout - if no hosts found after 15 seconds, show an error
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.isSearching else { return }
            
            if self.hosts.isEmpty {
                print("No hosts found after timeout, stopping discovery")
                
                self.discoveryError = "No hosts found. You may need to enter the IP address manually."
                
                // Don't stop browsing yet, just show the error - maybe something will show up later
            }
        }
    }
    
    /// Stop discovery of hosts
    func stopBrowsing() {
        print("Stopping \(browsers.count) browsers")
        
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
        isSearching = false
    }
    
    deinit {
        stopBrowsing()
    }
}
