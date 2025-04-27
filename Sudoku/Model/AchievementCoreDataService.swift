import Foundation
import CoreData

class AchievementCoreDataService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Achievements Management
    
    func saveAchievements(_ achievements: [Achievement], for userID: String) {
        let context = persistenceController.container.viewContext
        
        // Fetch user or create if doesn't exist
        let user = fetchOrCreateUser(withFirebaseUID: userID, in: context)
        
        // Delete existing achievements to prevent duplicates
        let fetchRequest: NSFetchRequest<AchievementEntity> = AchievementEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "user.firebaseUID == %@", userID)
        
        do {
            let existingAchievements = try context.fetch(fetchRequest)
            for achievement in existingAchievements {
                context.delete(achievement)
            }
        } catch {
            logError("Error fetching existing achievements: \(error)")
        }
        
        // Create new achievement entities
        for achievement in achievements {
            let achievementEntity = AchievementEntity(context: context)
            achievementEntity.id = achievement.id
            achievementEntity.name = achievement.name
            achievementEntity.desc = achievement.description
            achievementEntity.category = achievement.category.rawValue // Category'i rawValue olarak kaydet
            achievementEntity.iconName = achievement.iconName
            achievementEntity.isUnlocked = achievement.isUnlocked
            achievementEntity.currentValue = Int32(achievement.currentValue)
            achievementEntity.targetValue = Int32(achievement.targetValue)
            achievementEntity.rewardPoints = Int32(achievement.rewardPoints)
            achievementEntity.pointValue = Int32(achievement.pointValue)
            
            if let unlockedDate = achievement.unlockedDate {
                achievementEntity.unlockedDate = unlockedDate
            }
            
            if let completionDate = achievement.completionDate {
                achievementEntity.completionDate = completionDate
            }
            
            achievementEntity.lastSyncTimestamp = Date()
            achievementEntity.user = user
        }
        
        saveContext()
    }
    
    func loadAchievements(for userID: String) -> [Achievement] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AchievementEntity> = AchievementEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "user.firebaseUID == %@", userID)
        
        do {
            let achievementEntities = try context.fetch(fetchRequest)
            return achievementEntities.map { entity in
                // Kategorinin enum değerini güvenli şekilde al
                let categoryString = entity.category ?? "special" 
                let category = AchievementCategory(rawValue: categoryString) ?? .special
                
                var achievement = Achievement(
                    id: entity.id ?? "",
                    name: entity.name ?? "",
                    description: entity.desc ?? "",
                    category: category,
                    iconName: entity.iconName ?? "",
                    targetValue: Int(entity.targetValue),
                    pointValue: Int(entity.pointValue)
                )
                
                achievement.currentValue = Int(entity.currentValue)
                achievement.isUnlocked = entity.isUnlocked
                achievement.unlockedDate = entity.unlockedDate
                achievement.completionDate = entity.completionDate
                
                // Status özelliğini doğru şekilde ayarla
                if achievement.isUnlocked || achievement.completionDate != nil {
                    achievement.status = .completed(unlockDate: achievement.completionDate ?? achievement.unlockedDate ?? Date())
                } else if achievement.currentValue > 0 {
                    achievement.status = .inProgress(currentValue: achievement.currentValue, requiredValue: Int(entity.targetValue))
                } else {
                    achievement.status = .locked
                }
                
                return achievement
            }
        } catch {
            logError("Error loading achievements from CoreData: \(error)")
            return []
        }
    }
    
    func getLastSyncTimestamp(for userID: String) -> Date? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AchievementEntity> = AchievementEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "user.firebaseUID == %@", userID)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastSyncTimestamp", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let achievements = try context.fetch(fetchRequest)
            return achievements.first?.lastSyncTimestamp
        } catch {
            logError("Error fetching last sync timestamp: \(error)")
            return nil
        }
    }
    
    func updateAchievement(_ achievement: Achievement, for userID: String) {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AchievementEntity> = AchievementEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND user.firebaseUID == %@", achievement.id, userID)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let achievementEntity = results.first {
                achievementEntity.isUnlocked = achievement.isUnlocked
                achievementEntity.currentValue = Int32(achievement.currentValue)
                achievementEntity.unlockedDate = achievement.unlockedDate
                achievementEntity.completionDate = achievement.completionDate
                achievementEntity.lastSyncTimestamp = Date()
                
                // Status değerini CoreData'ya kaydet
                switch achievement.status {
                case .inProgress(let current, _):
                    // CoreData'ya currentValue değerini kaydet
                    achievementEntity.currentValue = Int32(current)
                case .completed:
                    // Tamamlanmış durum için tüm bayrakları ayarla
                    achievementEntity.isUnlocked = true
                    achievementEntity.currentValue = achievementEntity.targetValue
                case .locked:
                    achievementEntity.currentValue = 0
                    achievementEntity.isUnlocked = false
                }
                
                saveContext()
            }
        } catch {
            logError("Error updating achievement: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchOrCreateUser(withFirebaseUID uid: String, in context: NSManagedObjectContext) -> User {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "firebaseUID == %@", uid)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let user = results.first {
                return user
            } else {
                let user = User(context: context)
                user.id = UUID()
                user.firebaseUID = uid
                user.registrationDate = Date()
                return user
            }
        } catch {
            logError("Error fetching user: \(error)")
            let user = User(context: context)
            user.id = UUID()
            user.firebaseUID = uid
            user.registrationDate = Date()
            return user
        }
    }
    
    private func saveContext() {
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logError("Error saving context: \(error)")
            }
        }
    }
}