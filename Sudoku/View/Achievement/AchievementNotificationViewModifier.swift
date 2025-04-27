import SwiftUI

// Başarım bildirimlerini tüm sayfalarda göstermek için ViewModifier
struct AchievementNotificationViewModifier: ViewModifier {
    @ObservedObject var notificationManager = AchievementNotificationManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            // Ana içerik
            content
            
            // Başarım bildirimi
            AchievementNotificationView()
                .zIndex(999) // En üstte göster
        }
    }
}

// View uzantısı - kolay kullanım için
extension View {
    func withAchievementNotifications() -> some View {
        self.modifier(AchievementNotificationViewModifier())
    }
}

// NotificationCenter ile AchievementToastSystem ve AchievementNotificationManager arasında köprü
class AchievementNotificationBridge {
    static let shared = AchievementNotificationBridge()
    
    private init() {
        // Köprü devre dışı bırakıldı
        // Eski bildirim sistemi (AchievementToastSystem) zaten NotificationCenter üzerinden
        // doğrudan bildirim alıyor, bu yüzden köprüye gerek yok
    }
    
    private func setupBridge() {
        // Yeni bildirim sistemi devre dışı bırakıldı
        // Bildirimler sadece eski sisteme (AchievementToastSystem) gidecek
    }
}
