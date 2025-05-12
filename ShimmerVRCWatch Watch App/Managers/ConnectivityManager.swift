//
//  ConnectivityManager.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/11/25.
//

import Foundation
import WatchConnectivity

// Protocol for easier unit testing
protocol WatchConnectivityProtocol {
    var isReachable: Bool { get }
    func activate()
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?, errorHandler: ((Error) -> Void)?)
}

// WCSession conformance to protocol
extension WCSession: WatchConnectivityProtocol {}

class ConnectivityManager: NSObject, ObservableObject {
    static let shared = ConnectivityManager()
    
    private let session: WatchConnectivityProtocol
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    init(session: WatchConnectivityProtocol = WCSession.default) {
        self.session = session
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            lastError = "WCSession is not supported"
            return
        }
        
        if let wcSession = session as? WCSession {
            wcSession.delegate = self
        }
        
        session.activate()
    }
    
    func sendHeartRate(_ heartRate: Double) {
        guard session.isReachable else {
            lastError = "iPhone is not reachable"
            return
        }
        
        let message = ["heartRate": heartRate]
        session.sendMessage(message, replyHandler: nil) { error in
            DispatchQueue.main.async {
                self.lastError = "Error sending heart rate: \(error.localizedDescription)"
            }
        }
    }
}

extension ConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            if let error = error {
                self.lastError = "Activation error: \(error.localizedDescription)"
            }
        }
    }
    
    // Required for WCSessionDelegate conformance on watchOS
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle any messages from the iPhone app if needed
        print("Received message from iPhone: \(message)")
    }
}
