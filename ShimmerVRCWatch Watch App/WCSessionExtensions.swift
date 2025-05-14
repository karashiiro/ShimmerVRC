//
//  WCSessionExtensions.swift
//  ShimmerVRCWatch Watch App
//
//  Created by karashiiro on 5/13/25.
//

import Foundation
import WatchConnectivity

extension WCSessionActivationState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notActivated:
            return "notActivated"
        case .inactive:
            return "inactive"
        case .activated:
            return "activated"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}
