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
        
        // Kullanıcı adının benzersiz olduğunu kontrol et
        let usernameCheck = NSFetchRequest<User>(entityName: "User")
        usernameCheck.predicate = NSPredicate(format: "username == %@", username)
        
        // E-posta adresinin benzersiz olduğunu kontrol et
        let emailCheck = NSFetchRequest<User>(entityName: "User")
        emailCheck.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            // Kullanıcı adı kontrolü
            if try context.count(for: usernameCheck) > 0 {
                print("❌ Bu kullanıcı adı zaten kullanılıyor: \(username)")
                return false
            }
            
            // E-posta kontrolü
            if try context.count(for: emailCheck) > 0 {
                print("❌ Bu e-posta zaten kullanılıyor: \(email)")
                return false
            }
            
            // Yeni kullanıcı oluştur
            let user = User(context: context)
            
            // Şifre güvenliği için salt oluştur
            let salt = SecurityManager.shared.generateSalt()
            let hashedPassword = SecurityManager.shared.hashPassword(password, salt: salt)
            
            // Kullanıcı bilgilerini ayarla
            user.id = UUID()
            user.username = username
            user.password = hashedPassword
            user.passwordSalt = salt
            user.email = email
            user.name = name
            user.registrationDate = Date()
            user.isLoggedIn = true
            
            try context.save()
            print("✅ Kullanıcı başarıyla oluşturuldu: \(username)")
            return true
        } catch {
            print("❌ Kullanıcı kaydı başarısız: \(error.localizedDescription)")
            return false
        }
    }
    
    func loginUser(username: String, password: String) -> NSManagedObject? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@", username)
        
        do {
            let users = try context.fetch(request)
            
            if let user = users.first {
                // Şifre doğrulama
                if let storedPassword = user.password,
                   let salt = user.passwordSalt {
                    // Güvenli şifre doğrulama
                    if SecurityManager.shared.verifyPassword(password, against: storedPassword, salt: salt) {
                        // Başarılı giriş
                        user.isLoggedIn = true
                        try context.save()
                        print("✅ Kullanıcı girişi başarılı: \(username)")
                        return user
                    } else {
                        print("❌ Şifre yanlış: \(username)")
                        return nil
                    }
                } else {
                    // Eski kullanıcılar için geriye dönük uyumluluk (salt olmadan doğrudan şifre karşılaştırma)
                    if user.password == password {
                        // Başarılı giriş - eski kullanıcı
                        print("⚠️ Eski format kullanıcı girişi - güvenlik güncellemesi uygulanıyor")
                        
                        // Kullanıcı şifresini güncelle (salt ekle ve hashle)
                        let salt = SecurityManager.shared.generateSalt()
                        let hashedPassword = SecurityManager.shared.hashPassword(password, salt: salt)
                        user.password = hashedPassword
                        user.passwordSalt = salt
                        
                        user.isLoggedIn = true
                        try context.save()
                        return user
                    }
                }
            }
            
            print("❌ Kullanıcı bulunamadı: \(username)")
            return nil
        } catch {
            print("❌ Giriş başarısız: \(error.localizedDescription)")
            return nil
        }
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
            var anonymousUserExists = false
            
            for user in users {
                // Anonim kullanıcıyı kontrol et
                if user.isAnonymous {
                    // Anonim kullanıcı için çıkış yapmıyoruz, sadece var olduğunu not edelim
                    anonymousUserExists = true
                    continue
                }
                
                // Normal kullanıcı için çıkış yap
                user.isLoggedIn = false
            }
            
            // Değişiklikler varsa kaydet
            if context.hasChanges {
                try context.save()
            }
            
            // Eğer mevcut anonim kullanıcı yoksa ve bir kullanıcı çıkış yaptıysa yeni anonim kullanıcı oluştur
            if !anonymousUserExists && users.contains(where: { !$0.isAnonymous }) {
                _ = getOrCreateAnonymousUser()
            }
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
    
    // Tüm kayıtlı oyunları getir
    func getAllSavedGames() -> [SavedGame] {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        // Eğer oturum açmış bir kullanıcı varsa, sadece onun oyunlarını getir
        if let currentUser = getCurrentUser() {
            fetchRequest.predicate = NSPredicate(format: "user == %@", currentUser)
        } else {
            // Kullanıcı yoksa boş liste döndür
            return []
        }
        
        do {
            let savedGames = try context.fetch(fetchRequest)
            return savedGames
        } catch {
            print("❌ Kayıtlı oyunlar getirilemedi: \(error)")
            return []
        }
    }
    
    // Benzersiz ID ile yeni bir oyun kaydet
    func saveGame(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        let context = container.viewContext
        let game = SavedGame(context: context)
        
        // Benzersiz tanımlayıcı ata
        game.setValue(gameID, forKey: "id")
        
        // Eğer tam JSON verisi varsa onu kullan, yoksa basit bir versiyonu kaydet
        if let jsonData = jsonData {
            game.boardState = jsonData
        } else {
            // Tahtayı serialleştir (boardState artık dizi olarak serialleştirilecek)
            let boardDict: [String: Any] = [
                "board": board,
                "difficulty": difficulty
            ]
            
            game.boardState = try? JSONSerialization.data(withJSONObject: boardDict)
        }
        game.difficulty = difficulty
        game.elapsedTime = elapsedTime
        game.dateCreated = Date()
        
        // Eğer oturum açmış bir kullanıcı varsa, oyunu onunla ilişkilendir
        if let currentUser = getCurrentUser() {
            game.setValue(currentUser, forKey: "user")
        }
        
        do {
            try context.save()
            // Başarı mesajı SudokuViewModel'de gösterildiği için burada kaldırıldı
        } catch {
            print("❌ Oyun kaydedilemedi: \(error)")
        }
    }
    
    // Mevcut bir oyunu güncelle
    func updateSavedGame(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        let context = container.viewContext
        
        // ID'ye göre oyunu bul
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", gameID as CVarArg)
        
        // Eğer oturum açmış bir kullanıcı varsa, sadece onun oyunlarını güncelle
        if let currentUser = getCurrentUser() {
            let userPredicate = NSPredicate(format: "user == %@", currentUser)
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                request.predicate!,
                userPredicate
            ])
            request.predicate = compoundPredicate
        }
        
        do {
            let games = try context.fetch(request)
            
            if let existingGame = games.first {
                // Eğer tam JSON verisi varsa onu kullan, yoksa basit bir versiyonu kaydet
                if let jsonData = jsonData {
                    existingGame.boardState = jsonData
                } else {
                    // Veri güncellemesi
                    let boardDict: [String: Any] = [
                        "board": board,
                        "difficulty": difficulty
                    ]
                    
                    existingGame.boardState = try? JSONSerialization.data(withJSONObject: boardDict)
                }
                existingGame.elapsedTime = elapsedTime
                existingGame.dateCreated = Date()  // Son değişiklik zamanı
                
                try context.save()
                // Başarı mesajı SudokuViewModel'de gösterildiği için burada kaldırıldı
            } else {
                print("⚠️ Güncellenecek oyun bulunamadı, ID: \(gameID). Yeni oyun olarak kaydediliyor.")
                // Oyun bulunamadıysa yeni oluştur
                saveGame(gameID: gameID, board: board, difficulty: difficulty, elapsedTime: elapsedTime)
            }
        } catch {
            print("❌ Oyun güncellenemedi: \(error)")
        }
    }
    
    func loadSavedGames() -> [SavedGame] {
        let context = container.viewContext
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        // Eğer oturum açmış bir kullanıcı varsa, sadece onun oyunlarını yükleyin
        if let currentUser = getCurrentUser() {
            request.predicate = NSPredicate(format: "user == %@", currentUser)
        } else {
            // Kullanıcı yoksa boş liste döndür
            return []
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedGame.dateCreated, ascending: false)]
        
        do {
            let savedGames = try context.fetch(request)
            print("📊 Yüklenen oyun sayısı: \(savedGames.count)")
            
            // SavedGame nesnelerinin ID'leri için kontrol
            for (index, game) in savedGames.enumerated() {
                if game.value(forKey: "id") == nil {
                    // ID yoksa yeni bir ID ata (geriye dönük uyumluluk için)
                    let newID = UUID()
                    game.setValue(newID, forKey: "id")
                    print("🔄 Oyun #\(index) için eksik ID oluşturuldu: \(newID)")
                }
            }
            
            // Değişiklikler varsa kaydet
            if context.hasChanges {
                try context.save()
            }
            
            return savedGames
        } catch {
            print("❌ Kayıtlı oyunlar yüklenemedi: \(error)")
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
    
    // ID'ye göre kaydedilmiş oyunu sil
    func deleteSavedGameWithID(_ gameID: UUID) {
        let context = container.viewContext
        
        // ID'ye göre oyunu bul
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", gameID as CVarArg)
        
        do {
            let games = try context.fetch(request)
            
            if let existingGame = games.first {
                // Oyunu sil
                context.delete(existingGame)
                try context.save()
                print("✅ ID'si \(gameID) olan oyun başarıyla silindi")
            } else {
                print("❓ Silinecek oyun bulunamadı, ID: \(gameID)")
            }
        } catch {
            print("❌ Oyun silinemedi: \(error)")
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
    
    // Not: saveGameWithCustomName metodu kaldırıldı, yerine normal saveGame metodu ve updateGameDifficulty kullanılıyor
    
    // MARK: - Game Difficulty Update
    
    /// Belirli bir oyunun zorluk seviyesini günceller
    /// - Parameters:
    ///   - gameID: Güncellenecek oyunun ID'si
    ///   - newDifficulty: Yeni zorluk seviyesi
    func updateGameDifficulty(gameID: UUID, newDifficulty: String) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", gameID as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let game = results.first {
                game.difficulty = newDifficulty
                try context.save()
                print("✅ Oyun zorluk seviyesi güncellendi: \(newDifficulty)")
            }
        } catch {
            print("❌ Oyun zorluk seviyesi güncellenirken hata oluştu: \(error)")
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
    
    // Anonim kullanıcı oluşturma veya alma
    func getOrCreateAnonymousUser() -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "isAnonymous == YES")
        
        do {
            let anonymousUsers = try context.fetch(request)
            
            if let anonymousUser = anonymousUsers.first {
                return anonymousUser
            } else {
                // Anonim kullanıcı oluştur
                let anonymousUser = User(context: context)
                anonymousUser.id = UUID()
                anonymousUser.username = "anonymous_\(UUID().uuidString.prefix(8))"
                anonymousUser.isAnonymous = true
                anonymousUser.isLoggedIn = true
                anonymousUser.registrationDate = Date()
                
                try context.save()
                return anonymousUser
            }
        } catch {
            print("❌ Anonim kullanıcı oluşturulamadı: \(error)")
            return nil
        }
    }
    
    // Yeni bir skor kaydet
    func saveHighScore(difficulty: String, elapsedTime: TimeInterval, errorCount: Int, hintCount: Int, score: Int) -> Bool {
        let context = container.viewContext
        let highScore = HighScore(context: context)
        
        // Skor bilgilerini ayarla
        highScore.id = UUID()
        highScore.difficulty = difficulty
        highScore.elapsedTime = elapsedTime
        highScore.errorCount = Int16(errorCount)
        highScore.hintCount = Int16(hintCount)
        highScore.totalScore = Int32(score)
        highScore.date = Date()
        
        // Eğer oturum açmış bir kullanıcı varsa, skoru onunla ilişkilendir
        if let currentUser = getCurrentUser() {
            highScore.setValue(currentUser, forKey: "user")
            highScore.playerName = currentUser.name
        } else if let anonymousUser = getOrCreateAnonymousUser() {
            // Anonim kullanıcı ile ilişkilendir
            highScore.setValue(anonymousUser, forKey: "user")
            highScore.playerName = "Anonim Oyuncu"
        }
        
        do {
            try context.save()
            return true
        } catch {
            print("❌ Yüksek skor kaydedilemedi: \(error)")
            return false
        }
    }
    
    // Belirli bir zorluk seviyesine ait yüksek skorları getir
    func getHighScores(for difficulty: String) -> [HighScore] {
        let context = container.viewContext
        let request: NSFetchRequest<HighScore> = HighScore.fetchRequest()
        
        // Zorluk seviyesine göre filtrele
        request.predicate = NSPredicate(format: "difficulty == %@", difficulty)
        
        // Eğer oturum açmış bir kullanıcı varsa, sadece onun skorlarını getir
        if let currentUser = getCurrentUser() {
            let userPredicate = NSPredicate(format: "user == %@", currentUser)
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                request.predicate!,
                userPredicate
            ])
            request.predicate = compoundPredicate
        } else if let anonymousUser = getOrCreateAnonymousUser() {
            // Anonim kullanıcının skorlarını getir
            let userPredicate = NSPredicate(format: "user == %@", anonymousUser)
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                request.predicate!,
                userPredicate
            ])
            request.predicate = compoundPredicate
        } else {
            return []
        }
        
        // Skorları puan değerine göre sırala (yüksekten düşüğe)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HighScore.totalScore, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Yüksek skorlar getirilemedi: \(error)")
            return []
        }
    }
}