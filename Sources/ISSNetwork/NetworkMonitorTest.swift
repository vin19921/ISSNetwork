//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 29/08/2023.
//

import Combine
import Network

//public final class NetworkMonitorTest: ObservableObject {
//    private var monitor: NWPathMonitor?
//    private var queue: DispatchQueue
//
//    @Published var isInternetAvailable = false
//
//    public var internetStatus: Bool {
//        isInternetAvailable
//    }
//
//    public init() {
//        if monitor == nil {
//            monitor = NWPathMonitor()
//        }
//        queue = DispatchQueue(label: "NetworkMonitorTest")
//        monitor?.start(queue: queue)
//        monitor?.pathUpdateHandler = { path in
//            DispatchQueue.main.async {
//                self.isInternetAvailable = path.status == .satisfied
//            }
//        }
//    }
//
//    public func retryConnection() {
//        if monitor == nil {
//            monitor = NWPathMonitor()
//        }
//        queue = DispatchQueue(label: "NetworkMonitorTest")
//        monitor?.start(queue: queue)
//        monitor?.pathUpdateHandler = { path in
//            DispatchQueue.main.async {
//                self.isInternetAvailable = path.status == .satisfied
//            }
//        }
//    }
//
//    public func stopMonitoring() {
//        monitor?.cancel()
//    }
//}

final class NetworkMonitorTest: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isCellular = false
    @Published var isInternetAvailable = false

    public var internetStatus: Bool {
        isConnected
    }

    private let nwMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue.global()

    init() {
        nwMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.usesInterfaceType(.cellular)
                // Optionally, you can update isInternetAvailable based on your logic.
                // For example, you can check if isConnected and isCellular meet your criteria.
                self?.isInternetAvailable = self?.checkInternetAvailability() ?? false
            }
        }
        nwMonitor.start(queue: workerQueue)
    }

    public func stop() {
        nwMonitor.cancel()
    }

    // This function can be called to check internet availability based on your criteria.
    private func checkInternetAvailability() -> Bool {
        // Implement your logic to determine internet availability here.
        // For example, you can check if isConnected and isCellular meet your criteria.
        return isConnected && !isCellular
    }
}

