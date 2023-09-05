//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 29/08/2023.
//

import Combine
import Network

public final class NetworkMonitorTest: ObservableObject {
    private var monitor: NWPathMonitor?
    private var queue: DispatchQueue
    
    @Published var isInternetAvailable = false

    public var internetStatus: Bool {
        isInternetAvailable
    }

    public init() {
        if monitor == nil {
            monitor = NWPathMonitor()
        }
        queue = DispatchQueue(label: "NetworkMonitorTest")
        startMonitoring()
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

    public func retryConnection() {
        if monitor == nil {
            monitor = NWPathMonitor()
        }
        if !isInternetAvailable {
            queue = DispatchQueue(label: "NetworkMonitorTest")
            startMonitoring()
        }
    }
}


