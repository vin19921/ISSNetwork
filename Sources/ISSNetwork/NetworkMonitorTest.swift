//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 29/08/2023.
//

import Combine
import Network

public final class NetworkMonitorTest: ObservableObject {
    private var monitor: NWPathMonitor
    private var queue: DispatchQueue
    
    @Published public var isInternetAvailable = false

    public init() {
        monitor = NWPathMonitor()
        queue = DispatchQueue(label: "NetworkMonitorTest")
    }

    public func startMonitoring() {
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isInternetAvailable = path.status == .satisfied
            }
        }
    }

    public func stopMonitoring() {
        monitor.cancel()
    }
}


