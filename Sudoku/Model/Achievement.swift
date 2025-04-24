import Foundation
import SwiftUI

// Başarım kategori enumı
enum AchievementCategory: String, Codable, CaseIterable, Identifiable {
    case difficulty = "Zorluk"
    case streak = "Seri"
    case time = "Zaman"
    case special = "Özel"
    case beginner = "Başlangıç"
    case intermediate = "Orta Seviye"
    case expert = "Uzman"
    
    // Identifiable protokolü için id özelliği
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .difficulty: return "chart.bar.fill"
        case .streak: return "flame.fill"  
        case .time: return "clock.fill"
        case .special: return "sparkles"
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .expert: return "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .difficulty: return .blue
        case .streak: return .orange
        case .time: return .green
        case .special: return .purple
        case .beginner: return .green
        case .intermediate: return .orange
        case .expert: return .red
        }
    }
}

// AchievementStatus enum düzeltildi - associative value yerine enum ve struct
enum AchievementStatus: Codable, Equatable {
    case locked
    case inProgress(currentValue: Int, requiredValue: Int)
    case completed(unlockDate: Date)
    
    var isCompleted: Bool {
        switch self {
        case .completed:
            return true
        default:
            return false
        }
    }
    
    var progress: Double {
        switch self {
        case .locked:
            return 0.0
        case .inProgress(let current, let required):
            return Double(current) / Double(required)
        case .completed:
            return 1.0
        }
    }
}

// Temel başarım yapısı
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: AchievementCategory
    let iconName: String
    let targetValue: Int
    let pointValue: Int
    
    // İzleme için özellikler
    var currentValue: Int = 0
    var isUnlocked: Bool = false
    var unlockedDate: Date?
    var completionDate: Date?
    var status: AchievementStatus = .locked
    var rewardPoints: Int = 0
    
    // Kullanıcı arayüzü için yardımcı özellikler
    var progress: Double {
        if targetValue == 0 { return 0 }
        return status.progress
    }
    
    var isCompleted: Bool {
        return isUnlocked || completionDate != nil || status.isCompleted
    }
    
    var colorCode: Color {
        return category.color
    }
    
    var formattedCompletionDate: String {
        guard let date = completionDate ?? unlockedDate else { return "Tamamlanmadı" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    // Başlangıçta kullanılan uyumluluk yapıcısı
    init(id: String, name: String, description: String, category: AchievementCategory, iconName: String, requiredValue: Int) {
        self.id = id
        self.name = name 
        self.description = description
        self.category = category
        self.iconName = iconName
        self.targetValue = requiredValue
        self.pointValue = category == .special ? 50 : 25
        self.rewardPoints = self.pointValue
    }
    
    // Tam yapıcı
    init(id: String, name: String, description: String, category: AchievementCategory, iconName: String, targetValue: Int, pointValue: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.iconName = iconName
        self.targetValue = targetValue
        self.pointValue = pointValue
        self.rewardPoints = pointValue
    }
    
    // Eşitlik kontrolü
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Title için yardımcı özellik
    var title: String {
        return name
    }
    
    // Firebase için Dictionary dönüşümü
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description,
            "category": category.rawValue,
            "iconName": iconName,
            "targetValue": targetValue,
            "currentValue": currentValue,
            "isUnlocked": isUnlocked,
            "unlockedDate": unlockedDate as Any,
            "completionDate": completionDate as Any,
            "pointValue": pointValue,
            "rewardPoints": rewardPoints
        ]
    }
    
    // Firebase'den oluşturma
    static func fromDictionary(_ dict: [String: Any]) -> Achievement? {
        guard 
            let id = dict["id"] as? String,
            let name = dict["name"] as? String,
            let description = dict["description"] as? String,
            let categoryRaw = dict["category"] as? String,
            let category = AchievementCategory(rawValue: categoryRaw),
            let iconName = dict["iconName"] as? String,
            let targetValue = dict["targetValue"] as? Int,
            let pointValue = dict["pointValue"] as? Int
        else {
            return nil
        }
        
        var achievement = Achievement(
            id: id,
            name: name,
            description: description,
            category: category,
            iconName: iconName,
            targetValue: targetValue,
            pointValue: pointValue
        )
        
        achievement.currentValue = dict["currentValue"] as? Int ?? 0
        achievement.isUnlocked = dict["isUnlocked"] as? Bool ?? false
        achievement.unlockedDate = dict["unlockedDate"] as? Date
        achievement.completionDate = dict["completionDate"] as? Date
        achievement.rewardPoints = dict["rewardPoints"] as? Int ?? pointValue
        
        return achievement
    }
}

// Başarım listesi yapısı
struct AchievementList: Identifiable {
    let id = UUID()
    let category: AchievementCategory
    var achievements: [Achievement]
    
    var title: String {
        return category.rawValue + " Başarımları"
    }
} 