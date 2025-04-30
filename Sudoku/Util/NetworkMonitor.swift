import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // Notification name for network connection updates
    static let NetworkConnectedNotification = Notification.Name("NetworkConnectedNotification")
    static let NetworkDisconnectedNotification = Notification.Name("NetworkDisconnectedNotification")
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    @Published var isConnected: Bool = false
    private var lastConnectionStatus: Bool? = nil

    private init() {
        monitor = NWPathMonitor()
        setupMonitor()
    }

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newStatus = path.status == .satisfied
            
            // Update published property on the main thread
            DispatchQueue.main.async {
                self.isConnected = newStatus
                
                // Post notification only when status changes
                if self.lastConnectionStatus != newStatus {
                    if newStatus {
                        NotificationCenter.default.post(
                            name: Self.NetworkConnectedNotification, 
                            object: nil,
                            userInfo: ["isConnected": true]
                        )
                    } else {
                        NotificationCenter.default.post(
                            name: Self.NetworkDisconnectedNotification, 
                            object: nil,
                            userInfo: ["isConnected": false]
                        )
                    }
                    self.lastConnectionStatus = newStatus
                }
            }
        }
    }

    func startMonitoring() {
        // Check initial path status
        let initialPath = monitor.currentPath
        self.isConnected = initialPath.status == .satisfied
        self.lastConnectionStatus = self.isConnected
        
         if self.isConnected {
            // Post initial notification if connected at start - delay a bit to let app prepare
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in // Delay 0.5 second
                if self?.isConnected == true {
                    NotificationCenter.default.post(
                        name: Self.NetworkConnectedNotification,
                        object: nil,
                        userInfo: ["isConnected": true]
                    )
                }
            }
         }
         
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
} 