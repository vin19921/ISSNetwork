//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 29/08/2023.
//

import Network

class NetworkMonitorTest {
    private var monitor: NWPathMonitor
    private var queue: DispatchQueue
    
    @Published var isInternetAvailable = false

    init() {
        monitor = NWPathMonitor()
        queue = DispatchQueue(label: "NetworkMonitorTest")
    }

    func startMonitoring() {
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isInternetAvailable = path.status == .satisfied
            }
        }
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}


