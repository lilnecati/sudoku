import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreData

// UserDefaultsKeys tanımı
enum UserDefaultsKeys {
    static let achievements = "user_achievements"
    static let pendingSyncAchievements = "pending_sync_achievements"
}

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "user_achievements"
    private let pendingSyncKey = "pending_sync_achievements"
    
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var totalPoints: Int = 0
    @Published var showAchievementAlert: Bool = false
    @Published var lastUnlockedAchievement: Achievement? = nil
    @Published var unlockedAchievements: [String: Bool] = [:]
    @Published private(set) var newlyUnlockedAchievements: [Achievement] = []
    
    // Çevrimdışı mod için senkronizasyon kuyruğu
    private var pendingSyncQueue: [String] = []
    private var isCurrentlySync: Bool = false
    
    // CoreData servis referansı
    private let achievementCoreDataService = AchievementCoreDataService()
    
    // PersistenceController referansı (yeni eklendi)
    private let persistenceController = PersistenceController.shared
    
    private var db: Firestore {
        return Firestore.firestore()
    }
    
    private func setupNotifications() {
        // Başarı sıfırlama bildirimi için dinleyici ekle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetAchievementsData),
            name: Notification.Name("ResetAchievements"),
            object: nil
        )
        
        // Kullanıcı giriş yaptığında Firebase'den başarımları yüklemek için dinleyici ekle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLoggedIn),
            name: Notification.Name("UserLoggedIn"),
            object: nil
        )
        
        // İnternet bağlantısı değişiklikleri için dinleyiciler
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkConnectivityChange),
            name: NSNotification.Name("NetworkReachabilityChanged"),
            object: nil
        )
    }
    
    private init() {
        setupAchievements()
        loadAchievements()
        loadPendingSyncQueue()
        checkDailyAchievementsStatus()
        setupNotifications()
        
        // Eğer kullanıcı giriş yapmışsa, Firebase'den başarımları yükle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            logInfo("[ACH_INIT_CHECK] Dispatch queue block executed.") // <<< YENİ LOG
            if let currentUser = Auth.auth().currentUser {
                logInfo("[ACH_INIT_CHECK] User IS logged in (uid: \(currentUser.uid)). Calling loadAchievementsFromFirebase.") // <<< YENİ LOG
                // init sırasında çağrıldığında completion ile işimiz yok, sadece yüklemeyi denesin.
                self?.loadAchievementsFromFirebase { _ in /* Init sırasında sonuçla ilgilenmiyoruz */ }
            } else {
                logWarning("[ACH_INIT_CHECK] User IS NOT logged in at this point.") // <<< YENİ LOG
            }
        }
    }
    
    // Kullanıcı giriş yaptığında çağrılan fonksiyon
    @objc private func handleUserLoggedIn() {
        logInfo("[ACH_NOTIFICATION] handleUserLoggedIn called.") // <<< YENİ LOG
        logInfo("Kullanıcı oturum açtı - Başarımlar yükleniyor ve senkronize ediliyor") // Log güncellendi
        guard let user = Auth.auth().currentUser else {
            logError("handleUserLoggedIn: Kullanıcı bulunamadı.")
            return
        }
        
        // CoreData'dan önce başarımları yükle (Bu kısım senkron çalışır)
            let coreDataAchievements = achievementCoreDataService.loadAchievements(for: user.uid)
            if !coreDataAchievements.isEmpty {
            logInfo("CoreData\'dan \(coreDataAchievements.count) başarım yüklendi")
            // CoreData\'daki verileri yerel başarımlara yükle
                for coreDataAchievement in coreDataAchievements {
                    if let index = achievements.firstIndex(where: { $0.id == coreDataAchievement.id }) {
                    // Sadece yerel tamamlanmamış ve CoreData tamamlanmışsa veya ilerleme daha yüksekse güncelle
                    if (!achievements[index].isCompleted && coreDataAchievement.isCompleted) ||
                        (coreDataAchievement.currentValue > achievements[index].currentValue && !achievements[index].isCompleted) {
                            achievements[index] = coreDataAchievement
                        }
                    }
                }
                calculateTotalPoints()
            }
            
        // Firebase\'den başarımları yükle ve BİTTİĞİNDE bekleyenleri işle
        loadAchievementsFromFirebase { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async { // Ana thread'e dön
                if success {
                    logInfo("Firebase\'den yükleme başarılı, şimdi bekleyen senkronizasyonlar işleniyor.")
                    self.processPendingSyncQueue()
                } else {
                    logError("Firebase\'den başarım yükleme başarısız oldu. Bekleyen senkronizasyonlar şimdilik işlenmeyecek.")
                    // Başarısız yükleme durumunda senkronizasyonu tetiklememek,
                    // sunucudaki verinin üzerine yanlışlıkla yazmayı önler.
                }
            }
        }
            
            // Tam senkronizasyon yapmayı dene (handleUserLoggedIn içinde zaten yükleme yapılıyor, belki bu gereksiz? Şimdilik ekleyelim)
            // syncWithFirebase() // Bu, loadAchievementsFromFirebase içinde zaten yapılıyor gibi görünüyor, şimdilik yoruma alalım.
    }
    
    // Yeni başarımları almak için metod (bildirimler için)
    func getNewlyUnlockedAchievements() -> [Achievement]? {
        if newlyUnlockedAchievements.isEmpty {
            return nil
        }
        
        let achievements = newlyUnlockedAchievements
        newlyUnlockedAchievements = [] // Alındıktan sonra listeyi temizle
        return achievements
    }
    
    // Oyun tamamlandığında biten oyunu kayıtlardan silmek için
    func handleCompletedGame(gameID: UUID, difficulty: SudokuBoard.Difficulty, time: TimeInterval, errorCount: Int, hintCount: Int) {
        // Tamamlanmış oyunu kaydet ve kayıtlı oyunlardan sil
        // Firebase Firestore iç içe dizileri desteklemediği için düz bir dizi kullanıyoruz
        // Bellek optimizasyonu: Sabit boyutlu dizi kullanıyoruz
        // Boş bir tahta için tek boyutlu dizi oluşturuyoruz (81 hücre)
        let flatBoard = [Int](repeating: 0, count: 81) // 9x9 düzleştirilmiş tahta
        
        // Önemli: Önce silme işlemini gerçekleştiriyoruz, sonra kaydediyoruz
        // Bu şekilde çift silme işlemi önlenmiş olacak
        logDebug("Oyun tamamlandı: \(gameID) - Önce silme işlemi yapılıyor")
        PersistenceController.shared.deleteGameFromFirestore(gameID: gameID)
        
        // Silme işleminden sonra kayıt işlemi yapılıyor
        // Not: saveCompletedGame fonksiyonu 2D dizi bekliyor, ancak içeride flatMap ile düzleştiriyor
        // Bellek optimizasyonu: Tek bir dizi oluşturuyoruz ve referans olarak kullanıyoruz
        let singleRowBoard = [flatBoard] // Tek satırlı 2D dizi (nested array olmadan)
        
        logDebug("Oyun tamamlandı: \(gameID) - Silme işleminden sonra kayıt yapılıyor")
        PersistenceController.shared.saveCompletedGame(
            gameID: gameID,
            board: singleRowBoard, // Tek satırlı 2D dizi olarak gönderiyoruz
            difficulty: difficulty.rawValue,
            elapsedTime: time,
            errorCount: errorCount,
            hintCount: hintCount
        )
        
        // UI güncellemesi için bildirim gönderiyoruz - gecikmesiz
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
        }
        
        logSuccess("Tamamlanan oyun işlenip, kayıtlı oyunlardan silindi")
    }
    
    // Başarıları oluştur ve hazırla
    private func setupAchievements() {
        achievements = [
            // Başlangıç başarıları - Kolay seviye
            Achievement(id: "easy_1", name: "İlk Adım", description: "İlk Kolay Sudoku'yu tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 1),
            Achievement(id: "easy_10", name: "Kolay Uzman", description: "10 Kolay Sudoku tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 10),
            Achievement(id: "easy_50", name: "Kolay Üstat", description: "50 Kolay Sudoku tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 50),
            Achievement(id: "easy_100", name: "Kolay Efsane", description: "100 Kolay Sudoku tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 100),
            Achievement(id: "easy_500", name: "Kolay Sudoku Kralı", description: "500 Kolay Sudoku tamamla", category: .beginner, iconName: "crown.fill", requiredValue: 500),
            Achievement(id: "easy_1000", name: "Kolay Sudoku İmparatoru", description: "1000 Kolay Sudoku tamamla", category: .beginner, iconName: "crown.fill", requiredValue: 1000),
            
            // Orta seviye başarıları
            Achievement(id: "medium_1", name: "Zorluğa Adım", description: "İlk Orta Sudoku'yu tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 1),
            Achievement(id: "medium_10", name: "Orta Seviye Uzman", description: "10 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 10),
            Achievement(id: "medium_50", name: "Orta Seviye Üstat", description: "50 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 50),
            Achievement(id: "medium_100", name: "Orta Seviye Efsane", description: "100 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 100),
            Achievement(id: "medium_250", name: "Orta Seviye Sudoku Kralı", description: "250 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "crown.fill", requiredValue: 250),
            Achievement(id: "medium_500", name: "Orta Seviye Sudoku İmparatoru", description: "500 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "crown.fill", requiredValue: 500),
            
            // Zor ve Uzman başarıları
            Achievement(id: "hard_1", name: "Zor Meydan Okuma", description: "İlk Zor Sudoku'yu tamamla", category: .expert, iconName: "bolt.fill", requiredValue: 1),
            Achievement(id: "hard_10", name: "Zor Uzman", description: "10 Zor Sudoku tamamla", category: .expert, iconName: "bolt.fill", requiredValue: 10),
            Achievement(id: "hard_50", name: "Zor Seviye Üstat", description: "50 Zor Sudoku tamamla", category: .expert, iconName: "bolt.fill", requiredValue: 50),
            Achievement(id: "hard_100", name: "Zor Seviye Efsane", description: "100 Zor Sudoku tamamla", category: .expert, iconName: "bolt.fill", requiredValue: 100),
            Achievement(id: "hard_250", name: "Zor Seviye Sudoku Kralı", description: "250 Zor Sudoku tamamla", category: .expert, iconName: "crown.fill", requiredValue: 250),
            Achievement(id: "expert_1", name: "Uzman Meydan Okuma", description: "İlk Uzman Sudoku'yu tamamla", category: .expert, iconName: "star.fill", requiredValue: 1),
            Achievement(id: "expert_5", name: "Gerçek Sudoku Ustası", description: "5 Uzman Sudoku tamamla", category: .expert, iconName: "star.fill", requiredValue: 5),
            Achievement(id: "expert_25", name: "Uzman Sudoku Dehası", description: "25 Uzman Sudoku tamamla", category: .expert, iconName: "star.fill", requiredValue: 25),
            Achievement(id: "expert_50", name: "Uzman Sudoku Efsanesi", description: "50 Uzman Sudoku tamamla", category: .expert, iconName: "medal.fill", requiredValue: 50),
            Achievement(id: "expert_100", name: "Uzman Sudoku İmparatoru", description: "100 Uzman Sudoku tamamla", category: .expert, iconName: "medal.fill", requiredValue: 100),
            
            // Devamlılık başarıları
            Achievement(id: "streak_3", name: "Devam Eden Merak", description: "3 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar", requiredValue: 3),
            Achievement(id: "streak_7", name: "Haftalık Rutin", description: "7 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar", requiredValue: 7),
            Achievement(id: "streak_14", name: "İki Haftalık Tutku", description: "14 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.badge.clock", requiredValue: 14),
            Achievement(id: "streak_30", name: "Sudoku Tutkunu", description: "30 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.badge.clock", requiredValue: 30),
            Achievement(id: "streak_60", name: "Sudoku Bağımlısı", description: "60 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.badge.exclamationmark", requiredValue: 60),
            Achievement(id: "streak_100", name: "Sudoku Yaşam Tarzı", description: "100 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.day.timeline.leading", requiredValue: 100),
            Achievement(id: "streak_180", name: "Yarım Yıllık Sebat", description: "180 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.badge.clock.rtl", requiredValue: 180),
            Achievement(id: "streak_365", name: "Bir Yıllık Sudoku Efsanesi", description: "365 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.badge.clock.rtl", requiredValue: 365),
            
            // Zaman başarıları
            Achievement(id: "time_easy_3", name: "Hızlı Kolay", description: "Kolay Sudoku'yu 3 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_easy_2", name: "Süper Hızlı Kolay", description: "Kolay Sudoku'yu 2 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_easy_1", name: "Şimşek Kolay", description: "Kolay Sudoku'yu 1 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.fill", requiredValue: 1),
            Achievement(id: "time_easy_30s", name: "Speed Runner Kolay", description: "Kolay Sudoku'yu 30 saniyeden kısa sürede tamamla", category: .time, iconName: "bolt.circle.fill", requiredValue: 1),
            Achievement(id: "time_medium_5", name: "Hızlı Orta", description: "Orta Sudoku'yu 5 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_medium_3", name: "Süper Hızlı Orta", description: "Orta Sudoku'yu 3 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_medium_2", name: "Şimşek Orta", description: "Orta Sudoku'yu 2 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.fill", requiredValue: 1),
            Achievement(id: "time_medium_1", name: "Speed Runner Orta", description: "Orta Sudoku'yu 1 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.circle.fill", requiredValue: 1),
            Achievement(id: "time_hard_10", name: "Hızlı Zor", description: "Zor Sudoku'yu 10 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_hard_5", name: "Süper Hızlı Zor", description: "Zor Sudoku'yu 5 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_hard_3", name: "Şimşek Zor", description: "Zor Sudoku'yu 3 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.fill", requiredValue: 1),
            Achievement(id: "time_hard_2", name: "Speed Runner Zor", description: "Zor Sudoku'yu 2 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.circle.fill", requiredValue: 1),
            Achievement(id: "time_expert_15", name: "Hızlı Uzman", description: "Uzman Sudoku'yu 15 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_expert_8", name: "Süper Hızlı Uzman", description: "Uzman Sudoku'yu 8 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_expert_5", name: "Şimşek Uzman", description: "Uzman Sudoku'yu 5 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.fill", requiredValue: 1),
            Achievement(id: "time_expert_3", name: "Speed Runner Uzman", description: "Uzman Sudoku'yu 3 dakikadan kısa sürede tamamla", category: .time, iconName: "bolt.circle.fill", requiredValue: 1),
            
            // Özel başarılar
            Achievement(id: "no_errors", name: "Kusursuz", description: "Hiç hata yapmadan bir Sudoku tamamla", category: .special, iconName: "checkmark.seal.fill", requiredValue: 1),
            Achievement(id: "no_errors_10", name: "Hatasız Üstat", description: "10 Sudoku'yu hiç hata yapmadan tamamla", category: .special, iconName: "checkmark.seal.fill", requiredValue: 10),
            Achievement(id: "no_errors_50", name: "Hatasız Efsane", description: "50 Sudoku'yu hiç hata yapmadan tamamla", category: .special, iconName: "checkmark.seal.fill", requiredValue: 50),
            Achievement(id: "no_errors_100", name: "Mükemmeliyetçi", description: "100 Sudoku'yu hiç hata yapmadan tamamla", category: .special, iconName: "checkmark.seal.fill", requiredValue: 100),
            Achievement(id: "no_hints", name: "Yardımsız", description: "Hiç ipucu kullanmadan bir Sudoku tamamla", category: .special, iconName: "lightbulb.slash.fill", requiredValue: 1),
            Achievement(id: "no_hints_10", name: "Bağımsız Düşünür", description: "10 Sudoku'yu hiç ipucu kullanmadan tamamla", category: .special, iconName: "lightbulb.slash.fill", requiredValue: 10),
            Achievement(id: "no_hints_50", name: "Sudoku Dehası", description: "50 Sudoku'yu hiç ipucu kullanmadan tamamla", category: .special, iconName: "lightbulb.slash.fill", requiredValue: 50),
            Achievement(id: "no_hints_100", name: "Doğal Yetenek", description: "100 Sudoku'yu hiç ipucu kullanmadan tamamla", category: .special, iconName: "lightbulb.slash.fill", requiredValue: 100),
            Achievement(id: "all_difficulties", name: "Tam Set", description: "Her zorluk seviyesinden en az bir Sudoku tamamla", category: .special, iconName: "square.stack.3d.up.fill", requiredValue: 4),
            Achievement(id: "daily_5", name: "Günlük Hedef", description: "Bir günde 5 Sudoku tamamla", category: .special, iconName: "target", requiredValue: 5),
            Achievement(id: "daily_10", name: "Günlük Maraton", description: "Bir günde 10 Sudoku tamamla", category: .special, iconName: "figure.run", requiredValue: 10),
            Achievement(id: "daily_20", name: "Sudoku Maratoncusu", description: "Bir günde 20 Sudoku tamamla", category: .special, iconName: "figure.run.circle.fill", requiredValue: 20),
            Achievement(id: "daily_30", name: "Günlük Ultra Maraton", description: "Bir günde 30 Sudoku tamamla", category: .special, iconName: "figure.run.circle.fill", requiredValue: 30),
            Achievement(id: "total_100", name: "Yüzler Kulübü", description: "Toplam 100 Sudoku tamamla", category: .special, iconName: "100.square", requiredValue: 100),
            Achievement(id: "total_500", name: "Beşyüzler Kulübü", description: "Toplam 500 Sudoku tamamla", category: .special, iconName: "number.square.fill", requiredValue: 500),
            Achievement(id: "total_1000", name: "Binler Kulübü", description: "Toplam 1000 Sudoku tamamla", category: .special, iconName: "number.square.fill", requiredValue: 1000),
            Achievement(id: "total_5000", name: "Sudoku Efsaneler Ligi", description: "Toplam 5000 Sudoku tamamla", category: .special, iconName: "number.square.fill", requiredValue: 5000),
            Achievement(id: "weekend_warrior", name: "Hafta Sonu Savaşçısı", description: "Cumartesi ve Pazar günleri toplam 15 Sudoku tamamla", category: .special, iconName: "figure.martial.arts", requiredValue: 15),
            Achievement(id: "weekend_master", name: "Hafta Sonu Ustası", description: "Cumartesi ve Pazar günleri toplam 30 Sudoku tamamla", category: .special, iconName: "figure.martial.arts", requiredValue: 30),
            Achievement(id: "night_owl", name: "Gece Kuşu", description: "Gece saat 22:00 ile 06:00 arasında 10 Sudoku tamamla", category: .special, iconName: "moon.stars.fill", requiredValue: 10),
            Achievement(id: "night_hunter", name: "Gece Avcısı", description: "Gece saat 22:00 ile 06:00 arasında 30 Sudoku tamamla", category: .special, iconName: "moon.stars.fill", requiredValue: 30),
            Achievement(id: "early_bird", name: "Erken Kuş", description: "Sabah saat 06:00 ile 09:00 arasında 10 Sudoku tamamla", category: .special, iconName: "sunrise.fill", requiredValue: 10),
            Achievement(id: "morning_champion", name: "Sabah Şampiyonu", description: "Sabah saat 06:00 ile 09:00 arasında 30 Sudoku tamamla", category: .special, iconName: "sunrise.fill", requiredValue: 30),
            Achievement(id: "lunch_break", name: "Öğle Arası", description: "Öğle saati 12:00-14:00 arasında 10 Sudoku tamamla", category: .special, iconName: "cup.and.saucer.fill", requiredValue: 10),
            Achievement(id: "commuter", name: "Yolcu", description: "Ulaşım saatleri 07:00-09:00 veya 17:00-19:00 arasında 20 Sudoku tamamla", category: .special, iconName: "car.fill", requiredValue: 20),
            Achievement(id: "everyday_hero", name: "Her Gün Kahraman", description: "30 gün boyunca her gün en az 1 Sudoku tamamla", category: .special, iconName: "sparkles", requiredValue: 30),
            Achievement(id: "monthly_master", name: "Aylık Usta", description: "Bir ay içinde 100 Sudoku tamamla", category: .special, iconName: "calendar.badge.plus", requiredValue: 100),
            Achievement(id: "holiday_player", name: "Tatil Oyuncusu", description: "Resmi tatil günlerinde 5 Sudoku tamamla", category: .special, iconName: "gift.fill", requiredValue: 5),
            Achievement(id: "midnight_solver", name: "Gece Yarısı Çözücüsü", description: "Gece yarısı (23:45-00:15) bir Sudoku tamamla", category: .special, iconName: "moon.circle.fill", requiredValue: 1),
            Achievement(id: "puzzle_variety", name: "Çeşitlilik Ustası", description: "Her zorluk seviyesinden en az 5 Sudoku tamamla", category: .special, iconName: "chart.bar.doc.horizontal", requiredValue: 20),
            Achievement(id: "sudoku_master", name: "Sudoku Zirve", description: "Her kategoriden en az 3 başarı kazan", category: .special, iconName: "crown.fill", requiredValue: 15),
            Achievement(id: "sudoku_grandmaster", name: "Sudoku Grandmaster", description: "Her kategoriden en az 5 başarı kazan", category: .special, iconName: "crown.fill", requiredValue: 25),
            
            // Yeni tematik başarımlar
            Achievement(id: "seasonal_spring", name: "Bahar Çiçeği", description: "İlkbahar mevsiminde 10 Sudoku tamamla", category: .special, iconName: "leaf.fill", requiredValue: 10),
            Achievement(id: "seasonal_summer", name: "Yaz Güneşi", description: "Yaz mevsiminde 15 Sudoku tamamla", category: .special, iconName: "sun.max.fill", requiredValue: 15),
            Achievement(id: "seasonal_autumn", name: "Sonbahar Yaprakları", description: "Sonbahar mevsiminde 12 Sudoku tamamla", category: .special, iconName: "leaf.arrow.circlepath", requiredValue: 12),
            Achievement(id: "seasonal_winter", name: "Kış Soğuğu", description: "Kış mevsiminde 20 Sudoku tamamla", category: .special, iconName: "snow", requiredValue: 20),
            
            // Saat bazlı başarımlar
            Achievement(id: "clock_morning_rush", name: "Sabah Koşuşturması", description: "Sabah 7-9 arası 5 Sudoku tamamla", category: .time, iconName: "sunrise.fill", requiredValue: 5),
            Achievement(id: "clock_lunch_break", name: "Öğle Molası", description: "Öğlen 12-14 arası 5 Sudoku tamamla", category: .time, iconName: "fork.knife", requiredValue: 5),
            Achievement(id: "clock_tea_time", name: "Çay Saati", description: "Öğleden sonra 15-17 arası 5 Sudoku tamamla", category: .time, iconName: "cup.and.saucer.fill", requiredValue: 5),
            Achievement(id: "clock_prime_time", name: "Altın Saatler", description: "Akşam 20-22 arası 5 Sudoku tamamla", category: .time, iconName: "tv.fill", requiredValue: 5),
            
            // Hız bazlı başarımlar
            Achievement(id: "speed_easy_20", name: "Şimşek Gibi (Kolay)", description: "Kolay Sudoku'yu 20 saniyeden kısa sürede tamamla", category: .time, iconName: "bolt.car.fill", requiredValue: 1),
            Achievement(id: "speed_medium_45", name: "Şimşek Gibi (Orta)", description: "Orta Sudoku'yu 45 saniyeden kısa sürede tamamla", category: .time, iconName: "bolt.car.fill", requiredValue: 1),
            Achievement(id: "speed_hard_90", name: "Şimşek Gibi (Zor)", description: "Zor Sudoku'yu 90 saniyeden kısa sürede tamamla", category: .time, iconName: "bolt.car.fill", requiredValue: 1),
            
            // Kombine başarımlar
            Achievement(id: "combo_perfect_5", name: "Mükemmel Seri", description: "Art arda 5 oyunu hatasız tamamla", category: .special, iconName: "star.fill", requiredValue: 5),
            Achievement(id: "combo_perfect_10", name: "Üstün Performans", description: "Art arda 10 oyunu hatasız tamamla", category: .special, iconName: "star.square.fill", requiredValue: 10),
            Achievement(id: "combo_speed_5", name: "Hız Ustası", description: "Art arda 5 oyunu kendi rekorlarından hızlı tamamla", category: .special, iconName: "timer", requiredValue: 5),
            
            // Lokasyon bazlı başarımlar
            Achievement(id: "location_traveler", name: "Gezgin Sudokucu", description: "En az 3 farklı şehirde Sudoku oyna", category: .special, iconName: "map.fill", requiredValue: 3),
            Achievement(id: "location_home", name: "Ev Konforu", description: "Ev konumunda 50 Sudoku tamamla", category: .special, iconName: "house.fill", requiredValue: 50),
            Achievement(id: "location_travel", name: "Yolda Sudoku", description: "Hareket halindeyken 25 Sudoku tamamla", category: .special, iconName: "car.fill", requiredValue: 25),
            
            // Hafta içi/sonu başarımları genişletilmiş
            Achievement(id: "weekday_monday", name: "Pazartesi Sendromu", description: "10 Pazartesi günü Sudoku oyna", category: .streak, iconName: "1.square.fill", requiredValue: 10),
            Achievement(id: "weekday_wednesday", name: "Haftanın Ortası", description: "10 Çarşamba günü Sudoku oyna", category: .streak, iconName: "3.square.fill", requiredValue: 10),
            Achievement(id: "weekday_friday", name: "Haftasonu Kapısı", description: "10 Cuma günü Sudoku oyna", category: .streak, iconName: "5.square.fill", requiredValue: 10),
            
            // Oyun stili başarımları
            Achievement(id: "style_methodical", name: "Metodolojik Çözücü", description: "Bir oyunu hiç not almadan tamamla", category: .special, iconName: "pencil.slash", requiredValue: 1),
            Achievement(id: "style_fast_input", name: "Hızlı Girişçi", description: "30 saniye içinde 30 hücre doldur", category: .special, iconName: "hand.tap.fill", requiredValue: 1),
            Achievement(id: "style_perfectionist", name: "Mükemmeliyetçi", description: "Bir oyunda tüm notları kullanarak bitir", category: .special, iconName: "doc.text.fill", requiredValue: 1),
            
            // Bayram ve özel gün başarımları
            Achievement(id: "holiday_new_year", name: "Yeni Yıl Sudokusu", description: "Yeni yılın ilk gününde bir Sudoku tamamla", category: .special, iconName: "party.popper.fill", requiredValue: 1),
            Achievement(id: "holiday_weekend", name: "Hafta Sonu Canavarı", description: "Bir hafta sonunda 20 Sudoku tamamla", category: .special, iconName: "calendar.badge.clock", requiredValue: 20),
            Achievement(id: "birthday_player", name: "Doğum Günü Oyuncusu", description: "Doğum gününde Sudoku oyna", category: .special, iconName: "gift.fill", requiredValue: 1),
            
            // Sosyal başarımlar
            Achievement(id: "social_share_first", name: "İlk Paylaşım", description: "İlk kez skorunu sosyal medyada paylaş", category: .special, iconName: "square.and.arrow.up", requiredValue: 1),
            Achievement(id: "social_share_10", name: "Sosyal Sudokucu", description: "10 kez skorunu paylaş", category: .special, iconName: "person.2.fill", requiredValue: 10),
            Achievement(id: "social_invite", name: "Davetçi", description: "Bir arkadaşını oyuna davet et", category: .special, iconName: "envelope.fill", requiredValue: 1),
            
            // Farklı cihaz başarımları
            Achievement(id: "device_multi", name: "Çok Platformlu", description: "İki farklı cihazda oyna", category: .special, iconName: "laptopcomputer.and.iphone", requiredValue: 2),
            Achievement(id: "device_sync", name: "Bulut Ustası", description: "10 kez cihazlar arası senkronizasyon yap", category: .special, iconName: "icloud.fill", requiredValue: 10),
            
            // İstatistik başarımları
            Achievement(id: "stats_500_cells", name: "500 Hücre", description: "Toplam 500 Sudoku hücresi doldur", category: .special, iconName: "number.square.fill", requiredValue: 500),
            Achievement(id: "stats_1000_cells", name: "1000 Hücre", description: "Toplam 1000 Sudoku hücresi doldur", category: .special, iconName: "number.square.fill", requiredValue: 1000),
            Achievement(id: "stats_5000_cells", name: "5000 Hücre", description: "Toplam 5000 Sudoku hücresi doldur", category: .special, iconName: "number.square.fill", requiredValue: 5000),
            
            // Zorluk atlatma başarımları
            Achievement(id: "progress_all_easy", name: "Kolayı Geride Bırak", description: "30 kolay seviye tamamlayarak orta seviyeye geç", category: .beginner, iconName: "arrowshape.up.fill", requiredValue: 30),
            Achievement(id: "progress_all_medium", name: "Ortayı Geride Bırak", description: "50 orta seviye tamamlayarak zor seviyeye geç", category: .intermediate, iconName: "arrowshape.up.fill", requiredValue: 50),
            Achievement(id: "progress_all_hard", name: "Zoru Geride Bırak", description: "70 zor seviye tamamlayarak uzman seviyeye geç", category: .expert, iconName: "arrowshape.up.fill", requiredValue: 70)
        ]
    }
    
    // Başarıları yükle
    private func loadAchievements() {
        // UserDefaults'tan yükleme
        if let data = userDefaults.data(forKey: achievementsKey),
           let savedAchievements = try? JSONDecoder().decode([Achievement].self, from: data) {
            // Mevcut başarıları yükle, ancak eksik başarıları da ekle
            var updatedAchievements: [Achievement] = []
            
            // Temel başarıları hazırla
            for baseAchievement in achievements {
                if let savedAchievement = savedAchievements.first(where: { $0.id == baseAchievement.id }) {
                    updatedAchievements.append(savedAchievement)
                } else {
                    updatedAchievements.append(baseAchievement)
                }
            }
            
            achievements = updatedAchievements
        }
        
        // Toplam puanları hesapla
        calculateTotalPoints()
    }
    
    // Başarıları kaydet
    private func saveAchievements() {

        // --- YENİ: KODLAMADAN ÖNCE TİP KONTROLÜ ---
        logDebug("Kodlamadan önce zorunlu tarih tipi kontrolü yapılıyor...")
        for (_, achievement) in achievements.enumerated() {
            // completionDate kontrolü
            if case .completed(let date) = achievement.status {
                // date'in Date olup olmadığını kontrol etmenin en sağlam yolu `is` operatörüdür.
                // Ancak doğrudan FSTServerTimestampFieldValue tipini kontrol edemeyiz.
                // Farklı bir tip olup olmadığını anlamak için Date olmadığını kontrol edebiliriz.
                // Aslında Swift'in tip sistemi burada Date olmasını garantilemeli,
                // ama bir şekilde Timestamp sızıyorsa bu kontrol yakalayabilir.
                 if type(of: date) != Date.self {
                    let errorMessage = "!!! KRİTİK TİP HATASI !!! Başarım ID: \\(achievement.id) (index: \\(index)) - completionDate BEKLENMEDİK TÜR: \\(type(of: date))"
                     logError(errorMessage)
                     // Gerekirse burada fatalError ile uygulamayı durdurabiliriz:
                     // fatalError(errorMessage)
                 } else {
                     // logDebug("Ach ID: \\(achievement.id) - completionDate Tipi: OK (Date)") // Çok fazla log olmasın diye kapalı
                 }
            }

            // lastSyncDate kontrolü
            if let syncDate = achievement.lastSyncDate {
                 if type(of: syncDate) != Date.self {
                     let errorMessage = "!!! KRİTİK TİP HATASI !!! Başarım ID: \\(achievement.id) (index: \\(index)) - lastSyncDate BEKLENMEDİK TÜR: \\(type(of: syncDate))"
                     logError(errorMessage)
                     // fatalError(errorMessage)
                 } else {
                      // logDebug("Ach ID: \\(achievement.id) - lastSyncDate Tipi: OK (Date)") // Çok fazla log olmasın diye kapalı
                 }
            }
        }
        logDebug("Zorunlu tarih tipi kontrolü tamamlandı.")
        // --- YENİ KONTROL SONU ---


        // --- DEBUG KONTROLÜ BAŞLANGICI ---
        logDebug("UserDefaults'a kaydetmeden önce achievement tarih türleri kontrol ediliyor...")
        for achievement in achievements {
            // completionDate kontrolü (status içinden)
            if case .completed = achievement.status { // <<< DÜZELTME: Sadece case kontrolü
                // logDebug("Ach ID: \(achievement.id), completionDate type: \(type(of: date))") // logDebug kaldırıldı/yorumlandı
            }

            // lastSyncDate kontrolü
            if achievement.lastSyncDate != nil { // <<< DÜZELTME: `syncDate` yerine `!= nil` kontrolü
                // logDebug("Ach ID: \(achievement.id), lastSyncDate type: \(type(of: syncDate))") // logDebug kaldırıldı/yorumlandı
            } else {
                // logDebug("Ach ID: \(achievement.id), lastSyncDate: nil") // logDebug kaldırıldı/yorumlandı
            }
        }
        logDebug("Tarih türü kontrolü tamamlandı.")
        // --- DEBUG KONTROLÜ SONU ---

        // UserDefaults'a kaydetme - TEK TEK KODLAMA DENEMESİ
        let encoder = JSONEncoder()
        // encoder.dateEncodingStrategy = .iso8601 // Artık özel encode kullandığımız için bu stratejiye gerek yok

        var encodedAchievementsData: [Data] = [] // Başarılı kodlananları tutalım
        var encodingErrorOccurred = false

        for achievement in achievements { // <<< LOOP START >>>
             logError("### Kodlama Başlıyor: \(achievement.id)") // <<< YENİ LOG >>>
             do {
                // --- Here's the critical part ---
                // logDebug("Başarım kodlamaya başlıyor: \(achievement.id)") // REMOVED this logDebug

                let data = try encoder.encode(achievement)
                encodedAchievementsData.append(data)
                 logDebug("Başarım başarıyla kodlandı: \\(achievement.id)")
            } catch {
                // Hata durumunda hangi başarımın sorun çıkardığını logla
                logError("!!! JSON ENCODE HATASI !!! Başarım UserDefaults'a kaydedilemedi: \\(achievement.id)")
                logError("Hata Detayı: \\(error)")
                // Hatanın hangi alandan kaynaklandığını anlamak için achievement objesini de loglayabiliriz (dikkatli kullanılmalı)
                 // logError("Sorunlu Başarım Verisi: \\(achievement)") // Yorumu kaldırarak detaylı inceleme yapabilirsiniz

                // Sadece ilk hatayı raporlamak için flag ayarla ve döngüden çıkabiliriz veya devam edebiliriz
                encodingErrorOccurred = true
                // break // İlk hatada durmak isterseniz bu satırı açın
            }
        }

        // Eğer hiç hata olmadıysa tüm başarımları kaydet
        if !encodingErrorOccurred {
            // Başarılı kodlanan verileri birleştirip kaydet
            // Not: Tek tek kodlanmış verileri doğrudan bir dizi olarak kaydedemeyiz.
            // Tüm başarımları içeren diziyi tekrar kodlamamız gerekiyor.
            // Bu yüzden yukarıdaki tek tek kodlama sadece hata tespiti içindi.
            // Asıl kaydetme işlemi yine tüm dizi üzerinden yapılacak.
            do {
                // --- YENİ: DETAYLI TİP KONTROLÜ (KODLAMADAN HEMEN ÖNCE) ---
                logError("--- Kodlama Öncesi Detaylı Tip Kontrolü Başlıyor ---")
                for (_, achievement) in achievements.enumerated() { // <<< KONTROL: `index` yerine `_` zaten uygulanmış olmalı
                    var statusDateType: String = "Yok/Kilitli/İlerlemede"
                    if case .completed(let date) = achievement.status {
                        let mirror = Mirror(reflecting: date)
                        statusDateType = String(describing: mirror.subjectType)
                        if statusDateType != "Date" {
                             logError("!!! Kodlama Öncesi TİP UYARISI (status.date) !!! ID: \\(achievement.id) (Index: \\(index)), Tip: \\(statusDateType)")
                        }
                    }

                    var syncDateType: String = "nil"
                    if let syncDate = achievement.lastSyncDate {
                        let mirror = Mirror(reflecting: syncDate)
                        syncDateType = String(describing: mirror.subjectType)
                        // Optional<Date> is fine if it wraps a nil or a Date, but not if it wraps something else unexpected.
                        // However, Mirror might just show Optional<Date>. Let's log non-"Date" types within Optional too.
                        // A more robust check might involve unwrapping, but let's start simple.
                        if !syncDateType.contains("Date") && syncDateType != "nil" { // Check if "Date" is part of the type description
                            logError("!!! Kodlama Öncesi TİP UYARISI (lastSyncDate) !!! ID: \\(achievement.id) (Index: \\(index)), Tip: \\(syncDateType)")
                        }
                    }
                     // Debug: Her başarımı logla
                     // logDebug("Kontrol ID: \(achievement.id), StatusDateType: \(statusDateType), SyncDateType: \(syncDateType)")
                }
                logError("--- Kodlama Öncesi Detaylı Tip Kontrolü Tamamlandı ---")
                // --- KONTROL SONU ---

                logError("### TÜM BAŞARIMLAR DİZİSİ USERDEFAULTS İÇİN KODLANMAYA BAŞLIYOR ###") // <<< YENİ LOG >>>
                let finalData = try encoder.encode(achievements) // Tüm diziyi kodla
                logError("### TÜM BAŞARIMLAR DİZİSİ USERDEFAULTS İÇİN BAŞARIYLA KODLANDI ###") // <<< YENİ LOG >>>
                userDefaults.set(finalData, forKey: UserDefaultsKeys.achievements)
                logDebug("Tüm başarımlar UserDefaults'a başarıyla kodlandı ve kaydedildi.")
            } catch {
                 // Bu noktada hata olmaması lazım ama olursa loglayalım.
                 logError("!!! KRİTİK JSON ENCODE HATASI !!! Tüm başarımlar dizisi kaydedilemedi: \\(error)")
            }
        } else {
            logError("JSON kodlama sırasında en az bir hata oluştuğu için UserDefaults'a kaydetme işlemi atlandı.")
            // Hatalı durumda ne yapılacağına karar verilebilir (örn. eski veriyi koru, vs.)
        }


        // Toplam puanları hesapla
        calculateTotalPoints()

        // Senkronizasyon kuyruk sistemini kullanarak Firebase ile senkronize et
        queueSyncWithFirebase()

        // CoreData'ya kaydet
        if let user = Auth.auth().currentUser {
            achievementCoreDataService.saveAchievements(achievements, for: user.uid)
        }

        // UI'ın güncellenmesi için genel bir bildirim gönder
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("AchievementsUpdated"), object: nil)
        }
    }
    
    // Toplam puanları hesapla
    private func calculateTotalPoints() {
        totalPoints = achievements.reduce(0) { total, achievement in
            if achievement.isCompleted {
                return total + achievement.rewardPoints
            }
            return total
        }
    }
    
    // Başarı durumunu güncelle
    private func updateAchievement(id: String, status: AchievementStatus) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else {
            logError("updateAchievement: Başarım bulunamadı - ID: \\(id)") // Hata logu eklendi
            return
        }

        let previousStatus = achievements[index].status
        let originalAchievement = achievements[index] // Değişiklikleri takip için orijinali sakla

        // --- YENİ: TÜR KONTROLÜ (status atamasından önce) ---
        var assignedDate: Date? = nil // Atanan tarihi saklamak için
        if case .completed(let date) = status {
             assignedDate = date // Date'i değişkene al
             if type(of: date) != Date.self {
                logError("!!! updateAchievement TİP HATASI (status ataması ÖNCESİ) !!! ID: \\(id), Beklenen: Date, Gelen: \\(type(of: date))")
                // Hata durumunda belki varsayılan bir Date kullan? Şimdilik log yeterli.
                // status = .completed(unlockDate: Date()) // Güvenliğe almak için?
             } else {
                 // logDebug("updateAchievement: Status ataması öncesi tip OK (Date): \(id)")
             }
        }
        // --- KONTROL SONU ---

        // Durumu ata
        achievements[index].status = status

        // --- YENİ: TÜR KONTROLÜ (lastSyncDate atamasından önce) ---
        let currentDateForSync = Date()
        if type(of: currentDateForSync) != Date.self { // Bu kontrol gereksiz gibi görünse de ekleyelim
            logError("!!! updateAchievement TİP HATASI (lastSyncDate ataması ÖNCESİ) !!! ID: \\(id), Beklenen: Date, Gelen: \\(type(of: currentDateForSync))")
        }
        // --- KONTROL SONU ---

        // Zaman damgası güncelleme - senkronizasyon çakışması çözümlemesi için
        achievements[index].lastSyncDate = currentDateForSync // Artık hep Date() atanıyor

        // Sadece tamamlanmadıysa ve durum değiştiyse veya ilk kez tamamlandıysa devam et
        // (Durum aynı kalmışsa (örn. ilerleme aynı) gereksiz işlemler yapmayalım)
        let statusChanged = achievements[index].status != previousStatus

        if (!originalAchievement.isCompleted || statusChanged) { // Önceden tamamlanmamışsa VEYA durum değişmişse

            // Tamamlandıysa özel işlemleri yap
            if status.isCompleted && !originalAchievement.isCompleted {
                achievements[index].isUnlocked = true
                
                // --- YENİ: TÜR KONTROLÜ (completionDate atamasından ÖNCE ve SONRA) ---
                if let finalDate = assignedDate { // Yukarıda sakladığımız date'i kullan
                     if type(of: finalDate) != Date.self {
                         logError("!!! updateAchievement TİP HATASI (completionDate ataması ÖNCESİ) !!! ID: \\(id), Beklenen: Date, Gelen: \\(type(of: finalDate))")
                         achievements[index].completionDate = Date() // Güvenliğe al
                     } else {
                         achievements[index].completionDate = finalDate // Doğru tipi ata
                     }
                } else {
                    // Eğer status .completed değilse veya date nil ise (bu durum olmamalı)
                    logError("!!! updateAchievement Mantık Hatası !!! Status completed ama assignedDate nil: \(id)")
                    achievements[index].completionDate = Date() // Güvenliğe al
                }

                // Atamadan sonra tekrar kontrol et
                if let compDate = achievements[index].completionDate, type(of: compDate) != Date.self {
                    logError("!!! updateAchievement TİP HATASI (completionDate ataması SONRASI) !!! ID: \\(id), Beklenen: Date, Gelen: \\(type(of: compDate))")
                }
                // --- KONTROL SONU ---


                lastUnlockedAchievement = achievements[index]
                showAchievementAlert = true

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                // Yeni kazanılan başarımı listeye ekle
                if !newlyUnlockedAchievements.contains(where: { $0.id == achievements[index].id }) {
                    newlyUnlockedAchievements.append(achievements[index])
                }

                // Sudoku Zirve başarısını kontrol et
                checkForMasterAchievement()

                logSuccess("BAŞARIM KAZANILDI: '\\(achievements[index].name)' tamamlandı!")

                // NotificationCenter ile bildirimi hemen gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("AchievementUnlocked"),
                    object: nil,
                    userInfo: ["achievement": achievements[index]]
                )

                // CoreData'ya da kaydet (Artık saveAchievements içinde yapılıyor, burada gerek yok)
                // if let user = Auth.auth().currentUser {
                //     achievementCoreDataService.updateAchievement(achievements[index], for: user.uid)
                // }
                 logDebug("updateAchievement: \(id) tamamlandı işlemleri bitti.") // Debug log
            } else if !status.isCompleted {
                 // Eğer durum tamamlandı değilse completionDate'i nil yapalım
                 achievements[index].completionDate = nil
            }

            // Değişiklikleri kaydet (Sadece status değiştiyse veya tamamlandıysa)
            // saveAchievements() // !!! BU ÇAĞRIYI KALDIRIYORUZ !!! - processGameCompletion sonunda çağrılacak
             logDebug("updateAchievement: \(id) için değişiklikler yapıldı (veya zaten günceldi). Kaydetme işlemi processGameCompletion sonunda yapılacak.")

        } else {
             logDebug("updateAchievement: \(id) için durum değişmedi veya zaten tamamlanmıştı, işlem atlandı.")
        }
    }
    
    // Zorluk seviyesine göre başarıları güncelle
    func updateDifficultyAchievements(difficulty: SudokuBoard.Difficulty) {
        var prefixId: String
        
        switch difficulty {
        case .easy:
            prefixId = "easy_"
            logInfo("Kolay seviye başarım kontrolü - prefix: \(prefixId)")
        case .medium:
            prefixId = "medium_"
            logInfo("Orta seviye başarım kontrolü - prefix: \(prefixId)")
        case .hard:
            prefixId = "hard_"
            logInfo("Zor seviye başarım kontrolü - prefix: \(prefixId)")
        case .expert:
            prefixId = "expert_"
            logInfo("Uzman seviye başarım kontrolü - prefix: \(prefixId)")
        }
        
        // İlgili prefixe sahip başarımları listele
        let relatedAchievements = achievements.filter { $0.id.hasPrefix(prefixId) }
        logInfo("\(prefixId) prefixli \(relatedAchievements.count) başarım bulundu")
        
        // Her zorluk seviyesi başarısını kontrol et
        for achievement in achievements where achievement.id.hasPrefix(prefixId) {
            // Mevcut durumu al
            let currentStatus = achievement.status
            var newStatus: AchievementStatus
            
            switch currentStatus {
            case .locked:
                // Başlat
                newStatus = .inProgress(currentValue: 1, requiredValue: achievement.targetValue)
                logInfo("'\(achievement.name)' başarımı başlatılıyor - 1/\(achievement.targetValue)")
                
                // Eğer hedef değeri 1 ise, direkt tamamlandı olarak işaretle
                if achievement.targetValue == 1 {
                    newStatus = .completed(unlockDate: Date())
                    logInfo("'\(achievement.name)' başarımı direkt tamamlandı - 1/1 (100%)")
                }
            case .inProgress(let current, let required):
                let newCount = current + 1
                if newCount >= required {
                    // Tamamla
                    newStatus = .completed(unlockDate: Date())
                    logInfo("'\(achievement.name)' başarımı tamamlandı - \(newCount)/\(required)")
                } else {
                    // İlerlet
                    newStatus = .inProgress(currentValue: newCount, requiredValue: required)
                    logInfo("'\(achievement.name)' başarımı ilerledi - \(newCount)/\(required)")
                }
            case .completed:
                // Zaten tamamlanmış
                logInfo("'\(achievement.name)' başarımı zaten tamamlanmış")
                continue
            }
            
            // Başarıyı güncelle
            updateAchievement(id: achievement.id, status: newStatus)
        }
        
        // "Tam Set" başarısını kontrol et
        checkAllDifficultiesAchievement()
    }
    
    // Tüm zorluk seviyelerini tamamladı mı kontrol et
    private func checkAllDifficultiesAchievement() {
        let completedDifficulties = Set(["easy_1", "medium_1", "hard_1", "expert_1"]).filter { id in
            if let achievement = achievements.first(where: { $0.id == id }) {
                return achievement.isCompleted
            }
            return false
        }
        
        if completedDifficulties.count >= 4 {
            // Tam Set başarısını aç
            updateAchievement(id: "all_difficulties", status: .completed(unlockDate: Date()))
        } else if completedDifficulties.count > 0 {
            // İlerleme kaydet
            updateAchievement(id: "all_difficulties", status: .inProgress(
                currentValue: completedDifficulties.count,
                requiredValue: 4
            ))
        }
    }
    
    // Zaman başarılarını güncelle
    func updateTimeAchievements(difficulty: SudokuBoard.Difficulty, time: TimeInterval) {
        let timeInMinutes = time / 60.0
        
        switch difficulty {
        case .easy:
            if timeInMinutes < 3.0 {
                updateAchievement(id: "time_easy_3", status: .completed(unlockDate: Date()))
            }
        case .medium:
            if timeInMinutes < 5.0 {
                updateAchievement(id: "time_medium_5", status: .completed(unlockDate: Date()))
            }
        case .hard:
            if timeInMinutes < 10.0 {
                updateAchievement(id: "time_hard_10", status: .completed(unlockDate: Date()))
            }
        default:
            break
        }
    }
    
    // Özel başarıları güncelle
    func updateSpecialAchievements(errorCount: Int, hintCount: Int) {
        // Hatasız oyun
        if errorCount == 0 {
            updateAchievement(id: "no_errors", status: .completed(unlockDate: Date()))
            logDebug("Kusursuz başarımı tamamlandı - hatasız oyun")
        }
        
        // İpuçsuz oyun
        if hintCount == 0 {
            updateAchievement(id: "no_hints", status: .completed(unlockDate: Date()))
            logDebug("Yardımsız başarımı tamamlandı - ipuçsuz oyun")
            logDebug("'Yardımsız' başarımı tamamlandı - ipuçsuz oyun")
        }
    }
    
    // Oyun tamamlandığında tüm başarıları güncelle
    func processGameCompletion(difficulty: SudokuBoard.Difficulty, time: TimeInterval, errorCount: Int, hintCount: Int) {
        logInfo("BAŞARIM - Oyun tamamlandı: \(difficulty.rawValue) zorluk, \(time) süre, \(errorCount) hata, \(hintCount) ipucu")
        
        // Zorluk başarıları
        updateDifficultyAchievements(difficulty: difficulty)
        
        // Zaman başarıları
        updateTimeAchievements(difficulty: difficulty, time: time)
        
        // Özel başarılar
        updateSpecialAchievements(errorCount: errorCount, hintCount: hintCount)
        
        // Günlük oyun sayısı başarıları
        updateDailyCompletionAchievements()
        
        // Gün zamanına göre başarımlar
        updateTimeOfDayAchievements()
        
        // Hafta sonu başarımları
        updateWeekendAchievements()
        
        // Toplam tamamlanan oyun sayısı başarımları
        updateTotalCompletionAchievements()
        
        // Çeşitlilik başarısını kontrol et
        checkPuzzleVarietyAchievement()
        
        // Özel saat başarımları
        checkSpecialTimeAchievements()
        
        // YENİ: Mevsimsel başarımları kontrol et
        checkSeasonalAchievements()
        
        // YENİ: Saat dilimi başarımları
        checkClockBasedAchievements()
        
        // YENİ: Hızlı tamamlama başarımları
        checkSpeedAchievements(difficulty: difficulty, time: time)
        
        // YENİ: Hatasız seri başarımları
        checkPerfectComboAchievements(errorCount: errorCount)
        
        // YENİ: Hız seri başarımlarını kontrol et
        checkSpeedComboAchievements(time: time)
        
        // YENİ: Hafta içi başarımları
        checkWeekdayAchievements()
        
        // YENİ: Oyun stili başarımları
        checkGameStyleAchievements(hintCount: hintCount, errorCount: errorCount)
        
        // YENİ: Hücre tamamlama başarımları
        updateCellsCompletedAchievements()
        
        // YENİ: Özel gün başarımları
        checkSpecialDayAchievements()
        
        // İşlem bitince tüm yeni başarımları bildir
        if !newlyUnlockedAchievements.isEmpty {
            // NotificationCenter üzerinden başarımları bildir
            NotificationCenter.default.post(
                name: NSNotification.Name("NewAchievementsUnlocked"),
                object: nil,
                userInfo: ["achievements": newlyUnlockedAchievements]
            )
        }
        
        // Tüm başarımların durumunu göster
        printAchievementStatus()
        
        // Tüm güncellemeler bittikten sonra değişiklikleri kaydet
        saveAchievements()
    }
    
    // DEBUG: Başarım durumlarını yazdır
    private func printAchievementStatus() {
        logInfo("Mevcut başarım durumları:")
        
        // Kategoriye göre başarımları grupla
        Dictionary(grouping: achievements, by: { $0.category }).sorted { $0.key.rawValue < $1.key.rawValue }.forEach { category, achievements in
            logInfo("  Kategori: \(category.rawValue)")
            
            // Her başarım için durum göster
            achievements.sorted { $0.id < $1.id }.forEach { achievement in
                var statusText = ""
                switch achievement.status {
                case .locked:
                    statusText = "🔒 Kilitli"
                case .inProgress(let current, let required):
                    statusText = "🔄 İlerleme: \(current)/\(required) (\(Int(achievement.progress * 100))%)"
                case .completed(let date):
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    statusText = "✅ Tamamlandı: \(formatter.string(from: date))"
                }
                logInfo("    - \(achievement.name): \(statusText)")
            }
        }
    }
    
    // Günlük oyun sayısını takip etme
    private func updateDailyCompletionAchievements() {
        // Artık User entity'sindeki dailyCompletionCount ve lastCompletionDateForDailyCount kullanılacak.
        guard let firebaseUID = Auth.auth().currentUser?.uid else { return }

        let calendar = Calendar.current
        let today = Date()
        // let todayStart = calendar.startOfDay(for: today) // Removed unused variable

        // Core Data'dan mevcut verileri al
        let dailyData = persistenceController.getUserDailyCompletionData(for: firebaseUID)
        let lastCompletionDate = dailyData?.lastDate
        var currentCount = dailyData?.count ?? 0

        if let lastDate = lastCompletionDate, calendar.isDate(lastDate, inSameDayAs: today) {
            // Aynı gün, sayacı artır
            currentCount += 1
        } else {
            // Yeni gün veya ilk oyun, sayacı sıfırla
            currentCount = 1
        }

        // Core Data'yı güncelle
        persistenceController.updateUserDailyCompletionData(for: firebaseUID, count: currentCount, date: today)
        logInfo("Günlük Tamamlama Sayacı (Core Data): \(currentCount) (Tarih: \(today))")

        // Günlük başarımları kontrol et (Bu fonksiyon zaten currentValue kullanıyor)
        checkDailyGameCountAchievements(count: currentCount)
    }

    // Günlük oyun sayısı başarımlarını kontrol et
    private func checkDailyGameCountAchievements(count: Int) {
        // Günlük 5 oyun
        updateAchievementProgress(id: "daily_5", currentProgress: count)
        // Günlük 10 oyun
        updateAchievementProgress(id: "daily_10", currentProgress: count)
        // Günlük 20 oyun
        updateAchievementProgress(id: "daily_20", currentProgress: count)
        // Günlük 30 oyun
        updateAchievementProgress(id: "daily_30", currentProgress: count)
    }

    // Hafta sonu başarımlarını güncelle
    private func updateWeekendAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        // Cumartesi (7) veya Pazar (1) günleri
        let isWeekend = weekday == 1 || weekday == 7

        if isWeekend {
            // Artık User entity'sindeki weekendCompletionCount ve lastCompletionDateForWeekendCount kullanılacak.
            guard let firebaseUID = Auth.auth().currentUser?.uid else { return }

            // Core Data'dan mevcut verileri al
            let weekendData = persistenceController.getUserWeekendCompletionData(for: firebaseUID)
            let lastCompletionDate = weekendData?.lastDate
            var currentWeekendCount = weekendData?.count ?? 0

            let currentWeekOfYear = calendar.component(.weekOfYear, from: today)
            let currentYear = calendar.component(.year, from: today)

            var lastWeekOfYear = 0
            var lastYear = 0
            if let lastDate = lastCompletionDate {
                lastWeekOfYear = calendar.component(.weekOfYear, from: lastDate)
                lastYear = calendar.component(.year, from: lastDate)
            }

            // Aynı hafta sonu mu kontrol et (yıl ve hafta numarası aynı olmalı)
            if lastCompletionDate != nil && currentYear == lastYear && currentWeekOfYear == lastWeekOfYear {
                // Aynı hafta sonu, sayacı artır
                currentWeekendCount += 1
            } else {
                // Yeni hafta sonu veya ilk oyun, sayacı sıfırla
                currentWeekendCount = 1
            }

            // Core Data'yı güncelle
            persistenceController.updateUserWeekendCompletionData(for: firebaseUID, count: currentWeekendCount, date: today)
            logInfo("Hafta Sonu Tamamlama Sayacı (Core Data): \(currentWeekendCount) (Yıl: \(currentYear), Hafta: \(currentWeekOfYear))")

            // Hafta sonu başarımları kontrol et (Bu fonksiyon zaten currentValue kullanıyor)
            updateAchievementProgress(id: "weekend_warrior", currentProgress: currentWeekendCount) // 15 oyun
            updateAchievementProgress(id: "weekend_master", currentProgress: currentWeekendCount) // 30 oyun
            updateAchievementProgress(id: "holiday_weekend", currentProgress: currentWeekendCount) // 20 oyun (Özel gün başarımı)
        }
    }


    // Günlük görevleri sıfırla
    private func resetDailyAchievements() {
        // Günlük başarımların AchievementEntity.currentValue'larını sıfırlıyoruz.
        logInfo("Günlük başarım ilerlemeleri sıfırlanıyor...")
        for id in ["daily_5", "daily_10", "daily_20", "daily_30"] {
            if let achievement = achievements.first(where: { $0.id == id }), !achievement.isCompleted {
                logInfo("Sıfırlanıyor: \(id)")
                updateAchievementProgress(id: id, currentProgress: 0)
            }
        }
        // Artık User entity'sindeki sayaç burada sıfırlanmıyor.
        // Sayaç, yeni bir güne girildiğinde updateDailyCompletionAchievements içinde otomatik sıfırlanacak.
        // UserDefaults temizliği kaldırıldı.
        // userDefaults.removeObject(forKey: "games_completed_today_count")
        // userDefaults.removeObject(forKey: "games_completed_date_str")

        logInfo("Günlük başarım ilerlemeleri sıfırlandı.")
    }
    
    // Streak başarılarını güncelle
    private func updateStreakAchievements(streak: Int) {
        for achievement in achievements where achievement.id.hasPrefix("streak_") {
            if let requiredStreak = Int(achievement.id.split(separator: "_")[1]), streak >= requiredStreak {
                updateAchievement(id: achievement.id, status: .completed(unlockDate: Date()))
            } else if !achievement.isCompleted {
                updateAchievement(id: achievement.id, status: .inProgress(
                    currentValue: streak,
                    requiredValue: achievement.targetValue
                ))
            }
        }
    }
    
    // Firebase için başarıları kodla
    private func encodeAchievementsForFirebase() -> [[String: Any]] {
        // Önce zorunlu tarih tipi kontrolü
        for achievement in achievements {
            // Completion date kontrolü
            if case .completed(_) = achievement.status {
                // Date zaten Date türünde olduğu için kontrol etmeye gerek yok
                // logDebug("Tamamlanma tarihi: \(unlockDate) - \(achievement.id)")
            }
            
            // LastSyncDate kontrolü
            if achievement.lastSyncDate != nil {
                // Date zaten Date türünde olduğu için kontrol etmeye gerek yok
                // logDebug("Senkronizasyon tarihi: \(syncDate) - \(achievement.id)")
            }
        }
        
        return achievements.map { achievement in
            var achievementDict: [String: Any] = [
                "id": achievement.id,
                "name": achievement.name,
                "description": achievement.description,
                "category": achievement.category.rawValue,
                "iconName": achievement.iconName,
                "targetValue": achievement.targetValue,
                "pointValue": achievement.pointValue,
                "isCompleted": achievement.isCompleted
            ]
            
            switch achievement.status {
            case .locked:
                achievementDict["status"] = "locked"
                achievementDict["progress"] = 0
                achievementDict["currentValue"] = 0
                achievementDict["requiredValue"] = achievement.targetValue
            case .inProgress(let current, let required):
                achievementDict["status"] = "inProgress"
                achievementDict["progress"] = Double(current) / Double(required)
                achievementDict["currentValue"] = current
                achievementDict["requiredValue"] = required
            case .completed(let date):
                achievementDict["status"] = "completed"
                achievementDict["progress"] = 1.0
                
                // GÜVENLİ TIMESTAMP DÖNÜŞÜMÜ - safeTimestampFromDate kullanımı
                achievementDict["unlockDate"] = safeTimestampFromDate(date)
                
                // Hata ayıklama için
                logDebug("Başarım \(achievement.id) için tarih Timestamp'e çevrildi: \(date)")
                
                achievementDict["currentValue"] = achievement.targetValue
                achievementDict["requiredValue"] = achievement.targetValue
            }
            
            // lastSyncDate alanını da ekleyelim (firebase için) - GÜVENLİ DÖNÜŞÜM
            if let lastSyncDate = achievement.lastSyncDate {
                achievementDict["lastSyncDate"] = safeTimestampFromDate(lastSyncDate)
            }
            
            // completionDate alanını da ekleyelim (firebase için) - GÜVENLİ DÖNÜŞÜM
            if let completionDate = achievement.completionDate {
                achievementDict["completionDate"] = safeTimestampFromDate(completionDate)
            }
            
            return achievementDict
        }
    }
    
    // YENİ EKLENEN FONKSİYON - Date -> Timestamp güvenli dönüşüm
    private func safeTimestampFromDate(_ date: Date) -> Timestamp {
        // Date geçerli mi kontrol et
        let validDate: Date
        if date.timeIntervalSince1970 < 0 || date.timeIntervalSince1970 > Date().timeIntervalSince1970 + 86400*365*10 { // 10 yıl
            // Geçersiz tarih, bugünün tarihini kullan
            validDate = Date()
            logWarning("Geçersiz tarih düzeltildi: \(date) -> \(validDate)")
        } else {
            validDate = date
        }
        
        return Timestamp(date: validDate)
    }
    
    // Firestore'a başarımları senkronize et
    // MARK: - Senkronizasyon İyileştirmeleri
    
    // İnternet bağlantısı değişikliği bildirimi
    @objc private func handleNetworkConnectivityChange(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool, isConnected {
            logInfo("İnternet bağlantısı tespit edildi - Bekleyen başarımlar senkronize ediliyor")
            processPendingSyncQueue() // Bağlantı geldiğinde bekleyen senkronizasyonları işle
        }
    }
    
    // Bekleyen senkronizasyon kuyruğu yükleme
    private func loadPendingSyncQueue() {
        if let data = userDefaults.data(forKey: pendingSyncKey),
           let pendingQueue = try? JSONDecoder().decode([String].self, from: data) {
            self.pendingSyncQueue = pendingQueue
            logInfo("Bekleyen senkronizasyon kuyruğu yüklendi: \(pendingQueue.count) başarım")
            
            // İlk başlatmada bekleyen senkronizasyonları işlemeyi dene -> ARTIK BURADA ÇAĞIRMIYORUZ
            // if !pendingQueue.isEmpty {
            //     DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            //         self?.processPendingSyncQueue()
            //     }
            // }
        }
    }
    
    // Başarım ID'sini bekleyen senkronizasyon kuyruğuna ekle
    private func addToPendingSyncQueue(_ achievementID: String) {
        // Zaten kuyrukta yoksa ekle
        if !pendingSyncQueue.contains(achievementID) {
            pendingSyncQueue.append(achievementID)
            savePendingSyncQueue()
            logInfo("Başarım senkronizasyon kuyruğuna eklendi: \(achievementID)")
        }
        
        // Hemen işlemeyi dene
        processPendingSyncQueue() // Eğer internet varsa ve sync çalışmıyorsa hemen senkronize etmeyi dene
    }
    
    // Kuyruk sistemini kullanarak senkronizasyon yapma
    private func queueSyncWithFirebase() {
        // Tüm başarımlar için genel bir ID kullan
        addToPendingSyncQueue("ALL_ACHIEVEMENTS")
    }
    
    // Bekleyen senkronizasyon kuyruğunu kaydet
    private func savePendingSyncQueue() {
        if let data = try? JSONEncoder().encode(pendingSyncQueue) {
            userDefaults.set(data, forKey: pendingSyncKey)
        }
    }
    
    // Bekleyen başarımları senkronize etmeyi dene
    private func processPendingSyncQueue() {
        // Zaten işleniyorsa çık
        if isCurrentlySync || pendingSyncQueue.isEmpty {
            return
        }
        
        // Kullanıcı oturum açmış mı kontrol et
        guard Auth.auth().currentUser != nil else {
            logWarning("Senkronizasyon yapılamıyor: Kullanıcı oturum açmamış")
            return
        }
        
        // İnternet bağlantısı var mı kontrol et
        if !NetworkMonitor.shared.isConnected {
            logError("Senkronizasyon yapılamıyor: İnternet bağlantısı yok")
            return
        }
        
        // İşleme durumunu ayarla
        isCurrentlySync = true
        logInfo("Bekleyen senkronizasyonlar işleniyor: \(pendingSyncQueue.count) adet")
        
        // Firebase ile senkronize et - tüm başarımları bir kerede gönder
        syncWithFirebase(completionHandler: { [weak self] success in
            guard let self = self else { return }
            self.isCurrentlySync = false
            
            if success {
                // Başarılı ise kuyruğu temizle
                logSuccess("🔥 Firebase senkronizasyonu BAŞARILI oldu! Kuyruk temizleniyor.")
                self.pendingSyncQueue.removeAll()
                self.savePendingSyncQueue()
                logSuccess("Bekleyen tüm başarımlar başarıyla senkronize edildi")
                
                // UI'ın güncellenmesi için genel bir bildirim gönder
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("AchievementsSyncCompleted"), object: nil, userInfo: ["success": true])
                }
            } else {
                logError("❌ Firebase senkronizasyonu BAŞARISIZ oldu! Daha sonra tekrar denenecek.")
                logError("Başarımlar senkronize edilemedi, daha sonra tekrar denenecek")
                
                // UI'ın güncellenmesi için genel bir bildirim gönder
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("AchievementsSyncCompleted"), object: nil, userInfo: ["success": false])
                }
            }
        })
    }
    
    // Ana senkronizasyon fonksiyonu - tamamlama işleyicisi eklendi
    func syncWithFirebase(completionHandler: ((Bool) -> Void)? = nil) {
        guard let user = Auth.auth().currentUser else { 
            logWarning("Başarımlar kaydedilemiyor: Kullanıcı oturum açmamış")
            completionHandler?(false)
            return 
        }
        
        logInfo("Başarımlar Firebase'e senkronize ediliyor...")
        
        // Tüm başarımlar için toplu veri hazırla
        let achievementsData = encodeAchievementsForFirebase()
        
        // ÖNEMLİ: Senkronizasyon başarı takibi için yeni değişkenler
        var batchSuccess = false
        var legacySuccess = false
        var legacyCompleted = false
        
        // Önce kullanıcı belgesi var mı kontrol et
        db.collection("users").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { 
                completionHandler?(false)
                return
            }
            
            if let error = error {
                logError("Firebase belgesi kontrol edilemedi: \(error.localizedDescription)")
                completionHandler?(false)
                return
            }
            
            // Yeni yapı: Başarımları kategorilere göre grupla
            let userAchievementsRef = self.db.collection("userAchievements").document(user.uid)
            let batch = self.db.batch()
            
            // Başarımları kategorilerine göre grupla
            var categorizedAchievements: [String: [[String: Any]]] = [
                "easy": [],
                "medium": [],
                "hard": [],
                "expert": [],
                "streak": [],
                "time": [],
                "special": []
            ]
            
            // Başarımları kategorilere ayır
            for achievementData in achievementsData {
                guard let id = achievementData["id"] as? String,
                      let categoryName = achievementData["category"] as? String else { 
                    logWarning("Kategorileme hatası - kategori bilgisi eksik: \(achievementData["id"] ?? "bilinmeyen")")
                    continue 
                }
                
                // Achievement.swift'teki kategori adları ile Firestore kategori anahtarları eşleşmiyor, eşleştirme yapalım
                let firestoreCategory: String
                switch categoryName {
                case "Başlangıç": firestoreCategory = "easy"
                case "Orta Seviye": firestoreCategory = "medium"
                case "Uzman": firestoreCategory = "expert"
                case "Seri": firestoreCategory = "streak"
                case "Zaman": firestoreCategory = "time"
                case "Zorluk": firestoreCategory = "difficulty"
                case "Özel": firestoreCategory = "special"
                default: firestoreCategory = "special"
                }
                
                if categorizedAchievements.keys.contains(firestoreCategory) {
                    categorizedAchievements[firestoreCategory]?.append(achievementData)
                    logDebug("Başarım kategorisi eşleşti: \(id) -> \(firestoreCategory)")
            } else {
                    // Bilinmeyen kategoriler için "special" kategorisini kullan
                    categorizedAchievements["special"]?.append(achievementData)
                    logWarning("Bilinmeyen kategori: \(categoryName) -> 'special' kullanıldı")
                }
            }
            
            // Her kategori için ayrı bir belge oluştur
            for (category, achievements) in categorizedAchievements {
                if !achievements.isEmpty {
                    // Kategori adını Firestore için güvenli hale getir
                    let safeCategory = category.replacingOccurrences(of: " ", with: "_")
                                      .replacingOccurrences(of: "/", with: "_")
                                      .replacingOccurrences(of: ".", with: "_")
                    
                    let categoryRef = userAchievementsRef.collection("categories").document(safeCategory)
                    batch.setData([
                        "achievements": achievements,
                        "lastUpdated": FieldValue.serverTimestamp(),
                        "count": achievements.count,
                        "originalCategory": category // Orijinal kategori adını da saklayalım
                    ], forDocument: categoryRef)
                }
            }
            
            // Toplam puanlar ve diğer bilgileri ana belgeye kaydet
            let categoryKeys = ["easy", "medium", "hard", "expert", "streak", "time", "special", "difficulty"]
            let usedCategories = categoryKeys.filter { key in
                return (categorizedAchievements[key]?.count ?? 0) > 0
            }
            
            let summaryData: [String: Any] = [
                "totalPoints": self.totalPoints,
                "lastSyncDate": FieldValue.serverTimestamp(),
                "userId": user.uid,
                "categories": usedCategories
            ]
            batch.setData(summaryData, forDocument: userAchievementsRef)
            
            // Batch işlemini uygula
            batch.commit { error in
                if let error = error {
                    logError("Başarımlar Firestore'a kaydedilemedi: \(error.localizedDescription)")
                    batchSuccess = false
                    
                    // Her iki yazma işlemi tamamlanmışsa completion handler'ı çağır
                    if legacyCompleted {
                        completionHandler?(false)
                    }
                } else {
                    logSuccess("Başarımlar Firestore'a kaydedildi (Kategori Modeli)")
                    batchSuccess = true
                    
                    // Eğer legacy kısım completion handler'ı çağırdıysa (veya atlandıysa), 
                    // final completion handler'ı burada çağır
                    if legacyCompleted {
                        completionHandler?(batchSuccess && legacySuccess)
                    }
                }
            }
            
            // Eski yapıyı da desteklemek için kullanıcı belgesini güncelle
            if let document = document, document.exists {
                // Belge varsa sadece başarım alanlarını güncelle, diğer alanları koruyarak
                let achievementUpdateData: [String: Any] = [
                    "achievements": achievementsData,
                    "totalPoints": self.totalPoints,
                    "lastSyncDate": FieldValue.serverTimestamp(),
                    "lastUpdated": FieldValue.serverTimestamp()
                ]
                
                self.db.collection("users").document(user.uid).updateData(achievementUpdateData) { error in
                    legacyCompleted = true
                    
                    if let error = error {
                        logError("Başarımlar Firestore kullanıcı belgesine kaydedilemedi: \(error.localizedDescription)")
                        legacySuccess = false
                        
                        // Eğer batch işlemi tamamlandıysa ve hata verdiyse, false dön
                        if batchSuccess == true {
                            completionHandler?(false)
                        }
                    } else {
                        logSuccess("Başarımlar Firestore kullanıcı belgesine de kaydedildi (Geriye uyumluluk)")
                        legacySuccess = true
                        
                        // Eğer batch işlemi tamamlandıysa, her ikisinin başarı durumunu değerlendir
                        if batchSuccess == true {
                            completionHandler?(true)
                        }
                    }
                }
            } else {
                // Belge yoksa, önce kullanıcı profilini al, sonra başarımları ekle
                Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: true) { tokenResult, error in
                    if let error = error {
                        logError("Token doğrulama hatası: \(error.localizedDescription)")
                        legacyCompleted = true
                        legacySuccess = false
                        
                        if batchSuccess == true {
                            completionHandler?(false)
                        }
                        return
                    }
                    
                    // Kullanıcı profil bilgilerini al
                    let userProfile: [String: Any] = [
                        "email": Auth.auth().currentUser?.email ?? "",
                        "name": Auth.auth().currentUser?.displayName ?? "",
                        "isLoggedIn": true,
                        "achievements": achievementsData,
                        "totalPoints": self.totalPoints,
                        "lastSyncDate": FieldValue.serverTimestamp(),
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]
                    
                    // Belgeyi güncelle
                    self.db.collection("users").document(user.uid).setData(userProfile, merge: true) { error in
                        legacyCompleted = true
                        
                        if let error = error {
                            logError("Başarımlar Firestore kullanıcı belgesine kaydedilemedi: \(error.localizedDescription)")
                            legacySuccess = false
                            
                            // Batch işlemi tamamlandıysa, genel durumu bildir
                            if batchSuccess == true {
                                completionHandler?(false)
                            }
                        } else {
                            logSuccess("Başarımlar Firestore kullanıcı belgesine de kaydedildi (Geriye uyumluluk)")
                            legacySuccess = true
                            
                            // Batch işlemi tamamlandıysa, genel durumu bildir
                            if batchSuccess == true {
                                completionHandler?(true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Firebase'den başarımları yükle - Completion Handler Eklendi
    func loadAchievementsFromFirebase(completion: @escaping (Bool) -> Void) { // <<< Completion eklendi
        logInfo("[ACH_FIREBASE_LOAD] Starting loadAchievementsFromFirebase...") // BAŞLANGIÇ
        // Giriş yapmış kullanıcı kontrolü
        guard let user = Auth.auth().currentUser else {
            logError("[ACH_FIREBASE_LOAD] Failed: User not logged in.") // HATA: Kullanıcı yok
            completion(false) // <<< Başarısızlık bildir
            return
        }
        logInfo("[ACH_FIREBASE_LOAD] User confirmed: \\(user.uid)") // Kullanıcı OK

        logInfo("Firebase\\'den başarımlar yükleniyor...")

        // Firestore\\'dan başarımları al - doğru koleksiyon adını kullan
        let userAchievementsRef = db.collection("userAchievements").document(user.uid)

        userAchievementsRef.getDocument { [weak self] document, error in
            guard let self = self else {
                logError("[ACH_FIREBASE_LOAD] Failed: self is nil.") // HATA: Self nil
                completion(false) // Self yoksa başarısız
                return
            }

            if let error = error {
                logError("[ACH_FIREBASE_LOAD] Error getting user document: \(error.localizedDescription)") // HATA: Belge alınamadı
                // Hata durumunda CoreData'dan yüklemeyi dene
                self.loadFromCoreDataBackup(for: user.uid)
                completion(false) // <<< Hata durumunda başarısızlık bildir
                return
            }

            if let document = document, document.exists {
                // String interpolation düzeltildi
                let categories = document.data()?["categories"] as? [String] ?? []
                logInfo("[ACH_FIREBASE_LOAD] User document exists. Categories: \\(categories)") // Belge VAR
                // Ana belge varsa kategorileri kontrol et
                // let categories = document.data()?["categories"] as? [String] ?? [] // Tekrarlanan satır kaldırıldı

                if categories.isEmpty {
                    logWarning("[ACH_FIREBASE_LOAD] Categories array is empty in user document. Trying old structure...") // Kategoriler boş/yok
                    // Eski veriyi yüklemeyi dene
                    self.tryLoadingOldFirebaseStructure(userID: user.uid, completion: completion)
                    return // Eski yapı yüklemesi kendi completion'ını çağıracak
                }

                logInfo("Firebase\\'de \\(categories.count) başarım kategorisi bulundu")

                var loadedFirebaseAchievements: [[String: Any]] = []
                let categoriesGroup = DispatchGroup()
                var categoryLoadErrors = 0

                // Her kategori için yükleme işlemi
                for category in categories {
                    categoriesGroup.enter()
                    logInfo("[ACH_FIREBASE_LOAD] Loading category: \\(category)") // Kategori yükleme BAŞLADI
                    userAchievementsRef.collection("categories").document(category).getDocument { categoryDoc, categoryError in
                        defer {
                             logInfo("[ACH_FIREBASE_LOAD] Leaving dispatch group for category: \\(category)") // Grup bırakıldı
                             categoriesGroup.leave()
                        } // Her durumda leave çağrılmasını garantile
                        if let categoryError = categoryError { // _ -> categoryError
                            logError("[ACH_FIREBASE_LOAD] Error loading category \(category): \(categoryError.localizedDescription)") // Kategori HATA
                            categoryLoadErrors += 1
                            return
                        }

                        if let categoryDoc = categoryDoc, categoryDoc.exists,
                           let achievements = categoryDoc.data()?["achievements"] as? [[String: Any]] {
                            logInfo("[ACH_FIREBASE_LOAD] Successfully loaded \\(achievements.count) achievements for category: \\(category)") // Kategori OK
                            loadedFirebaseAchievements.append(contentsOf: achievements)
                        } else {
                             logWarning("[ACH_FIREBASE_LOAD] Category document \\(category) not found or empty.") // Kategori Belgesi YOK/BOŞ
                        }
                    }
                }

                // Tüm kategori yüklemeleri bittiğinde
                categoriesGroup.notify(queue: .main) {
                    if categoryLoadErrors > 0 {
                        logError("[ACH_FIREBASE_LOAD] Finished loading categories with \\(categoryLoadErrors) errors.") // Kategori HATALARI
                    } else {
                        logSuccess("[ACH_FIREBASE_LOAD] Finished loading categories successfully.") // Kategori OK
                    }
                    logInfo("[ACH_FIREBASE_LOAD] Calling updateAchievementsFromFirebase with \\(loadedFirebaseAchievements.count) achievements.") // Güncelleme ÇAĞRISI
                    self.updateAchievementsFromFirebase(loadedFirebaseAchievements)
                    // Başarılı yükleme sonrası CoreData'ya yedekle - DOĞRU FONKSİYON KULLANILDI
                    self.achievementCoreDataService.saveAchievements(self.achievements, for: user.uid)
                    logSuccess("[ACH_FIREBASE_LOAD] Finished successfully (New Structure). Calling completion(true).") // BİTTİ (Yeni)
                    completion(true)
                }
            } else {
                 logWarning("[ACH_FIREBASE_LOAD] User document not found in userAchievements collection for user \\(user.uid). Trying old structure...") // Belge YOK (Yeni)
                // Eski koleksiyondan (users) veri yüklemeyi dene
                self.tryLoadingOldFirebaseStructure(userID: user.uid, completion: completion)
            }
        }
    }

    // Yardımcı fonksiyon: Eski Firebase yapısını yüklemeyi dene
    private func tryLoadingOldFirebaseStructure(userID: String, completion: @escaping (Bool) -> Void) {
        logInfo("[ACH_FIREBASE_LOAD_OLD] Starting tryLoadingOldFirebaseStructure for user \\(userID)...") // BAŞLANGIÇ (Eski)
        self.db.collection("users").document(userID).getDocument { [weak self] (document, error) in
            guard let self = self else {
                logError("[ACH_FIREBASE_LOAD_OLD] Failed: self is nil.") // HATA: Self nil (Eski)
                completion(false)
                return
            }

                    if error != nil {
                        logError("[ACH_FIREBASE_LOAD_OLD] Error getting document from 'users' collection: \(error!.localizedDescription)") // HATA: Belge alınamadı (Eski)
                self.loadFromCoreDataBackup(for: userID)
                logInfo("[ACH_FIREBASE_LOAD_OLD] Finished unsuccessfully (Error fetching old structure). Calling completion(false).") // BİTTİ (Eski - Hata)
                completion(false) // Eski yapı yüklenemedi
                        return
                    }

                    if let document = document, document.exists,
                       let achievementsData = document.data()?["achievements"] as? [[String: Any]], !achievementsData.isEmpty {
                        logInfo("[ACH_FIREBASE_LOAD_OLD] Old structure data found in 'users' collection (\\(achievementsData.count) achievements). Updating and syncing to new structure...") // Eski Veri VAR
                        self.updateAchievementsFromFirebase(achievementsData)
                        // Başarılı yükleme sonrası CoreData'ya yedekle - DOĞRU FONKSİYON KULLANILDI
                        self.achievementCoreDataService.saveAchievements(self.achievements, for: userID)
                        logSuccess("Eski yapıdan başarımlar güncellendi, yeni yapıya senkronize ediliyor...")
                // Yeni yapıya senkronize et ve sonucu bildir
                self.syncWithFirebase { success in
                    logInfo("[ACH_FIREBASE_LOAD_OLD] Sync after loading old structure finished with success: \\(success). Calling completion(\\(success)).") // ESKİ -> YENİ Senkronizasyon BİTTİ
                    completion(success) // Yeni yapıya senkronizasyonun sonucunu bildir
                }
                    } else {
                logWarning("[ACH_FIREBASE_LOAD_OLD] No data found in 'users' collection or achievements array is empty for user \\(userID). Loading from CoreData backup.") // Eski Veri YOK
                self.loadFromCoreDataBackup(for: userID)
                logInfo("[ACH_FIREBASE_LOAD_OLD] Finished unsuccessfully (Old Structure not found or empty). Calling completion(false).") // BİTTİ (Eski - Başarısız)
                completion(false)
            }
        }
    }
    
    // Başarı verilerini sıfırlama fonksiyonu
    @objc private func resetAchievementsData() {
        logInfo("AchievementManager: Başarı verilerini sıfırlama bildirimi alındı")
        
        // Başarıları ilk durumlarına sıfırla
        setupAchievements()
        
        // Toplam puanları sıfırla
        totalPoints = 0
        
        // UserDefaults'taki sayaçları temizle (ilgili anahtarları silerek)
        let counterKeys = [
            "games_completed_date_str", "games_completed_today_count",
            "weekend_games_date_str", "weekend_games_count",
            "perfect_combo_count", "last_game_time", "speed_combo_count",
            "total_cells_completed",
            "weekend_warrior_date", "weekend_warrior_count"
            // Özel zaman/gün sayaçları
        ] + achievements.filter { $0.category == .special || $0.category == .time }.map { "\($0.id)_count" }
          + achievements.filter { $0.category == .special || $0.category == .time }.map { "\($0.id)_progress" }
          + ["weekday_monday_count", "weekday_wednesday_count", "weekday_friday_count"]


        logInfo("UserDefaults sayaçları temizleniyor...")
        for key in counterKeys {
            userDefaults.removeObject(forKey: key)
             // logDebug("Removed UserDefaults key: \(key)") // Debug için
        }
        // Not: userDefaults.removePersistentDomain çok geniş kapsamlıydı, kaldırdık.
        // achievementsKey'i de silelim
        userDefaults.removeObject(forKey: achievementsKey)

        userDefaults.synchronize()
        logInfo("UserDefaults sayaçları temizlendi.")


        // Firebase'deki verileri sıfırla
        deleteAchievementsFromFirebase()

        // CoreData'daki verileri sıfırla
        if let user = Auth.auth().currentUser {
            logInfo("Resetting Core Data achievements for user \(user.uid)")
            achievementCoreDataService.saveAchievements([], for: user.uid)
            logInfo("Resetting Core Data streak data for user \(user.uid)")
            persistenceController.updateUserStreakData(for: user.uid, lastLogin: nil, currentStreak: 0, highestStreak: 0)
            // Combo verilerini de sıfırla
             logInfo("Resetting Core Data combo data for user \(user.uid)")
             persistenceController.updateUserComboData(for: user.uid, perfectCombo: 0, lastGameTime: 0, speedCombo: 0)
        }

        // Uygulamaya bildir
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        }
    }
    
    // Firebase'den başarımları silme fonksiyonu
    private func deleteAchievementsFromFirebase() {
        guard let user = Auth.auth().currentUser else { return }
        
        logInfo("Firebase'deki başarımlar siliniyor...")
        
        // 1. Yeni yapıdan kategori verilerini sil
        let userAchievementsRef = db.collection("userAchievements").document(user.uid)
        
        // Önce kategori koleksiyonundaki tüm belgeleri sil
        userAchievementsRef.collection("categories").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                logError("Firebase kategori belgeleri alınamadı: \(error.localizedDescription)")
                return
            }
            
            // Batch işlemi oluştur
            let batch = self.db.batch()
            
            // Tüm belgeleri silme işlemini batch'e ekle
            if let documents = snapshot?.documents {
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
            }
            
            // Ana belgeyi de silme işlemini batch'e ekle
            batch.deleteDocument(userAchievementsRef)
            
            // Batch işlemini uygula
            batch.commit { error in
                if let error = error {
                    logError("Firebase kategori başarımları silinemedi: \(error.localizedDescription)")
                } else {
                    logSuccess("Firebase'deki kategori başarımları başarıyla silindi")
                }
                
                // 3. Users koleksiyonundaki başarımları da sil
                self.db.collection("users").document(user.uid).updateData(["achievements": FieldValue.delete()]) { error in
                    if let error = error {
                        logError("Users koleksiyonundaki başarımlar silinemedi: \(error.localizedDescription)")
                    } else {
                        logSuccess("Users koleksiyonundaki başarımlar başarıyla silindi")
                    }
                }
            }
        }
        
        // 2. Eski koleksiyon verilerini de sil (achievements koleksiyonu)
        db.collection("achievements").document(user.uid).collection("categories").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                logError("Firebase achievements koleksiyonu başarımları silinemedi: \(error.localizedDescription)")
                // Hata olsa bile devam et, diğer koleksiyonları silmeye çalış
            }
            
            // Batch işlemi oluştur
            let batch = self.db.batch()
            
            // Tüm belgeleri silme işlemini batch'e ekle
            if let documents = snapshot?.documents {
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
            }
            
            // Batch işlemini uygula
            batch.commit { error in
                if let error = error {
                    logError("Firebase başarımları silinemedi: \(error.localizedDescription)")
                } else {
                    logSuccess("Firebase'deki eski yapı başarımları başarıyla silindi")
                }
            }
        }
    }
    
    // Günlük başarımların durumunu kontrol et
    private func checkDailyAchievementsStatus() {
        // Bu fonksiyonun mantığı resetDailyAchievements ve updateDailyCompletionAchievements içinde
        // ele alındığı için artık gereksiz olabilir.
        // Şimdilik boş bırakalım veya kaldıralım.
         logInfo("checkDailyAchievementsStatus çağrıldı (içi boş).")

        // let calendar = Calendar.current
        // let today = Date()
        // let todayKey = "daily_completions_\(calendar.startOfDay(for: today).timeIntervalSince1970)"
        // let dailyCompletions = userDefaults.integer(forKey: todayKey)
        // if dailyCompletions == 0 {
        //     for id in ["daily_5", "daily_10", "daily_20"] {
        //         if let achievement = achievements.first(where: { $0.id == id }) {
        //             if !achievement.isCompleted {
        //                 updateAchievement(id: id, status: .inProgress(currentValue: 0, requiredValue: achievement.targetValue))
        //             }
        //         }
        //     }
        // }
    }
    
    // Başarımı güncelle ve durumunu değiştir
    func updateAchievement(_ achievementID: String, progress: Int? = nil, completed: Bool = false) {
        guard let index = achievements.firstIndex(where: { $0.id == achievementID }) else { return }
        
        var updatedAchievement = achievements[index]
        
        if let progress = progress {
            let newProgress = min(progress, updatedAchievement.targetValue)
            updatedAchievement.currentValue = newProgress
            achievements[index] = updatedAchievement
        }
        
        if completed && !updatedAchievement.isUnlocked {
            updatedAchievement.isUnlocked = true
            updatedAchievement.completionDate = Date()
            achievements[index] = updatedAchievement
            unlockedAchievements[achievementID] = true
            
            // Bildirim göstermek için değişkenleri güncelle
            lastUnlockedAchievement = updatedAchievement
            showAchievementAlert = true
            
            logSuccess("Başarım açıldı: \(updatedAchievement.name)")
            
            // Firebase'e kaydet
            saveAchievementToFirestore(achievementID: achievementID)
        }
    }
    
    // Firebase'e başarıyı kaydet
    private func saveAchievementToFirestore(achievementID: String) {
        // Kuyruk sistemi üzerinden senkronize etmeyi dene
        addToPendingSyncQueue(achievementID)
        
        // Log için
        if let achievement = achievements.first(where: { $0.id == achievementID }) {
            logInfo("Başarım senkronizasyon kuyruğuna eklendi: \(achievement.name)")
        }
    }
    
    // Toplam tamamlanan oyun sayısı başarımlarını kontrol et
    private func updateTotalCompletionAchievements() {
        // Toplam tamamlanan oyun sayısını `calculateTotalCompletedGames` ile alıp ilgili başarımları günceller.
        // Bu fonksiyon `AchievementEntity.currentValue` kullanacak şekilde güncellenmeli.
        // `calculateTotalCompletedGames` fonksiyonunun güncellenmesi gerekiyor.

        let totalCompleted = calculateTotalCompletedGames() // Bu fonksiyon güncellenecek

        updateAchievementProgress(id: "total_100", currentProgress: totalCompleted)
        updateAchievementProgress(id: "total_500", currentProgress: totalCompleted)
        updateAchievementProgress(id: "total_1000", currentProgress: totalCompleted)
        updateAchievementProgress(id: "total_5000", currentProgress: totalCompleted)
    }

    // Toplam tamamlanmış oyun sayısını hesapla (GÜNCELLENDİ)
    private func calculateTotalCompletedGames() -> Int {
        // Tüm zorluk seviyelerindeki tamamlanmış oyun sayısını Achievement listesinden hesapla.
        var totalCount = 0
        let difficultyPrefixes = ["easy_", "medium_", "hard_", "expert_"]

        for prefix in difficultyPrefixes {
            // İlgili zorluk seviyesindeki en yüksek tamamlanmış veya ilerlemedeki başarımı bul
            let relevantAchievements = achievements.filter { $0.id.hasPrefix(prefix) }
                                          .sorted(by: { ach1, ach2 in
                                              // ID'nin sonundaki sayıyı alarak sırala
                                              let num1 = Int(ach1.id.split(separator: "_").last ?? "0") ?? 0
                                              let num2 = Int(ach2.id.split(separator: "_").last ?? "0") ?? 0
                                              return num1 > num2 // Büyükten küçüğe sırala
                                          })

            // Önce tamamlanmış en yüksek gereksinimli başarımı ara
            if let completedMax = relevantAchievements.first(where: { $0.isCompleted }) {
                totalCount += completedMax.targetValue
            }
            // Tamamlanmış yoksa, ilerlemedeki en yüksek gereksinimli başarımın ilerlemesini al
            else if let inProgressMax = relevantAchievements.first {
                 totalCount += inProgressMax.currentValue
            }
             // Debug log
             // logDebug("Difficulty \(prefix): Max progress/completion = \(relevantAchievements.first?.currentValue ?? 0) (Completed: \(relevantAchievements.first?.isCompleted ?? false))")

        }
         logInfo("Toplam Tamamlanan Oyun Sayısı (Hesaplanan): \(totalCount)")
        return totalCount
    }


    // Belirli bir önek (prefix) ile başlayan başarımlardaki tamamlanan oyun sayısını hesapla (Artık kullanılmıyor, calculateTotalCompletedGames içinde benzer mantık var)
    // private func getCompletionCountForPrefix(_ prefix: String) -> Int { ... }


    // Çeşitlilik başarımını kontrol et (GÜNCELLENDİ)
    private func checkPuzzleVarietyAchievement() {
        // Her zorluk seviyesinden en az 5 oyun tamamlanıp tamamlanmadığını kontrol eder.
        // getCompletionCountForDifficulty fonksiyonunu kullanır.

        let minCompletionsPerDifficulty = 5
        let difficulties: [SudokuBoard.Difficulty] = [.easy, .medium, .hard, .expert]
        var difficultiesMeetingRequirement = 0

        for difficulty in difficulties {
            if getCompletionCountForDifficulty(difficulty) >= minCompletionsPerDifficulty {
                difficultiesMeetingRequirement += 1
            }
        }

        let totalRequired = difficulties.count // Toplam 4 zorluk seviyesi
        // Başarımın ilerlemesini, gereksinimi karşılayan zorluk sayısı olarak kaydedelim.
        updateAchievementProgress(id: "puzzle_variety", currentProgress: difficultiesMeetingRequirement, requiredOverride: totalRequired)
    }

    // Bir zorluk seviyesinde tamamlanmış oyun sayısını hesapla (GÜNCELLENDİ)
    private func getCompletionCountForDifficulty(_ difficulty: SudokuBoard.Difficulty) -> Int {
        var prefix: String
        switch difficulty {
        case .easy: prefix = "easy_"
        case .medium: prefix = "medium_"
        case .hard: prefix = "hard_"
        case .expert: prefix = "expert_"
        }

        // İlgili zorluk seviyesindeki en yüksek tamamlanmış veya ilerlemedeki başarımı bul
         let relevantAchievements = achievements.filter { $0.id.hasPrefix(prefix) }
                                       .sorted(by: { ach1, ach2 in
                                           let num1 = Int(ach1.id.split(separator: "_").last ?? "0") ?? 0
                                           let num2 = Int(ach2.id.split(separator: "_").last ?? "0") ?? 0
                                           return num1 > num2 // Büyükten küçüğe
                                       })

         // Önce tamamlanmış en yüksek gereksinimli başarımı ara
         if let completedMax = relevantAchievements.first(where: { $0.isCompleted }) {
             return completedMax.targetValue
         }
         // Tamamlanmış yoksa, ilerlemedeki en yüksek gereksinimli başarımın ilerlemesini al
         else if let inProgressMax = relevantAchievements.first {
              return inProgressMax.currentValue
         }
        return 0
    }


    // Özel saat başarımlarını kontrol et (GÜNCELLENDİ)
    private func checkSpecialTimeAchievements() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // Gece yarısı çözücüsü (23:45-00:15)
        if (hour == 23 && minute >= 45) || (hour == 0 && minute <= 15) {
            // Bu tek seferlik bir başarım, doğrudan tamamlandı yapalım.
            updateAchievement(id: "midnight_solver", status: .completed(unlockDate: Date()))
        }

        // Öğle arası (12:00-14:00)
        if hour >= 12 && hour < 14 {
            incrementAchievementProgress(id: "lunch_break")
        }

        // Yolcu (07:00-09:00 veya 17:00-19:00)
        if (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19) {
            incrementAchievementProgress(id: "commuter")
        }
    }

    // Özel zaman dilimlerine göre başarı sayısını artır (Artık Kullanılmıyor, incrementAchievementProgress kullanılacak)
    // private func incrementSpecialTimeAchievement(id: String) { ... }

    // Gün zamanına göre başarımları güncelle (GÜNCELLENDİ)
    private func updateTimeOfDayAchievements() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Gece kuşu (22:00-06:00 arası)
        if hour >= 22 || hour < 6 {
            incrementAchievementProgress(id: "night_owl")
            incrementAchievementProgress(id: "night_hunter")
        }

        // Erken kuş (06:00-09:00 arası)
        if hour >= 6 && hour < 9 {
            incrementAchievementProgress(id: "early_bird")
            incrementAchievementProgress(id: "morning_champion")
        }
    }

    // Gün zamanı başarımları için sayaç arttırma (Artık Kullanılmıyor, incrementAchievementProgress kullanılacak)
    // private func incrementTimeOfDayAchievement(id: String, requiredValue: Int) { ... }

    // Sudoku Zirve başarısını kontrol et (Aynı kalabilir, isCompleted kontrolü yapıyor)
    // func checkForMasterAchievement() { ... }

    // ... (loadFromCoreDataBackup, updateAchievementsFromFirebase aynı kalır) ...

    // YENİ: Mevsimsel başarımları kontrol et (GÜNCELLENDİ)
    private func checkSeasonalAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)

        var seasonAchievementId: String?
        switch month {
        case 3, 4, 5: seasonAchievementId = "seasonal_spring"
        case 6, 7, 8: seasonAchievementId = "seasonal_summer"
        case 9, 10, 11: seasonAchievementId = "seasonal_autumn"
        case 12, 1, 2: seasonAchievementId = "seasonal_winter"
        default: break
        }

        if let id = seasonAchievementId {
            incrementAchievementProgress(id: id)
        }
    }

    // Mevsimsel başarımlar için tamamlanan oyun sayısını artır (Artık Kullanılmıyor, incrementAchievementProgress kullanılacak)
    // private func incrementSeasonalAchievement(id: String) { ... }

    // YENİ: Saat dilimi başarımları (GÜNCELLENDİ)
    private func checkClockBasedAchievements() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        if hour >= 7 && hour < 9 { incrementAchievementProgress(id: "clock_morning_rush") }
        if hour >= 12 && hour < 14 { incrementAchievementProgress(id: "clock_lunch_break") }
        if hour >= 15 && hour < 17 { incrementAchievementProgress(id: "clock_tea_time") }
        if hour >= 20 && hour < 22 { incrementAchievementProgress(id: "clock_prime_time") }
    }

    // Saat dilimi başarımlarını artır (Artık Kullanılmıyor, incrementAchievementProgress kullanılacak)
    // private func incrementClockBasedAchievement(id: String) { ... }

    // ... (checkSpeedAchievements aynı kalır, updateAchievement çağırıyor) ...

    // YENİ: Hatasız seri başarımları (GÜNCELLENDİ - Core Data Kullanacak)
    private func checkPerfectComboAchievements(errorCount: Int) {
        guard let firebaseUID = Auth.auth().currentUser?.uid else { return }

        // Core Data'dan mevcut kombo sayısını al
        let comboData = persistenceController.getUserComboData(for: firebaseUID)
        var currentPerfectCombo = comboData?.perfectCombo ?? 0

        if errorCount == 0 {
            // Hata yok, seriyi artır
            currentPerfectCombo += 1
            logInfo("Hatasız Seri Arttı: \(currentPerfectCombo)")
            persistenceController.updateUserComboData(for: firebaseUID, perfectCombo: currentPerfectCombo)

            // Başarımları kontrol et/güncelle
            updateAchievementProgress(id: "combo_perfect_5", currentProgress: currentPerfectCombo)
            updateAchievementProgress(id: "combo_perfect_10", currentProgress: currentPerfectCombo)
        } else {
            // Hata var, seriyi sıfırla
            if currentPerfectCombo > 0 { // Sadece sıfırdan büyükse sıfırla ve logla
                 logInfo("Hatasız Seri Sıfırlandı (Önceki: \(currentPerfectCombo))")
                 currentPerfectCombo = 0
                 persistenceController.updateUserComboData(for: firebaseUID, perfectCombo: currentPerfectCombo)
                 // Başarımların ilerlemesini de sıfırlayalım mı? Hayır, sadece seri sıfırlanır.
                 // updateAchievementProgress(id: "combo_perfect_5", currentProgress: 0) // Bu yanlış olur
                 // updateAchievementProgress(id: "combo_perfect_10", currentProgress: 0) // Bu yanlış olur
            }
        }
    }


    // YENİ: Hız seri başarımları (GÜNCELLENDİ - Core Data Kullanacak)
    private func checkSpeedComboAchievements(time: TimeInterval) {
         guard let firebaseUID = Auth.auth().currentUser?.uid else { return }

         // Core Data'dan verileri al
         let comboData = persistenceController.getUserComboData(for: firebaseUID)
         let lastGameTime = comboData?.lastGameTime ?? 0.0
         var currentSpeedCombo = comboData?.speedCombo ?? 0

         var needsUpdate = false

         if lastGameTime > 0 && time < lastGameTime {
             // Kendi rekorunu kırdı, seriyi artır
             currentSpeedCombo += 1
             logInfo("Hız Rekoru Serisi Arttı: \(currentSpeedCombo) (Süre: \(time) < \(lastGameTime))")
             needsUpdate = true
             // Başarımı güncelle
             updateAchievementProgress(id: "combo_speed_5", currentProgress: currentSpeedCombo)

         } else if time >= lastGameTime && currentSpeedCombo > 0 { // Sadece 0'dan büyükse sıfırla
             // Rekor kırılmadı veya ilk oyun, seriyi sıfırla
             logInfo("Hız Rekoru Serisi Sıfırlandı (Önceki: \(currentSpeedCombo), Süre: \(time) >= \(lastGameTime))")
             currentSpeedCombo = 0
             needsUpdate = true
              // Başarım ilerlemesini sıfırlama (combo_speed_5 zaten currentValue alıyor)
         }

         // Yeni oyun süresini ve güncellenmiş seri sayısını Core Data'ya kaydet
         // Sadece gerçekten bir değişiklik olduğunda veya yeni süre kaydedilmesi gerektiğinde güncelle.
         if needsUpdate || time != lastGameTime {
             persistenceController.updateUserComboData(for: firebaseUID, lastGameTime: time, speedCombo: currentSpeedCombo)
         }
    }


    // YENİ: Hafta içi başarımları (GÜNCELLENDİ)
    private func checkWeekdayAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        switch weekday {
        case 2: incrementAchievementProgress(id: "weekday_monday") // Pazartesi
        case 4: incrementAchievementProgress(id: "weekday_wednesday") // Çarşamba
        case 6: incrementAchievementProgress(id: "weekday_friday") // Cuma
        default: break
        }
    }

    // Belirli gün başarımlarını artır (Artık Kullanılmıyor, incrementAchievementProgress kullanılacak)
    // private func incrementWeekdayAchievement(id: String) { ... }

    // YENİ: Oyun stili başarımları (GÜNCELLENDİ - UserDefaults kaldırıldı)
    private func checkGameStyleAchievements(hintCount: Int, errorCount: Int /*, notesUsed: Bool, allNotesUsed: Bool */) {
        // TODO: `notesUsed` ve `allNotesUsed` bilgileri oyun görünümünden (ViewModel?) gelmeli.
        // Bu bilgiler olmadan 'style_methodical' ve 'style_perfectionist' çalışmaz.
        // Şimdilik bu iki başarımı kontrol etmiyoruz.

        // Metodolojik Çözücü (Not almadan oyunu tamamlama)
        // if !notesUsed {
        //     updateAchievement(id: "style_methodical", status: .completed(unlockDate: Date()))
        // }

        // Mükemmeliyetçi (Tüm notları kullanma)
        // if allNotesUsed {
        //     updateAchievement(id: "style_perfectionist", status: .completed(unlockDate: Date()))
        // }

        // Hızlı Girişçi (30 saniye içinde 30 hücre)
        // Bu başarımın mantığı oyun sırasında gerçek zamanlı olarak kontrol edilmeli ve
        // AchievementManager'a sadece tamamlandığında bilgi verilmeli.
        // Örneğin: AchievementManager.shared.completeAchievement(id: "style_fast_input")
        // Bu yüzden buradaki kontrolü kaldırıyoruz.
    }

    // YENİ: Tamamlanan hücre sayısı başarımları (GÜNCELLENDİ - Core Data Kullanacak)
    private func updateCellsCompletedAchievements() {
        // Artık User entity'sindeki totalCellsCompleted kullanılacak.
        guard let firebaseUID = Auth.auth().currentUser?.uid else { return }

        // Core Data'dan mevcut toplamı al
        let currentCells = persistenceController.getUserTotalCellsCompleted(for: firebaseUID) ?? 0
        let newTotal = currentCells + 81 // Her tamamlanan oyun 81 hücre ekler

        // Core Data'yı güncelle
        persistenceController.updateUserTotalCellsCompleted(for: firebaseUID, total: newTotal)
        logInfo("Toplam Tamamlanan Hücre (Core Data): \(newTotal)")

        // Başarımları kontrol et (Bu fonksiyon zaten currentValue kullanıyor)
        updateAchievementProgress(id: "stats_500_cells", currentProgress: newTotal)
        updateAchievementProgress(id: "stats_1000_cells", currentProgress: newTotal)
        updateAchievementProgress(id: "stats_5000_cells", currentProgress: newTotal)
    }


    // YENİ: Özel gün başarımları (GÜNCELLENDİ)
    private func checkSpecialDayAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let month = calendar.component(.month, from: today)

        // Yeni yıl kontrolü
        if day == 1 && month == 1 {
            updateAchievement(id: "holiday_new_year", status: .completed(unlockDate: Date()))
        }

        // Doğum günü başarımı (Örnek: 15 Temmuz)
        if day == 15 && month == 7 {
            updateAchievement(id: "birthday_player", status: .completed(unlockDate: Date()))
        }

        // Hafta sonu canavarı - Bir hafta sonunda 20 oyun
        checkWeekendWarriorAchievement() // Bu fonksiyon da güncellendi
    }

    // Hafta sonu canavarı başarımını kontrol et (GÜNCELLENDİ)
    private func checkWeekendWarriorAchievement() {
        // Bu başarımın sayacını ("holiday_weekend") diğer hafta sonu sayaçları gibi
        // updateWeekendAchievements içinde yönetelim. Bu ayrı fonksiyon gereksiz.
        // updateWeekendAchievements zaten ilgili ID'leri kontrol ediyor.
        logDebug("checkWeekendWarriorAchievement çağrıldı, mantık updateWeekendAchievements'a taşındı.")
    }

    // --- YENİ Yardımcı Fonksiyonlar ---

    // Bir başarımın ilerlemesini currentValue kullanarak günceller
    private func updateAchievementProgress(id: String, currentProgress: Int, requiredOverride: Int? = nil) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else {
            logWarning("updateAchievementProgress: Başarım bulunamadı - ID: \(id)")
            return
        }

        // Eğer başarım zaten tamamlanmışsa işlem yapma
        if achievements[index].isCompleted {
            // logDebug("updateAchievementProgress: Başarım zaten tamamlanmış - ID: \(id)")
            return
        }

        let requiredValue = requiredOverride ?? achievements[index].targetValue
        let newProgress = min(currentProgress, requiredValue) // İlerleme hedef değeri geçemez

        // Sadece ilerleme değiştiyse veya ilk kez ayarlanıyorsa güncelle
        if achievements[index].currentValue != newProgress {
            if newProgress >= requiredValue {
                // Tamamlandı
                updateAchievement(id: id, status: .completed(unlockDate: Date()))
                 logInfo("Başarım tamamlandı (Progress): \(id) - \(newProgress)/\(requiredValue)")
            } else {
                // İlerliyor
                updateAchievement(id: id, status: .inProgress(currentValue: newProgress, requiredValue: requiredValue))
                 logInfo("Başarım ilerledi (Progress): \(id) - \(newProgress)/\(requiredValue)")
            }
        } else {
             //logDebug("updateAchievementProgress: İlerleme değişmedi - ID: \(id), Progress: \(newProgress)")
        }
    }

    // Bir başarımın sayacını 1 artırır
    func incrementAchievementProgress(id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else {
            logWarning("incrementAchievementProgress: Başarım bulunamadı - ID: \(id)")
            return
        }

        // Eğer başarım zaten tamamlanmışsa işlem yapma
        if achievements[index].isCompleted {
             //logDebug("incrementAchievementProgress: Başarım zaten tamamlanmış - ID: \(id)")
            return
        }

        let currentCount = achievements[index].currentValue
        let newCount = currentCount + 1
        let requiredValue = achievements[index].targetValue

        if newCount >= requiredValue {
            // Tamamlandı
            updateAchievement(id: id, status: .completed(unlockDate: Date()))
             logInfo("Başarım tamamlandı (Increment): \(id) - \(newCount)/\(requiredValue)")
        } else {
            // İlerliyor
            updateAchievement(id: id, status: .inProgress(currentValue: newCount, requiredValue: requiredValue))
             logInfo("Başarım ilerledi (Increment): \(id) - \(newCount)/\(requiredValue)")
        }
    }

    // Sudoku Zirve başarısını kontrol et - her kategoriden en az 3 başarı
    func checkForMasterAchievement() {
        // Tamamlanmış başarıları kategorilere göre say
        var completedByCategory: [AchievementCategory: Int] = [:]
        for achievement in achievements where achievement.isCompleted {
            completedByCategory[achievement.category, default: 0] += 1
        }

        // Her kategoride en az 3 veya 5 başarı olup olmadığını hesapla
        let categoriesWithThreeOrMore = completedByCategory.filter { $0.value >= 3 }.count
        let categoriesWithFiveOrMore = completedByCategory.filter { $0.value >= 5 }.count
        // Toplam kategori sayısını al (AchievementCategory enum'ındaki tüm case'ler)
        let totalCategories = AchievementCategory.allCases.count
        
        // Durumlara göre başarımları güncelle
        if categoriesWithFiveOrMore >= totalCategories {
            // Grandmaster tamamlandıysa, master da tamamlanmıştır.
            updateAchievement(id: "sudoku_grandmaster", status: .completed(unlockDate: Date()))
            updateAchievement(id: "sudoku_master", status: .completed(unlockDate: Date()))
        } else if categoriesWithThreeOrMore >= totalCategories {
            // Master tamamlandı ama Grandmaster tamamlanmadı.
            updateAchievement(id: "sudoku_master", status: .completed(unlockDate: Date()))
            // Grandmaster ilerlemesini güncelle
            let grandmasterStatus = AchievementStatus.inProgress(currentValue: categoriesWithFiveOrMore, requiredValue: totalCategories)
            updateAchievement(id: "sudoku_grandmaster", status: grandmasterStatus)
        } else {
            // İkisi de tamamlanmadı, ilerlemeleri güncelle.
            let masterStatus = AchievementStatus.inProgress(currentValue: categoriesWithThreeOrMore, requiredValue: totalCategories)
            updateAchievement(id: "sudoku_master", status: masterStatus)
            let grandmasterStatus = AchievementStatus.inProgress(currentValue: categoriesWithFiveOrMore, requiredValue: totalCategories)
            updateAchievement(id: "sudoku_grandmaster", status: grandmasterStatus)
        }
    


        if categoriesWithFiveOrMore >= totalCategories {
            // Tüm kategorilerde en az 5 başarı varsa Grandmaster başarısını da ver
            updateAchievement(id: "sudoku_grandmaster", status: .completed(unlockDate: Date()))
            updateAchievement(id: "sudoku_master", status: .completed(unlockDate: Date()))
        } else if categoriesWithThreeOrMore >= totalCategories {
            // Tüm kategorilerde en az 3 başarı varsa
            updateAchievement(id: "sudoku_master", status: .completed(unlockDate: Date()))

            // Grandmaster için ilerleme
            updateAchievement(id: "sudoku_grandmaster", status: .inProgress(
                currentValue: categoriesWithFiveOrMore,
                requiredValue: totalCategories
            ))
        } else {
            // Master için ilerleme
            updateAchievement(id: "sudoku_master", status: .inProgress(
                currentValue: categoriesWithThreeOrMore,
                requiredValue: totalCategories
            ))
        }
    }


    // CoreData'dan yedek yükleme fonksiyonu
    private func loadFromCoreDataBackup(for userID: String) {
        let coreDataAchievements = self.achievementCoreDataService.loadAchievements(for: userID)
        if !coreDataAchievements.isEmpty {
            logInfo("CoreData'dan \\(coreDataAchievements.count) başarım yüklendi")

            // Yerel başarımlarla birleştir
            for coreDataAchievement in coreDataAchievements {
                if let index = self.achievements.firstIndex(where: { $0.id == coreDataAchievement.id }) {
                     // Sadece yerel olan tamamlanmamışsa ve CoreData'daki tamamlanmışsa güncelle
                    if !self.achievements[index].isCompleted && coreDataAchievement.isCompleted {
                        self.achievements[index] = coreDataAchievement
                        logInfo("CoreData'dan güncellenen başarım: \(coreDataAchievement.id)")
                    } else if self.achievements[index].isCompleted && !coreDataAchievement.isCompleted {
                         // Yerel tamamlanmış, CoreData değilse? Bu durum olmamalı ama loglayalım.
                         logWarning("Yerel başarım (\(self.achievements[index].id)) tamamlanmış ama CoreData versiyonu değil.")
                    } else if !self.achievements[index].isCompleted && !coreDataAchievement.isCompleted {
                         // İkisi de tamamlanmamışsa, ilerlemesi daha yüksek olanı al
                         if coreDataAchievement.currentValue > self.achievements[index].currentValue {
                             self.achievements[index].status = coreDataAchievement.status // CoreData'daki status'u kullan
                             logInfo("CoreData'dan daha yüksek ilerlemeli başarım güncellendi: \(coreDataAchievement.id)")
                         }
                    }
                } else {
                    // Yerelde olmayan bir başarım CoreData'da varsa, ekle (bu olmamalı)
                     logWarning("CoreData'da bulunan ancak yerelde olmayan başarım: \(coreDataAchievement.id)")
                     // self.achievements.append(coreDataAchievement) // Gerekirse ekle
                }
            }

            // Toplam puanları güncelle
            self.calculateTotalPoints()

            // UI'ı güncellemek için bildirim gönder
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AchievementsUpdated"), object: nil)
            }

            // Firebase'e senkronize et (opsiyonel, loadFromFirebase sonrası zaten senkronize edilebilir)
            // self.syncWithFirebase()
        } else {
            logWarning("CoreData'da da başarım bulunamadı, varsayılan başarımlar kullanılacak")
        }
    }


    private func updateAchievementsFromFirebase(_ firebaseAchievements: [[String: Any]]) { // Uncommented function
        var updatedCount = 0
        let mergeDate = Date() // Tüm güncellemeler için ortak zaman damgası

        for fbAchievementData in firebaseAchievements {
            guard let id = fbAchievementData["id"] as? String,
                  let localIndex = achievements.firstIndex(where: { $0.id == id }) else { // <<< DÜZELTME: `_` yerine `localIndex` kullan
                logWarning("updateAchievementsFromFirebase: Bilinmeyen veya geçersiz başarım ID\'si: \(fbAchievementData["id"] ?? "yok")")
                continue
            }

            let localAchievement = achievements[localIndex] // DÜZELTME: Re-fetch yerine direkt localIndex kullan
            var updatedAchievement = localAchievement // Değişiklikleri yapmak için kopya oluştur

            // Firebase'den gelen temel veriler
            let firebaseStatusStr = fbAchievementData["status"] as? String ?? "locked"
            let firebaseCurrentValue = fbAchievementData["currentValue"] as? Int ?? 0
            let firebaseRequiredValue = fbAchievementData["requiredValue"] as? Int ?? updatedAchievement.targetValue

            // Zaman damgaları
            let firebaseTimestamp = fbAchievementData["lastUpdated"] as? Timestamp ?? fbAchievementData["unlockDate"] as? Timestamp
            let firebaseDate = firebaseTimestamp?.dateValue() ?? Date(timeIntervalSince1970: 0) // Firebase tarihi
            let localDate = localAchievement.lastSyncDate ?? Date(timeIntervalSince1970: 0) // Yerel son senkronizasyon tarihi

            // ---- GELİŞMİŞ ÇAKIŞMA ÇÖZÜMLEME MANTIĞI ----

            var needsSave = false // Sadece gerçekten değişiklik olursa kaydet

            // Durum 1: İki taraf da tamamlandıysa - en eski tamamlanma tarihini koru
            if localAchievement.isCompleted && firebaseStatusStr == "completed" {
                if let localCompletionDate = localAchievement.completionDate,
                   let fbUnlockTimestamp = fbAchievementData["unlockDate"] as? Timestamp {
                    let fbCompletionDate = fbUnlockTimestamp.dateValue()
                    
                    // Daha eski olanı seç (ilk başaran kişi)
                    let earlierDate = localCompletionDate < fbCompletionDate ? localCompletionDate : fbCompletionDate
                    if earlierDate != localCompletionDate {
                        // Sadece değişiklik varsa güncelle
                        updatedAchievement.status = .completed(unlockDate: earlierDate)
                        updatedAchievement.completionDate = earlierDate
                        updatedAchievement.lastSyncDate = mergeDate
                        needsSave = true
                        logInfo("İki taraflı tamamlama çakışması - daha eski tarih seçildi: \(id)")
                    }
                }
                // Durum 1 için işlem tamamlandı, diğer durumları kontrol etmeye gerek yok
                
            // Durum 2: Sadece yerel tamamlandıysa ve veriler çakışıyorsa - yerel durum korunur
            } else if localAchievement.isCompleted && firebaseStatusStr != "completed" {
                logInfo("Yerel tamamlanmış ama Firebase tamamlanmamış, yerel durum korunuyor: \(id)")
                // Sadece lastSyncDate güncellenir
                updatedAchievement.lastSyncDate = mergeDate
                    needsSave = true
                
            // Durum 3: Sadece Firebase tamamlandıysa - Firebase kazanır
            } else if !localAchievement.isCompleted && firebaseStatusStr == "completed" {
                if let fbUnlockTimestamp = fbAchievementData["unlockDate"] as? Timestamp {
                    let unlockDate = fbUnlockTimestamp.dateValue()
                    updatedAchievement.status = .completed(unlockDate: unlockDate)
                    updatedAchievement.completionDate = unlockDate
                    updatedAchievement.lastSyncDate = mergeDate
                    updatedAchievement.isUnlocked = true
                         needsSave = true
                    logInfo("Firebase'de tamamlanmış ama yerelde tamamlanmamış, Firebase verisi alındı: \(id)")
                }
                
            // Durum 4: İki taraf da ilerlemede - en yüksek ilerleme değeri alınır
            } else if !localAchievement.isCompleted && firebaseStatusStr == "inProgress" {
                let localValue = localAchievement.currentValue
                
                // En yüksek ilerleme değeri alınır
                if firebaseCurrentValue > localValue {
                    updatedAchievement.status = .inProgress(
                        currentValue: firebaseCurrentValue,
                        requiredValue: firebaseRequiredValue
                    )
                    updatedAchievement.lastSyncDate = mergeDate
                            needsSave = true
                    logInfo("Firebase ilerleme değeri daha yüksek, güncelleniyor: \(id) - \(firebaseCurrentValue)/\(firebaseRequiredValue)")
                         }
                // Yerel daha ilerideyse ve yerel daha yeniyse, bir şey yapmaya gerek yok
                else if localValue > firebaseCurrentValue && localDate > firebaseDate {
                    logInfo("Yerel ilerleme daha yüksek ve daha güncel: \(id) - \(localValue)/\(localAchievement.targetValue)")
                }
                
            // Durum 5: Firebase kilitli, yerel ilerleme var
            } else if firebaseStatusStr == "locked" && localAchievement.status != .locked {
                // Yerel ilerleme varsa Firebase'i görmezden gel
                logInfo("Firebase kilitli ama yerelde ilerleme var, yerel durum korunuyor: \(id)")
            }

            // Değişiklik varsa uygula
            if needsSave {
                // Array'de doğrudan güncelleme
                achievements[localIndex] = updatedAchievement
                updatedCount += 1
                 logDebug("Başarım güncellendi (Firebase'den): \(id)")
            }
        }

        if updatedCount > 0 {
            logSuccess("Firebase'den \(updatedCount) başarım güncellendi")

            // Değişiklikleri kaydet ve toplam puanları güncelle
            calculateTotalPoints()
            saveAchievements() // Hem UserDefaults hem CoreData'ya kaydeder

            // UI güncellemesi yap
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AchievementsUpdated"), object: nil)
            }
        } else {
             logInfo("Firebase'den gelen verilerle yerel başarımlarda bir değişiklik yapılmadı.")
        }
    }

    // YENİ: Hızlı tamamlama başarımları (Yeni eklendi) - Uncommented
    private func checkSpeedAchievements(difficulty: SudokuBoard.Difficulty, time: TimeInterval) {
        let timeInSeconds = time

        switch difficulty {
        case .easy:
            if timeInSeconds < 20.0 { // speed_easy_20
                updateAchievement(id: "speed_easy_20", status: .completed(unlockDate: Date()))
            }
            if timeInSeconds < 60.0 { // time_easy_1
                updateAchievement(id: "time_easy_1", status: .completed(unlockDate: Date()))
            }
             if timeInSeconds < 30.0 { // time_easy_30s
                 updateAchievement(id: "time_easy_30s", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 120.0 { // time_easy_2
                 updateAchievement(id: "time_easy_2", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 180.0 { // time_easy_3
                 updateAchievement(id: "time_easy_3", status: .completed(unlockDate: Date()))
             }
        case .medium:
            if timeInSeconds < 45.0 { // speed_medium_45
                updateAchievement(id: "speed_medium_45", status: .completed(unlockDate: Date()))
            }
             if timeInSeconds < 60.0 { // time_medium_1
                 updateAchievement(id: "time_medium_1", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 120.0 { // time_medium_2
                 updateAchievement(id: "time_medium_2", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 180.0 { // time_easy_3
                 // Derleyici hatasını çözmek için durumu ayrı değişkene ata
                 let newStatus: AchievementStatus = .completed(unlockDate: Date())
                 updateAchievement(id: "time_easy_3", status: newStatus)
             }
             if timeInSeconds < 300.0 { // time_medium_5
                 updateAchievement(id: "time_medium_5", status: .completed(unlockDate: Date()))
             }
        case .hard:
            if timeInSeconds < 90.0 { // speed_hard_90
                updateAchievement(id: "speed_hard_90", status: .completed(unlockDate: Date()))
            }
             if timeInSeconds < 120.0 { // time_hard_2
                 updateAchievement(id: "time_hard_2", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 180.0 { // time_hard_3
                 updateAchievement(id: "time_hard_3", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 300.0 { // time_hard_5
                 updateAchievement(id: "time_hard_5", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 600.0 { // time_hard_10
                 updateAchievement(id: "time_hard_10", status: .completed(unlockDate: Date()))
             }
        case .expert:
             if timeInSeconds < 180.0 { // time_expert_3
                 updateAchievement(id: "time_expert_3", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 300.0 { // time_expert_5
                 updateAchievement(id: "time_expert_5", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 480.0 { // time_expert_8
                 updateAchievement(id: "time_expert_8", status: .completed(unlockDate: Date()))
             }
             if timeInSeconds < 900.0 { // time_expert_15
                 updateAchievement(id: "time_expert_15", status: .completed(unlockDate: Date()))
             }
        }
         // Loglama eklenebilir
         // logDebug("Hız başarımları kontrol edildi: \(difficulty), Süre: \(timeInSeconds)s")
    }

    // Tüm achievements dizisini UserDefaults'a kaydet
    private func saveAchievementsToUserDefaults() {
        // Önce JSON'a çevirmeyi dene
        do {
            // Zorunlu kontrol: Bazı Date değerleri kodlanmadığı için Date türü kontrolü yapılacak
            // Öncelikle saklayacağımız dizideki tüm tarihlerin Date tipinde olduğunu doğrula
            for achievement in achievements {
                if case .completed(let date) = achievement.status {
                    let _ = date // Sadece kontrol amaçlı kullanım
                }
                if let syncDate = achievement.lastSyncDate {
                    let _ = syncDate // Sadece kontrol amaçlı kullanım
                }
            }
            
            // Tek achievementları önce test et 
            for achievement in achievements {
                try encodeAndSaveAchievement(achievement)
            }
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(achievements)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.achievements)
            logInfo("Tüm başarımlar UserDefaults'a başarıyla kodlandı ve kaydedildi.")
        } catch {
            logError("!!! KRİTİK JSON ENCODE HATASI !!! Tüm başarımlar dizisi kaydedilemedi: \(error)")
        }
    }
    
    // Tarih dönüşümü için yardımcı fonksiyon
    private func encodeAndSaveAchievement(_ achievement: Achievement) throws {
        let encoder = JSONEncoder()
        let _ = try encoder.encode(achievement)
        logDebug("Başarım başarıyla kodlandı: \(achievement.id)")
    }
}// AchievementManager SINIFININ KAPANIS PARANTEZİ



