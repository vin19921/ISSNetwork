//
//  ISSNetworkGateway.swift
//  
//
//  Copyright by iSoftStone 2023.
//

import Foundation

public enum ISSNetworkGateway {
    public static func createNetworkMonitor() -> NetworkMonitor {
        NetworkMonitor.sharedNetworkMonitor
    }
}
