import Foundation

// Başarı kategorileri
enum AchievementCategory: String, Codable, CaseIterable, Identifiable {
    case beginner = "Başlangıç"
    case intermediate = "Orta Seviye"
    case expert = "Uzman"
    case streak = "Devamlılık"
    case special = "Özel"
    case time = "Zaman"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .expert: return "star.fill"
        case .streak: return "calendar"
        case .special: return "checkmark.seal.fill"
        case .time: return "timer"
        }
    }
    
    var color: String {
        switch self {
        case .beginner: return "achievement.beginner"
        case .intermediate: return "achievement.intermediate"
        case .expert: return "achievement.expert"
        case .streak: return "achievement.streak"
        case .special: return "achievement.special"
        case .time: return "achievement.time"
        }
    }
}

// Başarı durumu
enum AchievementStatus: Codable {
    case locked
    case inProgress(currentValue: Int, requiredValue: Int)
    case completed(unlockDate: Date)
    
    var isCompleted: Bool {
        switch self {
        case .completed: return true
        default: return false
        }
    }
    
    var progress: Double {
        switch self {
        case .locked: return 0.0
        case .inProgress(let current, let required):
            return min(1.0, Double(current) / Double(required))
        case .completed: return 1.0
        }
    }
}

// Başarı modeli
struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: AchievementCategory
    let iconName: String
    let requiredValue: Int
    var status: AchievementStatus = .locked
    
    var isCompleted: Bool {
        status.isCompleted
    }
    
    var progress: Double {
        status.progress
    }
    
    // Tamamlandığında ödül puanı
    var rewardPoints: Int {
        switch category {
        case .beginner: return 10
        case .intermediate: return 20
        case .expert: return 50
        case .streak: return 30
        case .special: return 40
        case .time: return 25
        }
    }
} 