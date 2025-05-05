import Foundation
import Combine

// Achievement Notification Bridge sınıfı
// Düzeltme: ObservableObject protokolüne uyumlu hale getir
class AchievementNotificationBridge: ObservableObject {
    
    // Singleton instance
    static let shared = AchievementNotificationBridge()
    
    // Bildirim isimleri (Constants olarak tanımlamak daha iyi)
    struct NotificationNames {
        static let achievementUnlocked = Notification.Name("AchievementUnlocked")
        static let achievementProgress = Notification.Name("AchievementProgress")
        static let showAchievementPopup = Notification.Name("ShowAchievementPopup")
    }
    
    // Düzeltme: Başlatıcıyı private'dan internal yapalım (veya public)
    // Eğer singleton ise private kalabilir, dışarıdan çağrılmayacak.
    // Şimdilik singleton olduğu için private bırakabiliriz.
    private init() {
        logInfo("AchievementNotificationBridge initialized")
    }
    
    // Başarım kilidi açıldığında bildirim gönder
    func postAchievementUnlocked(achievement: Achievement) {
        NotificationCenter.default.post(
            name: NotificationNames.achievementUnlocked,
            object: nil,
            userInfo: ["achievement": achievement]
        )
        logInfo("Bildirim gönderildi: Başarım kilidi açıldı - \(achievement.title)")
        
        // Popup gösterme bildirimini de gönder
        postShowAchievementPopup(achievement: achievement)
    }
    
    // Başarım ilerlemesi olduğunda bildirim gönder
    func postAchievementProgress(achievement: Achievement, progress: Float, goal: Float) {
        NotificationCenter.default.post(
            name: NotificationNames.achievementProgress,
            object: nil,
            userInfo: [
                "achievement": achievement,
                "progress": progress,
                "goal": goal
            ]
        )
         // Çok sık loglama yapmamak için bunu loglamayabiliriz
         // logInfo("Bildirim gönderildi: Başarım ilerlemesi - \(achievement.title): \(progress)/\(goal)")
    }
    
    // Başarım popup'ını göstermek için bildirim gönder
    func postShowAchievementPopup(achievement: Achievement) {
        NotificationCenter.default.post(
            name: NotificationNames.showAchievementPopup, 
            object: nil,
            userInfo: ["achievement": achievement]
        )
        logInfo("Bildirim gönderildi: Başarım popup'ı göster - \(achievement.title)")
    }
} 