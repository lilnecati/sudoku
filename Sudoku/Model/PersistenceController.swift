import CoreData
import Foundation

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "SudokuModel")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("CoreData yüklenemedi: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - User Management
    
    func registerUser(username: String, password: String, email: String, name: String) -> Bool {
        let context = container.viewContext
        let user = User(context: context)
        
        user.username = username
        user.password = password 
        user.email = email
        user.name = name
        user.registrationDate = Date()
        user.isLoggedIn = true
        
        do {
            try context.save()
            return true
        } catch {
            print("Kullanıcı kaydı başarısız: \(error)")
            return false
        }
    }
    
    func loginUser(username: String, password: String) -> NSManagedObject? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@ AND password == %@", username, password)
        
        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.isLoggedIn = true
                try? context.save()
                return user
            }
        } catch {
            print("Giriş başarısız: \(error)")
        }
        return nil
    }
    
    func fetchUser(username: String) -> NSManagedObject? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@", username)
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("Kullanıcı bulunamadı: \(error)")
            return nil
        }
    }
    
    func logoutCurrentUser() {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "isLoggedIn == YES")
        
        do {
            let users = try context.fetch(request)
            users.forEach { $0.isLoggedIn = false }
            try context.save()
        } catch {
            print("Çıkış hatası: \(error)")
        }
    }
    
    func getCurrentUser() -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "isLoggedIn == YES")
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("Kullanıcı bilgisi alınamadı: \(error)")
        }
        return nil
    }
    
    // MARK: - Game Management
    
    func saveGame(board: [[Int]], difficulty: String, elapsedTime: TimeInterval) {
        let context = container.viewContext
        let game = SavedGame(context: context)
        
        // Tahtayı serialleştir (boardState artık dizi olarak serialleştirilecek)
        let boardDict: [String: Any] = [
            "board": board,
            "difficulty": difficulty
        ]
        
        game.boardState = try? JSONSerialization.data(withJSONObject: boardDict)
        game.difficulty = difficulty
        game.elapsedTime = elapsedTime
        game.dateCreated = Date()
        
        // Eğer oturum açmış bir kullanıcı varsa, oyunu onunla ilişkilendir
        if let currentUser = getCurrentUser() {
            game.setValue(currentUser, forKey: "user")
        }
        
        do {
            try context.save()
        } catch {
            print("Oyun kaydedilemedi: \(error)")
        }
    }
    
    func loadSavedGames() -> [SavedGame] {
        let context = container.viewContext
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        // Eğer oturum açmış bir kullanıcı varsa, sadece onun oyunlarını yükleyin
        if let currentUser = getCurrentUser() {
            request.predicate = NSPredicate(format: "user == %@", currentUser)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedGame.dateCreated, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Kayıtlı oyunlar yüklenemedi: \(error)")
        }
        return []
    }
    
    func deleteSavedGame(_ game: SavedGame) {
        let context = container.viewContext
        context.delete(game)
        
        do {
            try context.save()
        } catch {
            print("Oyun silinemedi: \(error)")
        }
    }
    
    // Kaydedilmiş tüm oyunları sil
    func deleteAllSavedGames() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SavedGame")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("Tüm kaydedilmiş oyunlar silindi")
        } catch {
            print("Kaydedilmiş oyunlar silinemedi: \(error)")
        }
    }
    
    // MARK: - General
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("CoreData kaydetme hatası: \(error)")
            }
        }
    }
}