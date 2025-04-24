import SwiftUI
import Combine

class AchievementNotificationManager: ObservableObject {
    static let shared = AchievementNotificationManager()
    
    @Published var currentAchievement: Achievement?
    @Published var shouldShowNotification = false
    @Published var achievementQueue: [Achievement] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var processingNotification = false
    
    private init() {
        // AchievementManager'dan başarım bildirimlerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showNewAchievements),
            name: NSNotification.Name("NewAchievementsUnlocked"),
            object: nil
        )
        
        // shouldShowNotification değiştiğinde, false olduğunda ve kuyrukta başarım varsa
        // bir sonraki bildirimi göster
        $shouldShowNotification
            .filter { !$0 }
            .sink { [weak self] _ in
                guard let self = self, !self.processingNotification else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Kısa bir gecikme ile işleme devam et
                    self.processNextNotificationIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    // AchievementManager'dan bildirilen başarımları göster
    @objc func showNewAchievements(_ notification: Notification) {
        if let achievements = notification.userInfo?["achievements"] as? [Achievement] {
            print("📝 \(achievements.count) yeni başarım bildirimi bildirimi alındı")
            
            // Özel sıralamaya göre başarımları sırala
            // Önce özel başarımlar, sonra zorluk başarımları
            let sortedAchievements = achievements.sorted { (a1, a2) -> Bool in
                // Başarım kategorisi önceliği: Özel > Zaman > Diğerleri
                if a1.category == .special && a2.category != .special {
                    return true
                } else if a1.category != .special && a2.category == .special {
                    return false
                } else if a1.category == .time && a2.category != .time {
                    return true
                } else if a1.category != .time && a2.category == .time {
                    return false
                }
                
                // Aynı kategorideyse ismine göre sırala
                return a1.name < a2.name
            }
            
            // Bildirilecek başarımları kuyruğa ekle
            for achievement in sortedAchievements {
                showAchievementNotification(achievement: achievement)
            }
            print("📝 \(sortedAchievements.count) yeni başarım bildirimi kuyruğa eklendi")
        }
    }
    
    // Tüm kazanılan başarımları göstermek için fonksiyon
    func showAllUnlockedAchievements() {
        guard let unlockedAchievements = AchievementManager.shared.getNewlyUnlockedAchievements() else {
            print("📝 Gösterilecek yeni başarım bulunamadı")
            return
        }
        
        print("📝 Gösterilecek \(unlockedAchievements.count) başarım bulundu")
        
        // Özel sıralamaya göre başarımları sırala
        let sortedAchievements = unlockedAchievements.sorted { (a1, a2) -> Bool in
            // Başarım türüne göre sırala (Önemli olanlar önce)
            if a1.category == .special && a2.category != .special {
                return true
            } else if a1.category != .special && a2.category == .special {
                return false
            } else {
                // Aynı kategorideyse isime göre sırala
                return a1.name < a2.name
            }
        }
        
        // Tüm başarımları kuyruğa ekle
        for achievement in sortedAchievements {
            showAchievementNotification(achievement: achievement)
        }
    }
    
    func showAchievementNotification(achievement: Achievement) {
        // Geçersiz başarımları filtrele
        guard achievement.id.count > 0 else {
            print("⚠️ Geçersiz başarım bildirimi: ID boş")
            return
        }
        
        // Eğer şu anda gösterilen başarım ile aynıysa yeniden gösterme
        if let currentAchievement = currentAchievement, currentAchievement.id == achievement.id {
            print("⚠️ Aynı başarım şu anda gösteriliyor: \(achievement.name)")
            return
        }
        
        // Kuyrukta aynı başarım zaten var mı kontrol et
        guard !achievementQueue.contains(where: { $0.id == achievement.id }) else {
            print("⚠️ Başarım zaten kuyrukta: \(achievement.name)")
            return
        }
        
        // Başarımı kuyruğa ekle
        achievementQueue.append(achievement)
        print("📝 Başarım kuyruğa eklendi: \(achievement.name), Kuyruk uzunluğu: \(achievementQueue.count + 1)")
        
        // Eğer şu anda başka bir bildirim gösterilmiyorsa, bu bildirimi göster
        if !shouldShowNotification && !processingNotification {
            processNextNotificationIfNeeded()
        }
    }
    
    func processNextNotificationIfNeeded() {
        guard !achievementQueue.isEmpty, !shouldShowNotification, !processingNotification else {
            if achievementQueue.isEmpty {
                print("📝 Bildirim kuyruğu boş, işlem yapılmadı")
            } else if shouldShowNotification {
                print("📝 Zaten bir bildirim gösteriliyor, bekleniyor")
            } else if processingNotification {
                print("📝 Bildirim işlemde, bekleniyor")
            }
            return
        }
        
        processingNotification = true
        
        // Kuyruktaki ilk başarımı al ve kuyruktan çıkar
        currentAchievement = achievementQueue.removeFirst()
        print("📝 Bildirim gösteriliyor: \(currentAchievement?.name ?? "Bilinmeyen"), Kalan bildirim: \(achievementQueue.count)")
        
        // Bildirimi göster
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.shouldShowNotification = true
            self.processingNotification = false
        }
    }
    
    // Belirli bir başarım bildirimini göstermek için (kaydırma için kullanılacak)
    func showSpecificAchievement(achievement: Achievement) {
        // Eğer kuyrukta bu başarım yoksa, önce kuyruğa ekle
        if !achievementQueue.contains(where: { $0.id == achievement.id }) {
            achievementQueue.append(achievement)
        }
        
        // Şu anda gösterilen bildirimi kapat
        shouldShowNotification = false
        
        // Kuyruktaki diğer başarımları yeniden düzenle
        achievementQueue.removeAll { $0.id == achievement.id }
        
        // İşleme devam et
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.processNextNotificationIfNeeded()
        }
    }
    
    // Tüm bildirimleri temizle
    func clearAllNotifications() {
        print("🧹 Tüm bildirimler temizleniyor")
        achievementQueue.removeAll()
        shouldShowNotification = false
        currentAchievement = nil
    }
} 