import Foundation
import CoreData

// CoreData entity'leri için extension'lar
extension NSManagedObject {
    // Ortak yardımcı metodlar
    func getUUID() -> UUID? {
        return value(forKey: "id") as? UUID
    }
    
    func getDate(key: String) -> Date {
        return value(forKey: key) as? Date ?? Date()
    }
    
    func getString(key: String, defaultValue: String = "") -> String {
        return value(forKey: key) as? String ?? defaultValue
    }
    
    func getDouble(key: String, defaultValue: Double = 0.0) -> Double {
        return value(forKey: key) as? Double ?? defaultValue
    }
    
    func getData(key: String) -> Data? {
        return value(forKey: key) as? Data
    }
    
    func getName() -> String {
        return getString(key: "name", defaultValue: "İsimsiz")
    }
    
    func getUsername() -> String {
        return getString(key: "username", defaultValue: "")
    }
    
    func getEmail() -> String {
        return getString(key: "email", defaultValue: "")
    }
}

// MARK: - User Helper Methods
extension User {
    func getPlayerName() -> String {
        return getName()
    }
    
    func getRegistrationDate() -> Date {
        return getDate(key: "registrationDate")
    }
    
    func isUserLoggedIn() -> Bool {
        return value(forKey: "isLoggedIn") as? Bool ?? false
    }
}

// MARK: - HighScore Helper Methods
extension HighScore {
    func getPlayerName() -> String {
        return getString(key: "playerName", defaultValue: "İsimsiz")
    }
    
    func getScoreDate() -> Date {
        return getDate(key: "date")
    }
    
    func getDifficulty() -> String {
        return getString(key: "difficulty", defaultValue: "Kolay")
    }
    
    func getElapsedTime() -> Double {
        return getDouble(key: "elapsedTime")
    }
}

// MARK: - SavedGame Helper Methods
extension SavedGame {
    func getGameDate() -> Date {
        return getDate(key: "dateCreated")
    }
    
    func getDifficulty() -> String {
        return getString(key: "difficulty", defaultValue: "Kolay")
    }
    
    func getElapsedTime() -> Double {
        return getDouble(key: "elapsedTime")
    }
    
    func getBoardState() -> Data? {
        return getData(key: "boardState")
    }
} 