//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 29/08/2023.
//

import Network
import UIKit

public protocol NetworkConnectivity {
    func isNetworkReachable() -> Bool
}

@available(iOS 12.0, *)
public class NetworkMonitor: NetworkConnectivity {
    enum NetworkStatus {
        case connected, notConnected

        static func availableStatus(status: NWPath.Status) -> Self {
            switch status {
            case .satisfied:
                return .connected
            default:
                return .notConnected
            }
        }
    }

    enum Constants {
        static let kNetworkReachabilityChange = "networkReachabilityChanged"
        static let networkMonitorLabel = "NetworkStatus_Monitor"
        static let networkMonitorStatus = "Status"
    }

    private var monitor: NWPathMonitor?
    var currentStatus: NWPath.Status?
    var isWifi: Bool = false
    public static let sharedNetworkMonitor = NetworkMonitor()

    // We need to make this as shared instance else we need to call monitorNetworkChange in the package level also.
    private init() {}

    public func monitorNetworkChange() {
        if monitor == nil {
            monitor = NWPathMonitor()
        }
        let queue = DispatchQueue(label: Constants.networkMonitorLabel)

        monitor?.start(queue: queue)
        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self, let currentStatus = self.monitor?.currentPath.status else { return }
            if path.usesInterfaceType(.wifi) {
                self.isWifi = true
            } else if path.usesInterfaceType(.cellular) {
                self.isWifi = false
            } else if path.usesInterfaceType(.wiredEthernet) {
                self.isWifi = true
            } else {
                self.isWifi = false
            }

            self.currentStatus = currentStatus
            print("Network Status ::: \(self.currentStatus)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(Constants.kNetworkReachabilityChange),
                                                object: self,
                                                userInfo: [Constants.networkMonitorStatus: NetworkStatus.availableStatus(status: currentStatus)])
            }
        }
    }

    public func stopMonitoring() {
        monitor = nil
        monitor?.cancel()
    }

    public func isConnectedToWifi() -> Bool {
        isWifi
    }

    public func isNetworkReachable() -> Bool {
//        if currentStatus != .satisfied {
//            monitorNetworkChange()
//        }
//        return currentStatus == .satisfied
        currentStatus == .satisfied
    }
}

