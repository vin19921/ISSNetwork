//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 29/08/2023.
//

import Foundation

//public enum ISSNetworkGateway {
//    public static func createNetworkMonitor() -> NetworkMonitor {
//        NetworkMonitor.sharedNetworkMonitor
//    }
//}

public enum ISSNetworkGateway {
    public static func createNetworkMonitor() -> NetworkMonitorTest {
        NetworkMonitorTest.init()
    }
}
