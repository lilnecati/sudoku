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
    
    // MARK: - Codable Conformance (Özel Implementasyon)
    
    // Hangi case olduğunu ayırt etmek için anahtar
    private enum CodingKeys: String, CodingKey {
        case statusType
        case currentValue
        case requiredValue
        case unlockDate
    }
    
    // Hangi case olduğunu belirtmek için ek enum
    private enum StatusType: String, Codable {
        case locked
        case inProgress
        case completed
    }
    
    // Özel Kodlama
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .locked:
            // logDebug("🔍 [Codable][Status] Encoding statusType: locked...") // Commented out
            try container.encode(StatusType.locked.rawValue, forKey: .statusType)
            // logDebug("🔍 [Codable][Status] Encoded statusType: locked.") // Commented out
        case .inProgress(let currentValue, let requiredValue):
            // logDebug("🔍 [Codable][Status] Encoding statusType: inProgress...") // Commented out
            try container.encode(StatusType.inProgress.rawValue, forKey: .statusType)
            // logDebug("🔍 [Codable][Status] Encoding currentValue: \(currentValue)...") // Commented out
            try container.encode(currentValue, forKey: .currentValue)
            // logDebug("🔍 [Codable][Status] Encoding requiredValue: \(requiredValue)...") // Commented out
            try container.encode(requiredValue, forKey: .requiredValue)
            // logDebug("🔍 [Codable][Status] Encoded statusType: inProgress.") // Commented out
        case .completed(let unlockDate):
            // logDebug("🔍 [Codable][Status] Encoding statusType: completed...") // Commented out
            try container.encode(StatusType.completed.rawValue, forKey: .statusType)
            // logDebug("🔍 [Codable][Status] Encoding unlockDate: \(unlockDate)...") // Commented out
            try container.encode(unlockDate, forKey: .unlockDate)
            // logDebug("🔍 [Codable][Status] Encoded statusType: completed.") // Commented out
        }
    }
    
    // Özel Çözme (Decoder)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let statusType = try container.decode(StatusType.self, forKey: .statusType)
        
        switch statusType {
        case .locked:
            self = .locked
        case .inProgress:
            let currentValue = try container.decode(Int.self, forKey: .currentValue)
            let requiredValue = try container.decode(Int.self, forKey: .requiredValue)
            self = .inProgress(currentValue: currentValue, requiredValue: requiredValue)
        case .completed:
            let dateString = try container.decode(String.self, forKey: .unlockDate)
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: dateString) {
                self = .completed(unlockDate: date)
            } else {
                // Tarih çözülemezse hata fırlat
                throw DecodingError.dataCorruptedError(forKey: .unlockDate, in: container, debugDescription: "Date string does not match format expected by formatter.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
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
    var lastSyncDate: Date? = nil
    
    // MARK: - Codable Conformance (Özel Implementasyon)
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, iconName, targetValue, pointValue
        case currentValue, isUnlocked, unlockedDate, completionDate, status, rewardPoints, lastSyncDate
    }
    
    // Özel kodlama fonksiyonu
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding id...") // Commented out
        try container.encode(id, forKey: .id)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding name...") // Commented out
        try container.encode(name, forKey: .name)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding description...") // Commented out
        try container.encode(description, forKey: .description)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding category...") // Commented out
        try container.encode(category.rawValue, forKey: .category) // Encode raw value
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding iconName...") // Commented out
        try container.encode(iconName, forKey: .iconName)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding targetValue...") // Commented out
        try container.encode(targetValue, forKey: .targetValue)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding pointValue...") // Commented out
        try container.encode(pointValue, forKey: .pointValue)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding currentValue...") // Commented out
        try container.encode(currentValue, forKey: .currentValue)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding isUnlocked...") // Commented out
        try container.encode(isUnlocked, forKey: .isUnlocked)

        // logDebug("🔍 [Codable][Ach:\(id)] Encoding status for key \(CodingKeys.status)...") // Commented out
        try container.encode(status, forKey: .status)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoded status successfully.") // Commented out
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding rewardPoints...") // Commented out
        try container.encode(rewardPoints, forKey: .rewardPoints)
        // logDebug("🔍 [Codable][Ach:\(id)] Encoded rewardPoints.") // Commented out

        // --- Date Encoding ---
        // logDebug("🔍 [Codable][Ach:\(id)] Encoding unlockedDate for key \(CodingKeys.unlockedDate)...") // Commented out
        if let date = unlockedDate {
            // logDebug("🔍 [Codable][Ach:\(id)]   Value: \(date)") // Commented out
            try container.encode(date, forKey: .unlockedDate)
        } else {
            // logDebug("🔍 [Codable][Ach:\(id)]   Value: nil") // Commented out
            try container.encodeNil(forKey: .unlockedDate)
        }
        // logDebug("🔍 [Codable][Ach:\(id)] Encoded unlockedDate successfully.") // Commented out

        // logDebug("🔍 [Codable][Ach:\(id)] Encoding completionDate for key \(CodingKeys.completionDate)...") // Commented out
        if let date = completionDate {
            // logDebug("🔍 [Codable][Ach:\(id)]   Value: \(date)") // Commented out
            try container.encode(date, forKey: .completionDate)
        } else {
            // logDebug("🔍 [Codable][Ach:\(id)]   Value: nil") // Commented out
            try container.encodeNil(forKey: .completionDate)
        }
        // logDebug("🔍 [Codable][Ach:\(id)] Encoded completionDate successfully.") // Commented out

        // logDebug("🔍 [Codable][Ach:\(id)] Encoding lastSyncDate for key \(CodingKeys.lastSyncDate)...") // Commented out
        if let date = lastSyncDate {
            // logDebug("🔍 [Codable][Ach:\(id)]   Value: \(date)") // Commented out
            try container.encode(date, forKey: .lastSyncDate)
        } else {
            // logDebug("🔍 [Codable][Ach:\(id)]   Value: nil") // Commented out
            try container.encodeNil(forKey: .lastSyncDate)
        }
        // logDebug("🔍 [Codable][Ach:\(id)] Encoded lastSyncDate successfully.") // Commented out
    }
    
    // Özel çözme fonksiyonu (Gerekirse eklenebilir, şimdilik otomatik yeterli olabilir)
    // init(from decoder: Decoder) throws { ... }
    
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
            "rewardPoints": rewardPoints,
            "lastSyncDate": lastSyncDate as Any,
            "lastUpdated": Date()
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
        achievement.lastSyncDate = dict["lastSyncDate"] as? Date
        
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