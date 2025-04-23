import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "user_achievements"
    private let streakKey = "user_streak_data"
    
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var totalPoints: Int = 0
    @Published var showAchievementAlert: Bool = false
    @Published var lastUnlockedAchievement: Achievement? = nil
    
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
    }
    
    // Başarıları oluştur ve hazırla
    private func setupAchievements() {
        achievements = [
            // Başlangıç başarıları - Kolay seviye
            Achievement(id: "easy_1", name: "İlk Adım", description: "İlk Kolay Sudoku'yu tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 1),
            Achievement(id: "easy_10", name: "Kolay Uzman", description: "10 Kolay Sudoku tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 10),
            Achievement(id: "easy_50", name: "Kolay Üstat", description: "50 Kolay Sudoku tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 50),
            Achievement(id: "easy_100", name: "Kolay Efsane", description: "100 Kolay Sudoku tamamla", category: .beginner, iconName: "leaf.fill", requiredValue: 100),
            
            // Orta seviye başarıları
            Achievement(id: "medium_1", name: "Zorluğa Adım", description: "İlk Orta Sudoku'yu tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 1),
            Achievement(id: "medium_10", name: "Orta Seviye Uzman", description: "10 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 10),
            Achievement(id: "medium_50", name: "Orta Seviye Üstat", description: "50 Orta seviye Sudoku tamamla", category: .intermediate, iconName: "flame.fill", requiredValue: 50),
            
            // Zor ve Uzman başarıları
            Achievement(id: "hard_1", name: "Zor Meydan Okuma", description: "İlk Zor Sudoku'yu tamamla", category: .expert, iconName: "bolt.fill", requiredValue: 1),
            Achievement(id: "hard_10", name: "Zor Uzman", description: "10 Zor Sudoku tamamla", category: .expert, iconName: "bolt.fill", requiredValue: 10),
            Achievement(id: "expert_1", name: "Uzman Meydan Okuma", description: "İlk Uzman Sudoku'yu tamamla", category: .expert, iconName: "star.fill", requiredValue: 1),
            Achievement(id: "expert_5", name: "Gerçek Sudoku Ustası", description: "5 Uzman Sudoku tamamla", category: .expert, iconName: "star.fill", requiredValue: 5),
            
            // Devamlılık başarıları
            Achievement(id: "streak_3", name: "Devam Eden Merak", description: "3 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar", requiredValue: 3),
            Achievement(id: "streak_7", name: "Haftalık Rutin", description: "7 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar", requiredValue: 7),
            Achievement(id: "streak_30", name: "Sudoku Tutkunu", description: "30 gün üst üste Sudoku oyna", category: .streak, iconName: "calendar.badge.clock", requiredValue: 30),
            
            // Zaman başarıları
            Achievement(id: "time_easy_3", name: "Hızlı Kolay", description: "Kolay Sudoku'yu 3 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_medium_5", name: "Hızlı Orta", description: "Orta Sudoku'yu 5 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            Achievement(id: "time_hard_10", name: "Hızlı Zor", description: "Zor Sudoku'yu 10 dakikadan kısa sürede tamamla", category: .time, iconName: "timer", requiredValue: 1),
            
            // Özel başarılar
            Achievement(id: "no_errors", name: "Kusursuz", description: "Hiç hata yapmadan bir Sudoku tamamla", category: .special, iconName: "checkmark.seal.fill", requiredValue: 1),
            Achievement(id: "no_hints", name: "Yardımsız", description: "Hiç ipucu kullanmadan bir Sudoku tamamla", category: .special, iconName: "lightbulb.slash.fill", requiredValue: 1),
            Achievement(id: "all_difficulties", name: "Tam Set", description: "Her zorluk seviyesinden en az bir Sudoku tamamla", category: .special, iconName: "square.stack.3d.up.fill", requiredValue: 4)
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
                lastUnlockedAchievement = achievements[index]
                showAchievementAlert = true
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
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
        case .medium:
            prefixId = "medium_"
        case .hard:
            prefixId = "hard_"
        case .expert:
            prefixId = "expert_"
        }
        
        // Her zorluk seviyesi başarısını kontrol et
        for achievement in achievements where achievement.id.hasPrefix(prefixId) {
            // Mevcut durumu al
            let currentStatus = achievement.status
            var newStatus: AchievementStatus
            
            switch currentStatus {
            case .locked:
                // Başlat
                newStatus = .inProgress(currentValue: 1, requiredValue: achievement.requiredValue)
            case .inProgress(let current, let required):
                let newCount = current + 1
                if newCount >= required {
                    // Tamamla
                    newStatus = .completed(unlockDate: Date())
                } else {
                    // İlerlet
                    newStatus = .inProgress(currentValue: newCount, requiredValue: required)
                }
            case .completed:
                // Zaten tamamlanmış
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
        }
        
        // İpuçsuz oyun
        if hintCount == 0 {
            updateAchievement(id: "no_hints", status: .completed(unlockDate: Date()))
        }
    }
    
    // Oyun tamamlandığında tüm başarıları güncelle
    func processGameCompletion(difficulty: SudokuBoard.Difficulty, time: TimeInterval, errorCount: Int, hintCount: Int) {
        // Zorluk başarıları
        updateDifficultyAchievements(difficulty: difficulty)
        
        // Zaman başarıları
        updateTimeAchievements(difficulty: difficulty, time: time)
        
        // Özel başarılar
        updateSpecialAchievements(errorCount: errorCount, hintCount: hintCount)
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
            } else if daysBetween > 1 {
                // Streak bozuldu
                streakData.currentStreak = 1
            } else if daysBetween == 0 {
                // Aynı gün, bir şey yapma
            }
        }
        
        // Son giriş tarihini güncelle ve kaydet
        streakData.lastLoginDate = today
        self.streakData = streakData
        saveAchievements()
    }
    
    // Streak başarılarını güncelle
    private func updateStreakAchievements(streak: Int) {
        for achievement in achievements where achievement.id.hasPrefix("streak_") {
            if let requiredStreak = Int(achievement.id.split(separator: "_")[1]), streak >= requiredStreak {
                updateAchievement(id: achievement.id, status: .completed(unlockDate: Date()))
            } else if !achievement.isCompleted {
                updateAchievement(id: achievement.id, status: .inProgress(
                    currentValue: streak,
                    requiredValue: achievement.requiredValue
                ))
            }
        }
    }
    
    // Firebase ile senkronizasyon
    private func syncWithFirebase() {
        // Sadece giriş yapmış kullanıcılar için senkronize et
        guard let user = Auth.auth().currentUser else { return }
        
        let userData: [String: Any] = [
            "achievements": encodeAchievementsForFirebase(),
            "totalPoints": totalPoints,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(user.uid).updateData(userData) { error in
            if let error = error {
                print("❌ Başarılar Firestore'a kaydedilemedi: \(error.localizedDescription)")
            } else {
                print("✅ Başarılar Firestore'a kaydedildi")
            }
        }
    }
    
    // Firebase için başarıları kodla
    private func encodeAchievementsForFirebase() -> [[String: Any]] {
        return achievements.map { achievement in
            var achievementDict: [String: Any] = [
                "id": achievement.id,
                "isCompleted": achievement.isCompleted
            ]
            
            switch achievement.status {
            case .locked:
                achievementDict["status"] = "locked"
                achievementDict["progress"] = 0
            case .inProgress(let current, let required):
                achievementDict["status"] = "inProgress"
                achievementDict["progress"] = Double(current) / Double(required)
                achievementDict["currentValue"] = current
                achievementDict["requiredValue"] = required
            case .completed(let date):
                achievementDict["status"] = "completed"
                achievementDict["progress"] = 1.0
                achievementDict["unlockDate"] = date
            }
            
            return achievementDict
        }
    }
    
    // Firebase'den başarıları yükle
    func loadAchievementsFromFirebase() {
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("users").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firestore'dan başarılar alınamadı: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists, let data = document.data(),
               let achievementsData = data["achievements"] as? [[String: Any]] {
                
                // Firebase verisi varsa, yerel verileri güncelle
                self.updateAchievementsFromFirebase(achievementsData)
            } else {
                // Firebase verisi yoksa, mevcut yerel verileri gönder
                self.syncWithFirebase()
            }
        }
    }
    
    // Firebase'den gelen verilerle başarıları güncelle
    private func updateAchievementsFromFirebase(_ firebaseAchievements: [[String: Any]]) {
        for fbAchievement in firebaseAchievements {
            guard let id = fbAchievement["id"] as? String,
                  let index = achievements.firstIndex(where: { $0.id == id }) else {
                continue
            }
            
            let statusStr = fbAchievement["status"] as? String ?? "locked"
            
            switch statusStr {
            case "locked":
                achievements[index].status = .locked
            case "inProgress":
                if let current = fbAchievement["currentValue"] as? Int,
                   let required = fbAchievement["requiredValue"] as? Int {
                    achievements[index].status = .inProgress(currentValue: current, requiredValue: required)
                }
            case "completed":
                if let unlockTimestamp = fbAchievement["unlockDate"] as? Timestamp {
                    achievements[index].status = .completed(unlockDate: unlockTimestamp.dateValue())
                } else {
                    achievements[index].status = .completed(unlockDate: Date())
                }
            default:
                break
            }
        }
        
        // Değişiklikleri kaydet ve toplam puanları güncelle
        calculateTotalPoints()
        saveAchievements()
    }
} 