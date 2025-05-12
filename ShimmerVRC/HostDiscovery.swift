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
    
    private var browser: NWBrowser?
    private var cancellables = Set<AnyCancellable>()
    
    /// Start discovery of hosts on the local network
    func startBrowsing() {
        isSearching = true
        hosts = []
        
        // Create parameters that enable peer-to-peer discovery
        let params = NWParameters()
        params.includePeerToPeer = true
        
        // Create a browser for Bonjour services
        // Using _services._dns-sd._udp to browse all services
        browser = NWBrowser(for: .bonjour(type: "_services._dns-sd._udp", domain: nil), using: params)
        
        // Handle results
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            
            let names = results.compactMap { result -> String? in
                if case let .service(name, _, _, _) = result.endpoint {
                    return name
                }
                return nil
            }
            
            DispatchQueue.main.async {
                // Uniquify and sort the names
                self.hosts = Array(Set(names)).sorted()
            }
        }
        
        // Handle state changes
        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .setup, .ready:
                print("mDNS browser: \(state)")
            case .cancelled:
                DispatchQueue.main.async {
                    self?.isSearching = false
                }
            case .failed(let error):
                print("mDNS browser failed: \(error)")
                DispatchQueue.main.async {
                    self?.isSearching = false
                }
            default:
                break
            }
        }
        
        // Start browsing
        browser?.start(queue: .main)
    }
    
    /// Stop discovery of hosts
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }
    
    deinit {
        stopBrowsing()
    }
}
