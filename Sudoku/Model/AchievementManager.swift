import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreData

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "user_achievements"
    private let streakKey = "user_streak_data"
    
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var totalPoints: Int = 0
    @Published var showAchievementAlert: Bool = false
    @Published var lastUnlockedAchievement: Achievement? = nil
    @Published var unlockedAchievements: [String: Bool] = [:]
    @Published private(set) var newlyUnlockedAchievements: [Achievement] = []
    
    // CoreData servis referansı
    private let achievementCoreDataService = AchievementCoreDataService()
    
    private var db: Firestore {
        return Firestore.firestore()
    }
    
    // Günlük giriş izleme için yapı
    private struct StreakData: Codable {
        var lastLoginDate: Date
        var currentStreak: Int
        var highestStreak: Int
    }
    
    private var streakData: StreakData?
    
    private init() {
        setupAchievements()
        loadAchievements()
        checkDailyLogin()
        checkDailyAchievementsStatus()
        
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
        
        // Eğer kullanıcı giriş yapmışsa, Firebase'den başarımları yükle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if Auth.auth().currentUser != nil {
                self?.loadAchievementsFromFirebase()
            }
        }
    }
    
    // Kullanıcı giriş yaptığında çağrılan fonksiyon
    @objc private func handleUserLoggedIn() {
        print("👤 Kullanıcı oturum açtı - Başarımlar yükleniyor")
        if let user = Auth.auth().currentUser {
            // CoreData'dan önce başarımları yükle
            let coreDataAchievements = achievementCoreDataService.loadAchievements(for: user.uid)
            if !coreDataAchievements.isEmpty {
                print("🗄️ CoreData'dan \(coreDataAchievements.count) başarım yüklendi")
                
                // CoreData'daki verileri yerel başarımlara yükle
                for coreDataAchievement in coreDataAchievements {
                    if let index = achievements.firstIndex(where: { $0.id == coreDataAchievement.id }) {
                        if !achievements[index].isCompleted && coreDataAchievement.isCompleted {
                            achievements[index] = coreDataAchievement
                        }
                    }
                }
                
                // Toplam puanları hesapla
                calculateTotalPoints()
            }
            
            // Firebase'den de başarımları yükle (en güncel versiyon olarak)
            loadAchievementsFromFirebase()
        }
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
        let board = Array(repeating: Array(repeating: 0, count: 9), count: 9) // dummy board
        
        // Önce Firebase'e kaydedelim, başarılı olduğunda Core Data'dan sileceğiz
        PersistenceController.shared.saveCompletedGame(
            gameID: gameID,
            board: board,
            difficulty: difficulty.rawValue,
            elapsedTime: time,
            errorCount: errorCount,
            hintCount: hintCount
        )
        
        // Fire'dan doğrudan silme işlemini de çağıralım
        PersistenceController.shared.deleteGameFromFirestore(gameID: gameID)
        
        // UI güncellemesi için gecikme ile bildirim gönderelim - bu UI'da anında değişikliği göstermeyecek
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
        }
        
        print("✅ Tamamlanan oyun işlenip, kayıtlı oyunlardan silindi")
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
        
        // Streak verilerini yükle
        if let data = userDefaults.data(forKey: streakKey),
           let savedStreakData = try? JSONDecoder().decode(StreakData.self, from: data) {
            streakData = savedStreakData
        } else {
            // İlk kez oluştur
            streakData = StreakData(
                lastLoginDate: Date(),
                currentStreak: 1,
                highestStreak: 1
            )
        }
        
        // Toplam puanları hesapla
        calculateTotalPoints()
        
        // Yüklenen verileri Firebase ile senkronize et
        syncWithFirebase()
    }
    
    // Başarıları kaydet
    private func saveAchievements() {
        if let data = try? JSONEncoder().encode(achievements) {
            userDefaults.set(data, forKey: achievementsKey)
        }
        
        // Streak verilerini kaydet
        if let streakData = streakData, let data = try? JSONEncoder().encode(streakData) {
            userDefaults.set(data, forKey: streakKey)
        }
        
        // Toplam puanları hesapla
        calculateTotalPoints()
        
        // Firebase ile senkronize et
        syncWithFirebase()
        
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
            return
        }
        
        let previousStatus = achievements[index].status
        
        // Sadece tamamlanmadıysa güncelle
        if !previousStatus.isCompleted {
            achievements[index].status = status
            
            // Tamamlandıysa bildirim göster
            if status.isCompleted && !previousStatus.isCompleted {
                // Başarımın tamamlandığını göster
                achievements[index].isUnlocked = true
                achievements[index].completionDate = Date()
                
                lastUnlockedAchievement = achievements[index]
                showAchievementAlert = true
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Yeni kazanılan başarımı listeye ekle
                newlyUnlockedAchievements.append(achievements[index])
                
                // Sudoku Zirve başarısını kontrol et
                checkForMasterAchievement()
                
                print("🏆 BAŞARIM KAZANILDI: '\(achievements[index].name)' tamamlandı!")
                
                // NotificationCenter ile bildirimi hemen gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("AchievementUnlocked"),
                    object: nil,
                    userInfo: ["achievement": achievements[index]]
                )
                
                // CoreData'ya da kaydet
                if let user = Auth.auth().currentUser {
                    achievementCoreDataService.updateAchievement(achievements[index], for: user.uid)
                }
            }
            
            // Değişiklikleri kaydet
            saveAchievements()
        }
    }
    
    // Zorluk seviyesine göre başarıları güncelle
    func updateDifficultyAchievements(difficulty: SudokuBoard.Difficulty) {
        var prefixId: String
        
        switch difficulty {
        case .easy:
            prefixId = "easy_"
            print("🏆 DEBUG: Kolay seviye başarım kontrolü - prefix: \(prefixId)")
        case .medium:
            prefixId = "medium_"
            print("🏆 DEBUG: Orta seviye başarım kontrolü - prefix: \(prefixId)")
        case .hard:
            prefixId = "hard_"
            print("🏆 DEBUG: Zor seviye başarım kontrolü - prefix: \(prefixId)")
        case .expert:
            prefixId = "expert_"
            print("🏆 DEBUG: Uzman seviye başarım kontrolü - prefix: \(prefixId)")
        }
        
        // İlgili prefixe sahip başarımları listele
        let relatedAchievements = achievements.filter { $0.id.hasPrefix(prefixId) }
        print("🏆 DEBUG: \(prefixId) prefixli \(relatedAchievements.count) başarım bulundu")
        
        // Her zorluk seviyesi başarısını kontrol et
        for achievement in achievements where achievement.id.hasPrefix(prefixId) {
            // Mevcut durumu al
            let currentStatus = achievement.status
            var newStatus: AchievementStatus
            
            switch currentStatus {
            case .locked:
                // Başlat
                newStatus = .inProgress(currentValue: 1, requiredValue: achievement.targetValue)
                print("🏆 DEBUG: '\(achievement.name)' başarımı başlatılıyor - 1/\(achievement.targetValue)")
                
                // Eğer hedef değeri 1 ise, direkt tamamlandı olarak işaretle
                if achievement.targetValue == 1 {
                    newStatus = .completed(unlockDate: Date())
                    print("🏆 DEBUG: '\(achievement.name)' başarımı direkt tamamlandı - 1/1 (100%)")
                }
            case .inProgress(let current, let required):
                let newCount = current + 1
                if newCount >= required {
                    // Tamamla
                    newStatus = .completed(unlockDate: Date())
                    print("🏆 DEBUG: '\(achievement.name)' başarımı tamamlandı - \(newCount)/\(required)")
                } else {
                    // İlerlet
                    newStatus = .inProgress(currentValue: newCount, requiredValue: required)
                    print("🏆 DEBUG: '\(achievement.name)' başarımı ilerledi - \(newCount)/\(required)")
                }
            case .completed:
                // Zaten tamamlanmış
                print("🏆 DEBUG: '\(achievement.name)' başarımı zaten tamamlanmış")
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
            print("🏆 DEBUG: 'Kusursuz' başarımı tamamlandı - hatasız oyun")
        }
        
        // İpuçsuz oyun
        if hintCount == 0 {
            updateAchievement(id: "no_hints", status: .completed(unlockDate: Date()))
            print("🏆 DEBUG: 'Yardımsız' başarımı tamamlandı - ipuçsuz oyun")
        }
    }
    
    // Oyun tamamlandığında tüm başarıları güncelle
    func processGameCompletion(difficulty: SudokuBoard.Difficulty, time: TimeInterval, errorCount: Int, hintCount: Int) {
        print("🏆 BAŞARIM - Oyun tamamlandı: \(difficulty.rawValue) zorluk, \(time) süre, \(errorCount) hata, \(hintCount) ipucu")
        
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
        
        // Hafta sonu başarıları
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
    }
    
    // DEBUG: Başarım durumlarını yazdır
    private func printAchievementStatus() {
        print("🏆 Mevcut başarım durumları:")
        
        // Kategoriye göre başarımları grupla
        Dictionary(grouping: achievements, by: { $0.category }).sorted { $0.key.rawValue < $1.key.rawValue }.forEach { category, achievements in
            print("  📋 Kategori: \(category.rawValue)")
            
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
                print("    - \(achievement.name): \(statusText)")
            }
        }
    }
    
    // Günlük oyun sayısını takip etme
    private func updateDailyCompletionAchievements() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Bugünün tarihini al
        let todayKey = "games_completed_date"
        let todayCountKey = "games_completed_today"
        
        // Kayıtlı tarihi kontrol et
        let savedDateTimeInterval = userDefaults.double(forKey: todayKey)
        if savedDateTimeInterval > 0 {
            let savedDate = Date(timeIntervalSince1970: savedDateTimeInterval)
        
            // Eğer bugün aynı gün ise, sayacı artır
            if calendar.isDate(savedDate, inSameDayAs: today) {
                // Aynı gündeyiz, sayacı artır
                let currentCount = userDefaults.integer(forKey: todayCountKey) + 1
                userDefaults.set(currentCount, forKey: todayCountKey)
                
                // Günlük başarımları kontrol et
                checkDailyGameCountAchievements(count: currentCount)
            } else {
                // Yeni tarih, sayacı sıfırla
                userDefaults.set(1, forKey: todayCountKey)
                
                // Yeni tarihi kaydet
                userDefaults.set(today.timeIntervalSince1970, forKey: todayKey)
            }
        } else {
            // İlk kez kaydediliyorsa
            userDefaults.set(1, forKey: todayCountKey)
        
            // Bugünün tarihini kaydet
            userDefaults.set(today.timeIntervalSince1970, forKey: todayKey)
        }
    }
    
    // Günlük oyun sayısı başarımlarını kontrol et
    private func checkDailyGameCountAchievements(count: Int) {
        // Günlük 5 oyun
        if count >= 5 {
            updateAchievement(id: "daily_5", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "daily_5", status: .inProgress(currentValue: count, requiredValue: 5))
        }
        
        // Günlük 10 oyun
        if count >= 10 {
            updateAchievement(id: "daily_10", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "daily_10", status: .inProgress(currentValue: count, requiredValue: 10))
        }
        
        // Günlük 20 oyun
        if count >= 20 {
            updateAchievement(id: "daily_20", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "daily_20", status: .inProgress(currentValue: count, requiredValue: 20))
        }
        
        // Günlük 30 oyun
        if count >= 30 {
            updateAchievement(id: "daily_30", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "daily_30", status: .inProgress(currentValue: count, requiredValue: 30))
        }
    }
    
    // Hafta sonu başarımlarını güncelle
    private func updateWeekendAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Cumartesi (7) veya Pazar (1) günleri
        let isWeekend = weekday == 1 || weekday == 7
        
        if isWeekend {
            // Hafta sonu başarı sayacını güncelle
            let weekendCountKey = "weekend_games_count"
            let currentCount = userDefaults.integer(forKey: weekendCountKey) + 1
            userDefaults.set(currentCount, forKey: weekendCountKey)
            
            // Hafta sonu başarımları kontrol et
            if currentCount >= 5 {
                updateAchievement(id: "weekend_5", status: .completed(unlockDate: Date()))
            } else {
                updateAchievement(id: "weekend_5", status: .inProgress(currentValue: currentCount, requiredValue: 5))
            }
            
            if currentCount >= 10 {
                updateAchievement(id: "weekend_10", status: .completed(unlockDate: Date()))
            } else {
                updateAchievement(id: "weekend_10", status: .inProgress(currentValue: currentCount, requiredValue: 10))
            }
            
            if currentCount >= 20 {
                updateAchievement(id: "weekend_20", status: .completed(unlockDate: Date()))
        } else {
                updateAchievement(id: "weekend_20", status: .inProgress(currentValue: currentCount, requiredValue: 20))
            }
        }
    }
    
    // Günlük giriş kontrolü
    private func checkDailyLogin() {
        guard var streakData = streakData else { return }
        
        let calendar = Calendar.current
        let today = Date()
        let lastLoginDay = calendar.startOfDay(for: streakData.lastLoginDate)
        let todayDay = calendar.startOfDay(for: today)
        
        if let daysBetween = calendar.dateComponents([.day], from: lastLoginDay, to: todayDay).day {
            if daysBetween == 1 {
                // Ardışık gün
                streakData.currentStreak += 1
                streakData.highestStreak = max(streakData.currentStreak, streakData.highestStreak)
                
                // Streak başarılarını kontrol et
                updateStreakAchievements(streak: streakData.currentStreak)
                
                // Yeni gün başladığında günlük görevleri sıfırla
                resetDailyAchievements()
            } else if daysBetween > 1 {
                // Streak bozuldu
                streakData.currentStreak = 1
                
                // Günlük görevleri sıfırla
                resetDailyAchievements()
            } else if daysBetween == 0 {
                // Aynı gün, bir şey yapma
            }
        }
        
        // Son giriş tarihini güncelle ve kaydet
        streakData.lastLoginDate = today
        self.streakData = streakData
        saveAchievements()
    }
    
    // Günlük görevleri sıfırla
    private func resetDailyAchievements() {
        // Önceki günün verilerini temizle
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayKey = "daily_completions_\(calendar.startOfDay(for: yesterday).timeIntervalSince1970)"
        userDefaults.removeObject(forKey: yesterdayKey)
        
        // Günlük görevleri kilitli olarak ayarla, halihazırda tamamlanmış değilse
        for id in ["daily_5", "daily_10", "daily_20"] {
            if let achievement = achievements.first(where: { $0.id == id }), !achievement.isCompleted {
                updateAchievement(id: id, status: .inProgress(currentValue: 0, requiredValue: achievement.targetValue))
            }
        }
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
                achievementDict["unlockDate"] = date
                achievementDict["currentValue"] = achievement.targetValue
                achievementDict["requiredValue"] = achievement.targetValue
            }
            
            return achievementDict
        }
    }
    
    // Firestore'a başarımları senkronize et
    func syncWithFirebase() {
        guard let user = Auth.auth().currentUser else { 
            print("⚠️ Başarımlar kaydedilemiyor: Kullanıcı oturum açmamış")
            return 
        }
        
        print("🔄 Başarımlar Firebase'e senkronize ediliyor...")
        
        // Tüm başarımlar için toplu veri hazırla
        let achievementsData = encodeAchievementsForFirebase()
        let userData: [String: Any] = [
            "achievements": achievementsData,
            "totalPoints": totalPoints,
            "lastSyncDate": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        // Önce kullanıcı belgesi var mı kontrol et
        db.collection("users").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase belgesi kontrol edilemedi: \(error.localizedDescription)")
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
                    print("⚠️ Kategorileme hatası - kategori bilgisi eksik: \(achievementData["id"] ?? "bilinmeyen")")
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
                    print("✅ Başarım kategorisi eşleşti: \(id) -> \(firestoreCategory)")
            } else {
                    // Bilinmeyen kategoriler için "special" kategorisini kullan
                    categorizedAchievements["special"]?.append(achievementData)
                    print("⚠️ Bilinmeyen kategori: \(categoryName) -> 'special' kullanıldı")
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
                    print("❌ Başarımlar Firestore'a kaydedilemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Başarımlar Firestore'a kaydedildi (Kategori Modeli)")
                }
            }
            
            // Eski yapıyı da desteklemek için kullanıcı belgesini güncelle
            if let document = document, document.exists {
                // Belge varsa güncelle
                self.db.collection("users").document(user.uid).updateData(userData) { error in
                    if let error = error {
                        print("❌ Başarımlar Firestore kullanıcı belgesine kaydedilemedi: \(error.localizedDescription)")
                } else {
                        print("✅ Başarımlar Firestore kullanıcı belgesine de kaydedildi (Geriye uyumluluk)")
                    }
                }
            } else {
                // Belge yoksa oluştur
                self.db.collection("users").document(user.uid).setData(userData) { error in
                    if let error = error {
                        print("❌ Başarımlar Firestore kullanıcı belgesine kaydedilemedi: \(error.localizedDescription)")
                    } else {
                        print("✅ Başarımlar Firestore kullanıcı belgesine de kaydedildi (Geriye uyumluluk)")
                    }
                }
            }
        }
    }
    
    // Firebase'den başarımları yükle
    func loadAchievementsFromFirebase() {
        // Giriş yapmış kullanıcı kontrolü
        guard let user = Auth.auth().currentUser else {
            print("❌ Firebase başarımları yüklenemiyor - kullanıcı giriş yapmamış")
            return
        }
        
        print("🔄 Firebase'den başarımlar yükleniyor...")
        
        // Firestore'dan başarımları al
        let userAchievementsRef = db.collection("achievements").document(user.uid)
        
        userAchievementsRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase başarım yükleme hatası: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                // Ana belge varsa kategorileri kontrol et
                let categories = document.data()?["categories"] as? [String] ?? []
                
                if categories.isEmpty {
                    print("⚠️ Kategorileri yok veya boş - Firebase başarımları bulunamadı")
                    return
                }
                
                print("📊 Firebase'de \(categories.count) başarım kategorisi bulundu")
                
                var loadedFirebaseAchievements: [[String: Any]] = []
                let categoriesGroup = DispatchGroup()
                
                // Her kategori için yükleme işlemi
                for category in categories {
                    categoriesGroup.enter()
                    
                    userAchievementsRef.collection("categories").document(category).getDocument { categoryDoc, categoryError in
                        if let categoryError = categoryError {
                            print("❌ Kategori yükleme hatası: \(categoryError.localizedDescription)")
                            categoriesGroup.leave()
                            return
                        }
                        
                        if let categoryDoc = categoryDoc, categoryDoc.exists,
                           let achievements = categoryDoc.data()?["achievements"] as? [[String: Any]] {
                            // Başarımları listeye ekle
                            loadedFirebaseAchievements.append(contentsOf: achievements)
                        }
                        
                        categoriesGroup.leave()
                    }
                }
                
                // Tüm kategoriler yüklendiğinde
                categoriesGroup.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    
                    if loadedFirebaseAchievements.isEmpty {
                        print("⚠️ Firebase'den yüklenen başarımlar yok veya boş")
                        return
                    }
                    
                    // Firebase'den gelen verilerle başarımları güncelle
                    self.updateAchievementsFromFirebase(loadedFirebaseAchievements)
                    print("✅ Firebase'den \(loadedFirebaseAchievements.count) başarım yüklendi ve güncellendi")
                    
                    // Başarımları CoreData'ya da kaydet
                    self.achievementCoreDataService.saveAchievements(self.achievements, for: user.uid)
                    print("💾 Başarımlar CoreData'ya kaydedildi")
                }
            } else {
                print("⚠️ Firebase'de başarım belgesi bulunamadı")
                
                // Başarımları CoreData'dan kontrole çalış
                let coreDataAchievements = self.achievementCoreDataService.loadAchievements(for: user.uid)
                if !coreDataAchievements.isEmpty {
                    print("🗄️ CoreData'dan \(coreDataAchievements.count) başarım yüklendi")
                    
                    // Yerel başarımlarla birleştir
                    for coreDataAchievement in coreDataAchievements {
                        if let index = self.achievements.firstIndex(where: { $0.id == coreDataAchievement.id }) {
                            if !self.achievements[index].isCompleted && coreDataAchievement.isCompleted {
                                self.achievements[index] = coreDataAchievement
                            }
                        }
                    }
                    
                    // Toplam puanları güncelle
                    self.calculateTotalPoints()
                }
            }
        }
    }
    
    // Başarı verilerini sıfırlama fonksiyonu
    @objc private func resetAchievementsData() {
        print("🧹 AchievementManager: Başarı verilerini sıfırlama bildirimi alındı")
        
        // Başarıları ilk durumlarına sıfırla
        setupAchievements()
        
        // Streak verisini sıfırla
        streakData = StreakData(
            lastLoginDate: Date(),
            currentStreak: 1,
            highestStreak: 1
        )
        
        // Toplam puanları sıfırla
        totalPoints = 0
        
        // UserDefaults'taki tüm başarım verilerini temizle
        let domainName = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domainName)
        userDefaults.synchronize()
        
        // Gün zamanı başarımları için tüm sayaçları temizle
        let timeOfDayAchievementIds = ["night_owl", "night_hunter", "early_bird", "morning_champion", "lunch_break", "commuter"]
        for id in timeOfDayAchievementIds {
            userDefaults.removeObject(forKey: "\(id)_count")
        }
        
        // Yerel değişiklikleri kaydet
        saveAchievements()
        
        // Firebase'deki verileri sıfırla (eğer kullanıcı giriş yapmışsa)
        deleteAchievementsFromFirebase()
        
        // CoreData'daki verileri de sıfırla
        if let user = Auth.auth().currentUser {
            // Boş bir başarım listesi göndererek CoreData'dan silinmesini sağla
            achievementCoreDataService.saveAchievements([], for: user.uid)
        }
        
        // Uygulamaya bildir - yeniden yükleme gerekebilir
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        }
    }
    
    // Firebase'den başarımları silme fonksiyonu
    private func deleteAchievementsFromFirebase() {
        guard let user = Auth.auth().currentUser else { return }
        
        print("🗑️ Firebase'deki başarımlar siliniyor...")
        
        // 1. Yeni yapıdan kategori verilerini sil
        let userAchievementsRef = db.collection("userAchievements").document(user.uid)
        
        // Önce kategori koleksiyonundaki tüm belgeleri sil
        userAchievementsRef.collection("categories").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase kategori belgeleri alınamadı: \(error.localizedDescription)")
                return
            }
            
            // Batch işlemi oluştur
            let batch = self.db.batch()
            
            // Tüm kategori belgelerini silme işlemini batch'e ekle
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
                    print("❌ Firebase kategori başarımları silinemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Firebase'deki kategori başarımları başarıyla silindi")
                }
            }
        }
        
        // 2. Eski koleksiyon verilerini de sil
        userAchievementsRef.collection("achievements").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase başarımları silinemedi: \(error.localizedDescription)")
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
            
            // Batch işlemini uygula
            batch.commit { error in
                if let error = error {
                    print("❌ Firebase başarımları silinemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Firebase'deki eski yapı başarımları başarıyla silindi")
                }
            }
        }
    }
    
    // Günlük başarımların durumunu kontrol et
    private func checkDailyAchievementsStatus() {
        let calendar = Calendar.current
        let today = Date()
        let todayKey = "daily_completions_\(calendar.startOfDay(for: today).timeIntervalSince1970)"
        
        // Bugün için zaten kaydedilmiş tamamlanan oyun sayısını al
        let dailyCompletions = userDefaults.integer(forKey: todayKey)
        
        // Eğer bugün için hiç oyun tamamlanmamışsa ve önceki günün verileri duruyorsa, günlük görevleri sıfırla
        if dailyCompletions == 0 {
            for id in ["daily_5", "daily_10", "daily_20"] {
                if let achievement = achievements.first(where: { $0.id == id }) {
                    // Eğer başarım tamamlanmamışsa, sıfırla
                    if !achievement.isCompleted {
                        updateAchievement(id: id, status: .inProgress(currentValue: 0, requiredValue: achievement.targetValue))
                    }
                }
            }
        }
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
            
            print("🏆 Başarım açıldı: \(updatedAchievement.name)")
            
            // Firebase'e kaydet
            saveAchievementToFirestore(achievementID: achievementID)
        }
    }
    
    // Firebase'e başarıyı kaydet
    private func saveAchievementToFirestore(achievementID: String) {
        // Doğrudan tüm başarımları senkronize et, daha tutarlı bir yaklaşım
        syncWithFirebase()
        
        // Log için
        if let achievement = achievements.first(where: { $0.id == achievementID }) {
            print("🏆 Başarım Firebase'e kaydedildi: \(achievement.name)")
        }
    }
    
    // Toplam tamamlanan oyun sayısı başarımlarını kontrol et
    private func updateTotalCompletionAchievements() {
        // Tüm zorluk seviyelerindeki tamamlanmış oyun sayısını hesapla
        let totalCompleted = calculateTotalCompletedGames()
        
        // Başarımlar kontrol et
        if totalCompleted >= 100 {
            updateAchievement(id: "total_100", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "total_100", status: .inProgress(currentValue: totalCompleted, requiredValue: 100))
        }
        
        if totalCompleted >= 500 {
            updateAchievement(id: "total_500", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "total_500", status: .inProgress(currentValue: totalCompleted, requiredValue: 500))
        }
        
        if totalCompleted >= 1000 {
            updateAchievement(id: "total_1000", status: .completed(unlockDate: Date()))
            } else {
            updateAchievement(id: "total_1000", status: .inProgress(currentValue: totalCompleted, requiredValue: 1000))
        }
        
        if totalCompleted >= 5000 {
            updateAchievement(id: "total_5000", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "total_5000", status: .inProgress(currentValue: totalCompleted, requiredValue: 5000))
        }
    }
    
    // Toplam tamamlanmış oyun sayısını hesapla
    private func calculateTotalCompletedGames() -> Int {
        // Bu değerleri Firebase/LocalStorage'dan almalıyız
        // Not: Bu örnek için varsayılan bir değer kullanıyoruz
        // Gerçek uygulamada bu değer kalıcı olarak saklanmalı
        let easyCount = getCompletionCountForPrefix("easy_")
        let mediumCount = getCompletionCountForPrefix("medium_")
        let hardCount = getCompletionCountForPrefix("hard_")
        let expertCount = getCompletionCountForPrefix("expert_")
        
        return easyCount + mediumCount + hardCount + expertCount
    }
    
    // Belirli bir önek (prefix) ile başlayan başarımlardaki tamamlanan oyun sayısını hesapla
    private func getCompletionCountForPrefix(_ prefix: String) -> Int {
        // İlgili başarımlar
        let relevantAchievements = achievements.filter { $0.id.hasPrefix(prefix) }
        
        // Tamamlanmış en yüksek başarımı bul
        for achievement in relevantAchievements.sorted(by: { 
            Int($0.id.split(separator: "_")[1]) ?? 0 > Int($1.id.split(separator: "_")[1]) ?? 0 
        }) {
            if achievement.isCompleted {
                if let requiredStr = achievement.id.split(separator: "_").last, 
                   let requiredValue = Int(requiredStr) {
                    return requiredValue
                }
            }
        }
        
        // Hiçbir başarım tamamlanmadıysa, ilerleme durumundaki başarımı kontrol et
        if let firstAchievement = relevantAchievements.first(where: { $0.id == "\(prefix)1" || $0.id == "\(prefix.dropLast())_1" }) {
            return firstAchievement.currentValue
        }
        
        return 0
    }
    
    // Çeşitlilik başarımını kontrol et
    private func checkPuzzleVarietyAchievement() {
        var completedDifficulties: [SudokuBoard.Difficulty: Int] = [:]
        
        // Her zorluk seviyesi için tamamlanan oyun sayısını kontrol et
        let difficulties: [SudokuBoard.Difficulty] = [.easy, .medium, .hard, .expert]
        
        for difficulty in difficulties {
            let count = getCompletionCountForDifficulty(difficulty)
            completedDifficulties[difficulty] = count
        }
        
        // Her zorluk seviyesinden en az 5 oyun
        let minCompletionsPerDifficulty = 5
        
        let difficulitesWithMinimumCompletions = completedDifficulties.filter { $0.value >= minCompletionsPerDifficulty }.count
        
        if difficulitesWithMinimumCompletions >= difficulties.count {
            updateAchievement(id: "puzzle_variety", status: .completed(unlockDate: Date()))
        } else {
            // İlerleme güncellemesi
            updateAchievement(id: "puzzle_variety", status: .inProgress(
                currentValue: difficulitesWithMinimumCompletions * minCompletionsPerDifficulty,
                requiredValue: difficulties.count * minCompletionsPerDifficulty
            ))
        }
    }
    
    // Bir zorluk seviyesinde tamamlanmış oyun sayısını hesapla
    private func getCompletionCountForDifficulty(_ difficulty: SudokuBoard.Difficulty) -> Int {
        var prefix: String
        
        switch difficulty {
        case .easy: prefix = "easy_"
        case .medium: prefix = "medium_"
        case .hard: prefix = "hard_"
        case .expert: prefix = "expert_"
        }
        
        return getCompletionCountForPrefix(prefix)
    }
    
    // Özel saat başarımlarını kontrol et
    private func checkSpecialTimeAchievements() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // Gece yarısı çözücüsü (23:45-00:15)
        if (hour == 23 && minute >= 45) || (hour == 0 && minute <= 15) {
            updateAchievement(id: "midnight_solver", status: .completed(unlockDate: Date()))
        }
        
        // Öğle arası (12:00-14:00)
        if hour >= 12 && hour < 14 {
            incrementSpecialTimeAchievement(id: "lunch_break")
        }
        
        // Yolcu (07:00-09:00 veya 17:00-19:00)
        if (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19) {
            incrementSpecialTimeAchievement(id: "commuter")
        }
    }
    
    // Özel zaman dilimlerine göre başarı sayısını artır
    private func incrementSpecialTimeAchievement(id: String) {
        let key = "\(id)_progress"
        let progress = userDefaults.integer(forKey: key) + 1
        userDefaults.set(progress, forKey: key)
        
        let requiredValue = id == "lunch_break" ? 10 : 20
        
        if progress >= requiredValue {
            updateAchievement(id: id, status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: id, status: .inProgress(currentValue: progress, requiredValue: requiredValue))
        }
    }
    
    // Gün zamanına göre başarımları güncelle
    private func updateTimeOfDayAchievements() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Gece kuşu (22:00-06:00 arası)
        if hour >= 22 || hour < 6 {
            incrementTimeOfDayAchievement(id: "night_owl", requiredValue: 10)
            incrementTimeOfDayAchievement(id: "night_hunter", requiredValue: 30)
        }
        
        // Erken kuş (06:00-09:00 arası)
        if hour >= 6 && hour < 9 {
            incrementTimeOfDayAchievement(id: "early_bird", requiredValue: 10)
            incrementTimeOfDayAchievement(id: "morning_champion", requiredValue: 30)
        }
    }
    
    // Gün zamanı başarımları için sayaç arttırma
    private func incrementTimeOfDayAchievement(id: String, requiredValue: Int) {
        let key = "\(id)_count"
        let count = userDefaults.integer(forKey: key) + 1
        userDefaults.set(count, forKey: key)
        
        if count >= requiredValue {
            updateAchievement(id: id, status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: id, status: .inProgress(currentValue: count, requiredValue: requiredValue))
        }
    }
    
    // Sudoku Zirve başarısını kontrol et - her kategoriden en az 3 başarı
    func checkForMasterAchievement() {
        // Tamamlanmış başarıları kategorilere göre say
        var completedByCategory: [AchievementCategory: Int] = [:]
        
        for achievement in achievements where achievement.isCompleted {
            completedByCategory[achievement.category, default: 0] += 1
        }
        
        // Her kategoride en az 3 başarı var mı?
        let categoriesWithThreeOrMore = completedByCategory.filter { $0.value >= 3 }.count
        let categoriesWithFiveOrMore = completedByCategory.filter { $0.value >= 5 }.count
        let totalCategories = AchievementCategory.allCases.count
        
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
    
    // Firebase'den gelen verilerle başarıları güncelle
    private func updateAchievementsFromFirebase(_ firebaseAchievements: [[String: Any]]) {
        var updatedCount = 0
        
        for fbAchievement in firebaseAchievements {
            guard let id = fbAchievement["id"] as? String,
                  let index = achievements.firstIndex(where: { $0.id == id }) else {
                continue
            }
            
            let statusStr = fbAchievement["status"] as? String ?? "locked"
            let firebaseIsCompleted = fbAchievement["isCompleted"] as? Bool ?? false
            let localIsCompleted = achievements[index].isCompleted
            
            // Eğer yerel başarım tamamlanmış ve Firebase başarımı tamamlanmamışsa, yerel başarımı üstün tut
            if localIsCompleted && !firebaseIsCompleted {
                continue
            }
            
            // Firebase'de başarım tamamlanmışsa, yerel başarımı güncelle
            switch statusStr {
            case "locked":
                achievements[index].status = .locked
            case "inProgress":
                if let current = fbAchievement["currentValue"] as? Int,
                   let required = fbAchievement["requiredValue"] as? Int {
                    // Eğer Firebase'deki ilerleme değeri yerel ilerlemeden daha fazlaysa, güncelle
                    let localProgress = achievements[index].currentValue
                    if localProgress > current {
                        // Yerel ilerleme daha iyi, değiştirme
                    } else {
                        achievements[index].status = .inProgress(currentValue: current, requiredValue: required)
                        updatedCount += 1
                    }
                }
            case "completed":
                // Başarım tamamlanmışsa, Firebase'deki tarihi kullan
                if let unlockTimestamp = fbAchievement["unlockDate"] as? Timestamp {
                    achievements[index].status = .completed(unlockDate: unlockTimestamp.dateValue())
                    achievements[index].isUnlocked = true
                    achievements[index].completionDate = unlockTimestamp.dateValue()
                    updatedCount += 1
                } else {
                    achievements[index].status = .completed(unlockDate: Date())
                    achievements[index].isUnlocked = true
                    achievements[index].completionDate = Date()
                    updatedCount += 1
                }
            default:
                break
            }
        }
        
        print("✅ Firebase'den \(updatedCount) başarım güncellendi")
        
        // Değişiklikleri kaydet ve toplam puanları güncelle
        calculateTotalPoints()
        saveAchievements()
        
        // UI güncellemesi yap
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("AchievementsUpdated"), object: nil)
        }
    }
    
    // YENİ: Mevsimsel başarımları kontrol et (Yeni eklendi)
    private func checkSeasonalAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        
        // Hangi mevsimdeyiz?
        var season = ""
        switch month {
        case 3, 4, 5:
            season = "spring" // İlkbahar: Mart, Nisan, Mayıs
        case 6, 7, 8:
            season = "summer" // Yaz: Haziran, Temmuz, Ağustos
        case 9, 10, 11:
            season = "autumn" // Sonbahar: Eylül, Ekim, Kasım
        case 12, 1, 2:
            season = "winter" // Kış: Aralık, Ocak, Şubat
        default:
            season = "unknown"
        }
        
        if season != "unknown" {
            let achievementId = "seasonal_\(season)"
            incrementSeasonalAchievement(id: achievementId)
        }
    }
    
    // Mevsimsel başarımlar için tamamlanan oyun sayısını artır
    private func incrementSeasonalAchievement(id: String) {
        let key = "\(id)_count"
        let count = userDefaults.integer(forKey: key) + 1
        userDefaults.set(count, forKey: key)
        
        var requiredValue = 10 // Varsayılan değer
        
        // Başarıma göre gerekli değeri ayarla
        switch id {
        case "seasonal_spring":
            requiredValue = 10
        case "seasonal_summer":
            requiredValue = 15
        case "seasonal_autumn":
            requiredValue = 12
        case "seasonal_winter":
            requiredValue = 20
        default:
            break
        }
        
        if count >= requiredValue {
            updateAchievement(id: id, status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: id, status: .inProgress(currentValue: count, requiredValue: requiredValue))
        }
    }
    
    // YENİ: Saat dilimi başarımları (Yeni eklendi)
    private func checkClockBasedAchievements() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Sabah koşuşturması (7-9)
        if hour >= 7 && hour < 9 {
            incrementClockBasedAchievement(id: "clock_morning_rush")
        }
        
        // Öğle arası (12-14)
        if hour >= 12 && hour < 14 {
            incrementClockBasedAchievement(id: "clock_lunch_break")
        }
        
        // Çay saati (15-17)
        if hour >= 15 && hour < 17 {
            incrementClockBasedAchievement(id: "clock_tea_time")
        }
        
        // Altın saatler (20-22)
        if hour >= 20 && hour < 22 {
            incrementClockBasedAchievement(id: "clock_prime_time")
        }
    }
    
    // Saat dilimi başarımlarını artır
    private func incrementClockBasedAchievement(id: String) {
        let key = "\(id)_count"
        let count = userDefaults.integer(forKey: key) + 1
        userDefaults.set(count, forKey: key)
        
        let requiredValue = 5 // Tüm saat bazlı başarımlar için 5
        
        if count >= requiredValue {
            updateAchievement(id: id, status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: id, status: .inProgress(currentValue: count, requiredValue: requiredValue))
        }
    }
    
    // YENİ: Hızlı tamamlama başarımları (Yeni eklendi)
    private func checkSpeedAchievements(difficulty: SudokuBoard.Difficulty, time: TimeInterval) {
        let timeInSeconds = time
        
        switch difficulty {
        case .easy:
            if timeInSeconds < 20.0 {
                updateAchievement(id: "speed_easy_20", status: .completed(unlockDate: Date()))
            }
        case .medium:
            if timeInSeconds < 45.0 {
                updateAchievement(id: "speed_medium_45", status: .completed(unlockDate: Date()))
            }
        case .hard:
            if timeInSeconds < 90.0 {
                updateAchievement(id: "speed_hard_90", status: .completed(unlockDate: Date()))
            }
        default:
            break
        }
    }
    
    // YENİ: Hatasız seri başarımları (Yeni eklendi)
    private func checkPerfectComboAchievements(errorCount: Int) {
        if errorCount == 0 {
            // Art arda hatasız oyunları takip et
            let key = "perfect_combo_count"
            var count = userDefaults.integer(forKey: key)
            count += 1
            userDefaults.set(count, forKey: key)
            
            if count >= 5 {
                updateAchievement(id: "combo_perfect_5", status: .completed(unlockDate: Date()))
            } else {
                updateAchievement(id: "combo_perfect_5", status: .inProgress(currentValue: count, requiredValue: 5))
            }
            
            if count >= 10 {
                updateAchievement(id: "combo_perfect_10", status: .completed(unlockDate: Date()))
            } else {
                updateAchievement(id: "combo_perfect_10", status: .inProgress(currentValue: count, requiredValue: 10))
            }
        } else {
            // Hata yapılmış, seriyi sıfırla
            userDefaults.set(0, forKey: "perfect_combo_count")
        }
    }
    
    // YENİ: Hız seri başarımları (Yeni eklendi)
    private func checkSpeedComboAchievements(time: TimeInterval) {
        // Son oyunun süresini kaydet
        let key = "last_game_time"
        let lastGameTime = userDefaults.double(forKey: key)
        
        if lastGameTime > 0 && time < lastGameTime {
            // Kendi rekorunu kırdı, art arda rekor kırma sayısını artır
            let comboKey = "speed_combo_count"
            var count = userDefaults.integer(forKey: comboKey)
            count += 1
            userDefaults.set(count, forKey: comboKey)
            
            if count >= 5 {
                updateAchievement(id: "combo_speed_5", status: .completed(unlockDate: Date()))
            } else {
                updateAchievement(id: "combo_speed_5", status: .inProgress(currentValue: count, requiredValue: 5))
            }
        } else if time >= lastGameTime {
            // Rekor kırılmadı, seriyi sıfırla
            userDefaults.set(0, forKey: "speed_combo_count")
        }
        
        // Bu oyunun süresini kaydet
        userDefaults.set(time, forKey: key)
    }
    
    // YENİ: Hafta içi başarımları (Yeni eklendi)
    private func checkWeekdayAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Hafta içi günleri
        switch weekday {
        case 2: // Pazartesi
            incrementWeekdayAchievement(id: "weekday_monday")
        case 4: // Çarşamba
            incrementWeekdayAchievement(id: "weekday_wednesday")
        case 6: // Cuma
            incrementWeekdayAchievement(id: "weekday_friday")
        default:
            break
        }
    }
    
    // Belirli gün başarımlarını artır
    private func incrementWeekdayAchievement(id: String) {
        let key = "\(id)_count"
        let count = userDefaults.integer(forKey: key) + 1
        userDefaults.set(count, forKey: key)
        
        let requiredValue = 10 // Tüm gün bazlı başarımlar için 10
        
        if count >= requiredValue {
            updateAchievement(id: id, status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: id, status: .inProgress(currentValue: count, requiredValue: requiredValue))
        }
    }
    
    // YENİ: Oyun stili başarımları (Yeni eklendi)
    private func checkGameStyleAchievements(hintCount: Int, errorCount: Int) {
        // Metodolojik Çözücü (Not almadan oyunu tamamlama)
        let notesUsed = userDefaults.bool(forKey: "notes_used_in_current_game")
        if !notesUsed {
            updateAchievement(id: "style_methodical", status: .completed(unlockDate: Date()))
        }
        
        // Mükemmeliyetçi (Tüm notları kullanma)
        let allNotesUsed = userDefaults.bool(forKey: "all_notes_used_in_current_game")
        if allNotesUsed {
            updateAchievement(id: "style_perfectionist", status: .completed(unlockDate: Date()))
        }
        
        // Hızlı Girişçi (30 saniye içinde 30 hücre) - Bu başarım için ana oyun kodunda lojik eklenmesi gerekebilir
        // Bu başarım için ayrı bir fonksiyon kullanılabilir
    }
    
    // YENİ: Tamamlanan hücre sayısı başarımları (Yeni eklendi)
    private func updateCellsCompletedAchievements() {
        // Her Sudoku 81 hücreye sahip, bu yüzden her oyun tamamlandığında 81 hücre ekliyoruz
        let key = "total_cells_completed"
        let currentCells = userDefaults.integer(forKey: key)
        let newTotal = currentCells + 81
        userDefaults.set(newTotal, forKey: key)
        
        // Başarımları kontrol et
        if newTotal >= 500 {
            updateAchievement(id: "stats_500_cells", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "stats_500_cells", status: .inProgress(currentValue: newTotal, requiredValue: 500))
        }
        
        if newTotal >= 1000 {
            updateAchievement(id: "stats_1000_cells", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "stats_1000_cells", status: .inProgress(currentValue: newTotal, requiredValue: 1000))
        }
        
        if newTotal >= 5000 {
            updateAchievement(id: "stats_5000_cells", status: .completed(unlockDate: Date()))
        } else {
            updateAchievement(id: "stats_5000_cells", status: .inProgress(currentValue: newTotal, requiredValue: 5000))
        }
    }
    
    // YENİ: Özel gün başarımları (Yeni eklendi)
    private func checkSpecialDayAchievements() {
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let month = calendar.component(.month, from: today)
        
        // Yeni yıl kontrolü
        if day == 1 && month == 1 {
            updateAchievement(id: "holiday_new_year", status: .completed(unlockDate: Date()))
        }
        
        // Doğum günü başarımını yılın belirli bir gününde (örn: 15 Temmuz) herkes için otomatik olarak aç
        // Bu sabit tarih seçimi ile oyuncular belirli bir günde oynadıklarında başarımı kazanır
        if day == 15 && month == 7 {  // 15 Temmuz - örnek tarih
            updateAchievement(id: "birthday_player", status: .completed(unlockDate: Date()))
        }
        
        // Hafta sonu canavarı - Bir hafta sonunda 20 oyun
        // Bu başarım için ekstra bir fonksiyon gerekebilir
        checkWeekendWarriorAchievement()
    }
    
    // Hafta sonu canavarı başarımını kontrol et
    private func checkWeekendWarriorAchievement() {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Cumartesi (7) veya Pazar (1) günü mü?
        if weekday == 1 || weekday == 7 {
            // Bugünün tarihini al
            let todayKey = "weekend_warrior_date"
            let todayCountKey = "weekend_warrior_count"
            
            // Kayıtlı tarihi kontrol et
            let savedDateTimeInterval = userDefaults.double(forKey: todayKey)
            let savedDate = Date(timeIntervalSince1970: savedDateTimeInterval)
            
            // Bugün aynı hafta sonu mu kontrol et
            let isSameWeekend = calendar.isDate(savedDate, equalTo: today, toGranularity: .weekOfYear) &&
                               (calendar.component(.weekday, from: savedDate) == 1 || 
                                calendar.component(.weekday, from: savedDate) == 7)
            
            if isSameWeekend || savedDateTimeInterval == 0 {
                // Sayacı artır
                let currentCount = userDefaults.integer(forKey: todayCountKey) + 1
                userDefaults.set(currentCount, forKey: todayCountKey)
                
                // Başarım kontrolü
                if currentCount >= 20 {
                    updateAchievement(id: "holiday_weekend", status: .completed(unlockDate: Date()))
                } else {
                    updateAchievement(id: "holiday_weekend", status: .inProgress(currentValue: currentCount, requiredValue: 20))
                }
                
                // Tarihi kaydet
                userDefaults.set(today.timeIntervalSince1970, forKey: todayKey)
            } else {
                // Yeni hafta sonu, sayacı sıfırla
                userDefaults.set(1, forKey: todayCountKey)
                userDefaults.set(today.timeIntervalSince1970, forKey: todayKey)
            }
        }
    }
} 