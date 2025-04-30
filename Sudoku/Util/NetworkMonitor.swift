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
                print("Ağ Durumu Güncellendi: \(newStatus ? "Bağlandı" : "Bağlantı Kesildi")")
                
                // Post notification only when status changes
                if self.lastConnectionStatus != newStatus {
                    if newStatus {
                         print("NetworkConnectedNotification gönderiliyor...")
                         NotificationCenter.default.post(name: Self.NetworkConnectedNotification, object: nil)
                    } else {
                         print("NetworkDisconnectedNotification gönderiliyor...")
                         NotificationCenter.default.post(name: Self.NetworkDisconnectedNotification, object: nil)
                    }
                    self.lastConnectionStatus = newStatus
                }
            }
        }
    }

    func startMonitoring() {
        print("NetworkMonitor başlatılıyor...")
        // Check initial path status
        let initialPath = monitor.currentPath
        self.isConnected = initialPath.status == .satisfied
        self.lastConnectionStatus = self.isConnected
         print("İlk Ağ Durumu: \(self.isConnected ? "Bağlandı" : "Bağlantı Kesildi")")
         if self.isConnected {
              // Post initial notification if connected at start
              // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Small delay
              //     print("Başlangıçta bağlı, NetworkConnectedNotification gönderiliyor...")
              //     NotificationCenter.default.post(name: Self.NetworkConnectedNotification, object: nil)
              // }
         }
         
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
         print("NetworkMonitor durduruluyor...")
        monitor.cancel()
    }
} 