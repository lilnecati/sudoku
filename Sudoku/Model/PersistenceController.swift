import CoreData
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
// Şimdilik Firestore'u kaldırdık
// import FirebaseFirestore

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    // Lazy loading ile Firestore başlatmayı geciktir
    lazy var db: Firestore = {
        // Firebase'in başlatıldığından emin ol
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase Auth configured from PersistenceController (lazy)")
        }
        return Firestore.firestore()
    }()
    
    init() {
        container = NSPersistentContainer(name: "SudokuModel")
        
        // ÖNCELİKLE history tracking ayarlanmalı
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
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
        
        debugPrint("🔄 LogoutCurrentUser başladı")
        
        // Firebase Authentication'dan çıkış yap
        if let firebaseUser = Auth.auth().currentUser {
            // Firestore'da kullanıcının çıkış yaptığını kaydet
            db.collection("users").document(firebaseUser.uid).updateData([
                "isLoggedIn": false,
                "lastLogoutDate": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("⚠️ Firestore çıkış bilgisi güncellenemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Firestore çıkış bilgisi güncellendi")
                }
            }
            
            // Firebase Authentication'dan çıkış yap
            do {
                try Auth.auth().signOut()
                print("✅ Firebase Auth'dan çıkış yapıldı")
            } catch {
                print("❌ Firebase Auth çıkış hatası: \(error.localizedDescription)")
            }
        }
        
        do {
            let users = try context.fetch(request)
            debugPrint("👥 Giriş yapmış kullanıcı sayısı: \(users.count)")
            
            for user in users {
                // Anonim kullanıcı sistemini kaldırdığımız için tüm kullanıcıları çıkış yaptırıyoruz
                debugPrint("👤 Çıkış yapan kullanıcı: \(user.username ?? "bilinmiyor")")
                user.isLoggedIn = false
            }
            
            // Değişiklikler varsa kaydet
            if context.hasChanges {
                try context.save()
                debugPrint("✅ Kullanıcı çıkış bilgileri kaydedildi")
            } else {
                debugPrint("ℹ️ Kaydedilecek değişiklik yok")
            }
            
            // Artık anonim kullanıcı oluşturmuyoruz
            
            // Son kontrol
            if let currentUser = getCurrentUser() {
                debugPrint("ℹ️ İşlem sonrası giriş yapmış kullanıcı: \(currentUser.username ?? "bilinmiyor")")
            } else {
                debugPrint("✅ Tüm kullanıcılar başarıyla çıkış yaptı")
            }
            
        } catch {
            debugPrint("❌ Çıkış hatası: \(error)")
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
        
        // Kullanıcı kontrolünü kaldırdık - tüm kayıtlı oyunları getir
        
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
        
        // Kullanıcı ilişkilendirme kısmını kaldırdık, tüm oyunlar görülebilsin
        
        do {
            try context.save()
            // Başarı mesajı SudokuViewModel'de gösterildiği için burada kaldırıldı
            
            // Firestore'a da kaydet
            saveGameToFirestore(gameID: gameID, board: board, difficulty: difficulty, elapsedTime: elapsedTime, jsonData: jsonData)
            
        } catch {
            print("❌ Oyun kaydedilemedi: \(error)")
        }
    }
    
    // Firestore'a oyun kaydetme
    func saveGameToFirestore(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        // Kullanıcı kimliğini al - giriş yapmış kullanıcı veya misafir
        let userID = Auth.auth().currentUser?.uid ?? "guest"
        
        // Board dizisini düzleştir
        let flatBoard = board.flatMap { $0 }
        
        // Oyunun tamamlanıp tamamlanmadığını kontrol et
        let isCompleted = !flatBoard.contains(0) // Eğer tahtada 0 yoksa oyun tamamlanmıştır
        
        // Firestore'da kayıt için döküman oluştur - UUID'yi uppercase olarak kullan
        let documentID = gameID.uuidString.uppercased()
        let gameRef = db.collection("savedGames").document(documentID)
        
        let gameData: [String: Any] = [
            "userID": userID,
            "difficulty": difficulty,
            "elapsedTime": elapsedTime,
            "dateCreated": FieldValue.serverTimestamp(),
            "board": flatBoard,
            "size": board.count, // Tahta boyutunu da kaydedelim (9x9 için 9)
            "isCompleted": isCompleted  // Oyunun tamamlanma durumunu kaydet
        ]
        
        // Firestore'a kaydet
        gameRef.setData(gameData) { error in
            if let error = error {
                print("❌ Firestore oyun kaydı hatası: \(error.localizedDescription)")
            } else {
                print("✅ Oyun Firebase Firestore'a kaydedildi: \(documentID)")
                if isCompleted {
                    print("✅ Oyun tamamlandı olarak işaretlendi!")
                }
            }
        }
    }
    
    // Mevcut bir oyunu güncelle
    func updateSavedGame(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        let context = container.viewContext
        
        // ID'ye göre oyunu bul
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", gameID as CVarArg)
        
        // Kullanıcı kontrolünü kaldırdık - tüm oyunlar erişilebilir
        
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
                
                // Firestore'da da güncelle
                saveGameToFirestore(gameID: gameID, board: board, difficulty: difficulty, elapsedTime: elapsedTime, jsonData: jsonData)
                
            } else {
                print("⚠️ Güncellenecek oyun bulunamadı, ID: \(gameID). Yeni oyun olarak kaydediliyor.")
                // Oyun bulunamadıysa yeni oluştur
                saveGame(gameID: gameID, board: board, difficulty: difficulty, elapsedTime: elapsedTime)
            }
        } catch {
            print("❌ Oyun güncellenemedi: \(error)")
        }
    }
    
    // Kayıtlı oyunları senkronize et
    func syncSavedGamesFromFirestore(completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Oyunlar senkronize edilemedi: Kullanıcı giriş yapmamış")
            completion(false)
            return
        }
        
        print("🔄 Kayıtlı oyunlar Firestore'dan senkronize ediliyor...")
        
        let context = container.viewContext
        
        // Önce mevcut verileri kontrol edelim 
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        do {
            let existingGames = try context.fetch(fetchRequest)
            print("📊 Senkronizasyon öncesi yerel veritabanında \(existingGames.count) oyun var")
            
            // Mevcut oyunların ID'lerini bir dictionary'de saklayarak silinen oyunları takip edelim
            var existingGameIDs: [String: Bool] = [:]
            
            // Silinen oyunları izlemek için son 24 saat içinde silinen ID'leri kontrol et
            let deletedGamesKey = "recentlyDeletedGameIDs"
            var recentlyDeletedIDs: [String] = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
            
            // 24 saatten eski silinen ID'leri temizle (Unix timestamp olarak saklıyoruz)
            let currentTimestamp = Date().timeIntervalSince1970
            let oneDayInSeconds: TimeInterval = 86400 // 24 saat
            
            // Silinen ID'lerin zaman damgalarını al
            let deletedTimestampsKey = "deletedGameTimestamps"
            var deletedTimestamps = UserDefaults.standard.dictionary(forKey: deletedTimestampsKey) as? [String: Double] ?? [:]
            
            // Eski kayıtları temizle (24 saatten eski)
            for (id, timestamp) in deletedTimestamps {
                if currentTimestamp - timestamp > oneDayInSeconds {
                    deletedTimestamps.removeValue(forKey: id)
                    if let index = recentlyDeletedIDs.firstIndex(of: id) {
                        recentlyDeletedIDs.remove(at: index)
                    }
                }
            }
            
            // Değişiklikleri kaydet
            UserDefaults.standard.set(recentlyDeletedIDs, forKey: deletedGamesKey)
            UserDefaults.standard.set(deletedTimestamps, forKey: deletedTimestampsKey)
            
            print("Yeni format tespit edildi")
            
            // Tüm mevcut oyunların ID'lerini loglayalım ve dictionary'e ekleyelim
            for (index, game) in existingGames.enumerated() {
                if let id = game.value(forKey: "id") as? UUID {
                    let idString = id.uuidString
                    existingGameIDs[idString] = true
                    print("   🎮 Yerel oyun \(index+1): ID = \(idString), difficulty = \(game.difficulty ?? "nil")")
                } else {
                    print("   ⚠️ Yerel oyun \(index+1): ID eksik")
                }
            }
        
            // Kullanıcının kayıtlı oyunlarını getir
            db.collection("savedGames")
                .whereField("userID", isEqualTo: userID)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("ℹ️ Firestore'da kayıtlı oyun bulunamadı")
                        completion(true)
                        return
                    }
                    
                    print("📊 Firestore'dan \(documents.count) oyun getirildi")
                    
                    // Firestore'dan gelen oyunları detaylı loglayalım
                    for (index, document) in documents.enumerated() {
                        let data = document.data()
                        print("   🔥 Firebase oyun \(index+1): ID = \(document.documentID), difficulty = \(data["difficulty"] as? String ?? "nil")")
                    }
                    
                    let context = self.container.viewContext
                    
                    // Her oyunu CoreData'ya kaydet veya güncelle
                    for document in documents {
                        let data = document.data()
                        let gameIDString = document.documentID
                        
                        // Eğer bu ID son 24 saatte silindi olarak işaretlendiyse, senkronize etme
                        if recentlyDeletedIDs.contains(gameIDString) {
                            print("⏭️ ID: \(gameIDString) olan oyun son 24 saat içinde silinmiş, senkronize edilmiyor.")
                            continue
                        }
                        
                        // Eğer bu ID yerel veritabanında yoksa, muhtemelen silinmiştir
                        // Bu durumda senkronize etmiyoruz
                        if existingGameIDs[gameIDString] == nil {
                            print("⏭️ ID: \(gameIDString) olan oyun yerel veritabanında bulunmadı, muhtemelen silinmiş. Senkronize edilmiyor.")
                            continue
                        }
                        
                        guard let gameID = UUID(uuidString: gameIDString),
                              let difficulty = data["difficulty"] as? String,
                              let elapsedTime = data["elapsedTime"] as? TimeInterval,
                              let flatBoard = data["board"] as? [Int],
                              let size = data["size"] as? Int else {
                            continue
                        }
                        
                        // 1D diziyi 2D diziye dönüştür
                        var board: [[Int]] = []
                        for i in stride(from: 0, to: flatBoard.count, by: size) {
                            let row = Array(flatBoard[i..<min(i + size, flatBoard.count)])
                            board.append(row)
                        }
                        
                        // CoreData'da oyunu ara veya yeni oluştur
                        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", gameID as CVarArg)
                        
                        do {
                            let existingGames = try context.fetch(fetchRequest)
                            
                            if let existingGame = existingGames.first {
                                // Oyunu güncelle
                                let boardDict: [String: Any] = [
                                    "board": board,
                                    "difficulty": difficulty
                                ]
                                existingGame.boardState = try? JSONSerialization.data(withJSONObject: boardDict)
                                existingGame.elapsedTime = elapsedTime
                                existingGame.dateCreated = Date()
                                print("✅ Oyun güncellendi: \(gameID)")
                            } else {
                                // Bu duruma ulaşılmamalı, çünkü existingGameIDs kontrolü yapıldı
                                print("⚠️ Beklenmeyen durum: ID: \(gameID) olan oyun dictionary'de var ama fetchRequest bulamadı.")
                            }
                        } catch {
                            print("❌ CoreData oyun güncelleme hatası: \(error.localizedDescription)")
                        }
                    }
                    
                    // Değişiklikleri kaydet
                    do {
                        try context.save()
                        
                        // Sadece değişiklik olduğunda bildirim gönder
                        // Bu değişen bir şey varsa anlamına gelir
                        if documents.count > 0 {
                            print("✅ Oyunlar başarıyla senkronize edildi")
                            // Core Data'nın yenilenmesi için bildirim gönder
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                            }
                        }
                        
                        print("✅ Firebase senkronizasyonu tamamlandı")
                        completion(true)
                    } catch {
                        print("❌ Core Data kaydetme hatası: \(error)")
                        completion(false)
                    }
                }
        } catch {
            print("⚠️ Yerel veritabanı sorgulanamadı: \(error)")
            completion(false)
        }
    }
    
    // Kayıtlı oyunları yükle - güncellendi
    func loadSavedGames() -> [SavedGame] {
        // Firebase senkronizasyonunu kaldırdık - gereksiz döngüleri önlemek için
        
        let context = container.viewContext
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedGame.dateCreated, ascending: false)]
        
        do {
            let savedGames = try context.fetch(request)
            print("📊 Yüklenen oyun sayısı: \(savedGames.count)")
            
            // SavedGame nesnelerinin ID'leri için kontrol
            var idFixed = false
            for (index, game) in savedGames.enumerated() {
                if game.value(forKey: "id") == nil {
                    let newID = UUID()
                    game.setValue(newID, forKey: "id")
                    print("🔄 Oyun #\(index) için eksik ID oluşturuldu: \(newID)")
                    idFixed = true
                }
            }
            
            // Değişiklikler varsa kaydet
            if context.hasChanges && idFixed {
                try context.save()
                print("✅ Eksik ID'ler düzeltildi ve kaydedildi")
            }
            
            return savedGames
        } catch {
            print("❌ Kayıtlı oyunlar yüklenemedi: \(error)")
        }
        return []
    }
    
    func deleteSavedGame(_ game: SavedGame) {
        let context = container.viewContext
        
        // Debug: Oyun nesnesinin detaylarını göster
        print("🔍 Silinecek oyun detayları:")
        if let gameID = game.value(forKey: "id") as? UUID {
            let gameIDString = gameID.uuidString
            print("📍 Oyun UUID: \(gameID)")
            print("📍 Oyun UUID String: \(gameIDString)")
            
            // Silinen oyunu "son silinen oyunlar" listesine ekle
            let deletedGamesKey = "recentlyDeletedGameIDs"
            var recentlyDeletedIDs = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
            
            // Eğer zaten listede yoksa ekle
            if !recentlyDeletedIDs.contains(gameIDString) {
                recentlyDeletedIDs.append(gameIDString)
                UserDefaults.standard.set(recentlyDeletedIDs, forKey: deletedGamesKey)
                
                // Silme zamanını kaydet
                let deletedTimestampsKey = "deletedGameTimestamps"
                var deletedTimestamps = UserDefaults.standard.dictionary(forKey: deletedTimestampsKey) as? [String: Double] ?? [:]
                deletedTimestamps[gameIDString] = Date().timeIntervalSince1970
                UserDefaults.standard.set(deletedTimestamps, forKey: deletedTimestampsKey)
                
                print("📝 Oyun ID \(gameIDString) silinen oyunlar listesine eklendi")
            }
            
            // Kullanıcı kontrolü
            guard let currentUser = Auth.auth().currentUser else {
                print("❌ Firebase'de oturum açık değil!")
                return
            }
            print("👤 Mevcut kullanıcı: \(currentUser.uid)")
            
            // Firestore'dan sil
            let documentID = gameID.uuidString.uppercased()
            print("🔥 Firebase'den silinecek döküman ID: \(documentID)")
            
            // Önce dökümanı kontrol et
            db.collection("savedGames").document(documentID).getDocument { [weak self] (document, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Döküman kontrol hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("⚠️ Döküman zaten Firebase'de mevcut değil")
                    return
                }
                
                // Döküman verilerini kontrol et
                if let data = document.data(),
                   let documentUserID = data["userID"] as? String {
                    print("📄 Döküman sahibi: \(documentUserID)")
                    print("👤 Mevcut kullanıcı: \(currentUser.uid)")
                    
                    // Kullanıcı yetkisi kontrolü
                    if documentUserID != currentUser.uid {
                        print("❌ Bu dökümanı silme yetkiniz yok!")
                        return
                    }
                }
                
                // Silme işlemini gerçekleştir
                self.db.collection("savedGames").document(documentID).delete { error in
                    if let error = error {
                        print("❌ Firestore'dan oyun silme hatası: \(error.localizedDescription)")
                    } else {
                        print("✅ Oyun Firestore'dan silindi: \(documentID)")
                        
                        // Silme işlemini doğrula
                        self.db.collection("savedGames").document(documentID).getDocument { (document, _) in
                            if let document = document, document.exists {
                                print("⚠️ Dikkat: Döküman hala Firebase'de mevcut!")
                            } else {
                                print("✅ Doğrulandı: Döküman Firebase'den başarıyla silindi")
                            }
                        }
                    }
                }
            }
        } else {
            print("❌ Oyun ID'si alınamadı!")
        }
        
        // Yerel veritabanından sil
        context.delete(game)
        
        do {
            try context.save()
            print("✅ Oyun yerel veritabanından silindi")
            
            // Oyun silindikten hemen sonra UI güncellemesi için bildirim gönder
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
            }
        } catch {
            print("❌ Oyun silinemedi: \(error)")
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
                
                // Firestore'dan da sil
                deleteGameFromFirestore(gameID: gameID)
            } else {
                print("❓ Silinecek oyun bulunamadı, ID: \(gameID)")
            }
        } catch {
            print("❌ Oyun silinemedi: \(error)")
        }
    }
    
    // Firestore'dan oyun silme
    func deleteGameFromFirestore(gameID: UUID) {
        // UUID'yi uppercase olarak kullan
        let documentID = gameID.uuidString.uppercased()
        
        db.collection("savedGames").document(documentID).delete { error in
            if let error = error {
                print("❌ Firestore'dan oyun silme hatası: \(error.localizedDescription)")
            } else {
                print("✅ Oyun Firestore'dan silindi: \(gameID)")
            }
        }
    }
    
    // Tüm kayıtlı oyunları sil
    func deleteAllSavedGames() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        do {
            // Önce tüm oyunları getir
            let allGames = try context.fetch(fetchRequest)
            
            // Her bir oyunu tek tek sil
            for game in allGames {
                context.delete(game)
            }
            
            // Değişiklikleri kaydet
            try context.save()
            print("✅ Tüm kaydedilmiş oyunlar yerel veritabanından silindi")
            
            // Firestore'dan kullanıcıya ait tüm oyunları sil
            deleteAllUserGamesFromFirestore()
            
        } catch {
            print("❌ Kaydedilmiş oyunlar silinemedi: \(error)")
        }
    }
    
    // Firestore'dan kullanıcıya ait tüm oyunları sil
    func deleteAllUserGamesFromFirestore() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
            return
        }
        
        print("🔄 Tüm oyunlar Firestore'dan siliniyor... Kullanıcı ID: \(userID)")
        
        // Kullanıcıya ait oyunları sorgula
        db.collection("savedGames")
            .whereField("userID", isEqualTo: userID)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da silinecek oyun bulunamadı")
                    return
                }
                
                print("📊 Silinecek oyun sayısı: \(documents.count)")
                
                // Her oyunu tek tek sil
                let batch = self.db.batch()
                documents.forEach { document in
                    print("🗑️ Siliniyor: \(document.documentID)")
                    let gameRef = self.db.collection("savedGames").document(document.documentID)
                    batch.deleteDocument(gameRef)
                }
                
                // Batch işlemini uygula
                batch.commit { error in
                    if let error = error {
                        print("❌ Firestore toplu oyun silme hatası: \(error.localizedDescription)")
                    } else {
                        print("✅ \(documents.count) oyun Firestore'dan silindi")
                    }
                }
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
        
        debugPrint("🔄 getOrCreateAnonymousUser çağrıldı")
        
        do {
            let anonymousUsers = try context.fetch(request)
            
            debugPrint("👥 Mevcut anonim kullanıcı sayısı: \(anonymousUsers.count)")
            
            if let anonymousUser = anonymousUsers.first {
                debugPrint("✅ Mevcut anonim kullanıcı bulundu: \(anonymousUser.username ?? "bilinmiyor")")
                // Giriş durumunu garantiye al
                if !anonymousUser.isLoggedIn {
                    anonymousUser.isLoggedIn = true
                    try context.save()
                    debugPrint("ℹ️ Anonim kullanıcının giriş durumu güncellendi")
                }
                return anonymousUser
            } else {
                // Anonim kullanıcı oluştur
                debugPrint("ℹ️ Yeni anonim kullanıcı oluşturuluyor...")
                let anonymousUser = User(context: context)
                anonymousUser.id = UUID()
                let anonymousID = UUID().uuidString.prefix(8)
                anonymousUser.username = "anonymous_\(anonymousID)"
                anonymousUser.isAnonymous = true
                anonymousUser.isLoggedIn = true
                anonymousUser.registrationDate = Date()
                
                try context.save()
                debugPrint("✅ Yeni anonim kullanıcı oluşturuldu: \(anonymousUser.username ?? "bilinmiyor")")
                return anonymousUser
            }
        } catch {
            debugPrint("❌ Anonim kullanıcı oluşturulamadı: \(error)")
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
            highScore.playerName = currentUser.name ?? "Oyuncu"
        } else {
            // Kullanıcı giriş yapmamışsa, geçici oyuncu adı ver
            highScore.playerName = "Misafir Oyuncu"
        }
        
        do {
            try context.save()
            
            // Firestore'a da kaydet
            saveHighScoreToFirestore(
                scoreID: highScore.id?.uuidString ?? UUID().uuidString,
                difficulty: difficulty,
                elapsedTime: elapsedTime,
                errorCount: errorCount, 
                hintCount: hintCount,
                score: score,
                playerName: highScore.playerName ?? "Misafir Oyuncu"
            )
            
            return true
        } catch {
            print("❌ Yüksek skor kaydedilemedi: \(error)")
            return false
        }
    }
    
    // Yüksek skor bilgilerini Firestore'a kaydet
    func saveHighScoreToFirestore(scoreID: String, difficulty: String, elapsedTime: TimeInterval, errorCount: Int, hintCount: Int, score: Int, playerName: String) {
        // Kullanıcı kimliğini al
        let userID = Auth.auth().currentUser?.uid ?? "guest"
        
        // Skor verileri
        let scoreData: [String: Any] = [
            "scoreID": scoreID,
            "userID": userID,
            "playerName": playerName,
            "difficulty": difficulty,
            "elapsedTime": elapsedTime,
            "errorCount": errorCount,
            "hintCount": hintCount,
            "totalScore": score,
            "date": FieldValue.serverTimestamp()
        ]
        
        // Firestore'a kaydet
        db.collection("highScores").document(scoreID).setData(scoreData) { error in
            if let error = error {
                print("❌ Firestore yüksek skor kaydı hatası: \(error.localizedDescription)")
            } else {
                print("✅ Yüksek skor Firebase Firestore'a kaydedildi")
            }
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
        } else {
            // Kullanıcı giriş yapmamışsa - sadece zorluk seviyesine göre skorları getir 
            // ama kullanıcıya göre filtreleme.
            // request.predicate ifadesi zaten difficulty'yi filtreliyor, bu yeterli
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
    
    // MARK: - Firebase User Management
    
    func registerUserWithFirebase(username: String, password: String, email: String, name: String, completion: @escaping (Bool, Error?) -> Void) {
        // Önce Firebase Auth'a kaydet
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase kayıt hatası: \(error.localizedDescription)")
                let nsError = error as NSError
                print("❌ Firebase hata detayları: \(nsError.userInfo)")
                completion(false, error)
                return
            }
            
            guard let user = authResult?.user else {
                print("❌ Firebase kullanıcı oluşturma hatası")
                completion(false, nil)
                return
            }
            
            // Kullanıcı profil bilgilerini güncelle
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            
            changeRequest.commitChanges { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firebase profil güncelleme hatası: \(error.localizedDescription)")
                    // Profil güncellemesi başarısız olsa da devam et
                }
                
                // YENI: Kullanıcı verilerini Firestore'a kaydet
                self.db.collection("users").document(user.uid).setData([
                    "username": username,
                    "email": email,
                    "name": name,
                    "registrationDate": FieldValue.serverTimestamp(),
                    "isLoggedIn": true
                ]) { error in
                    if let error = error {
                        print("❌ Firestore kullanıcı veri kaydı hatası: \(error.localizedDescription)")
                    } else {
                        print("✅ Kullanıcı verileri Firestore'a kaydedildi: \(username)")
                    }
                    
                    // Şimdilik Firestore kullanmıyoruz - sadece yerel veritabanına kaydet
                    DispatchQueue.main.async {
                        let saveLocally = self.registerUser(username: username, password: password, email: email, name: name)
                        
                        if saveLocally {
                            // Kullanıcı bilgilerini doğrudan Firebase Authentication UID ile ilişkilendir
                            if let localUser = self.fetchUser(username: username) as? User {
                                let context = self.container.viewContext
                                localUser.firebaseUID = user.uid
                                
                                do {
                                    try context.save()
                                    print("✅ Kullanıcı Firebase UID ile güncellendi: \(username)")
                                } catch {
                                    print("❌ Firebase UID güncellenirken hata: \(error.localizedDescription)")
                                }
                            }
                            
                            print("✅ Kullanıcı Firebase ve yerel veritabanına kaydedildi: \(username)")
                            completion(true, nil)
                        } else {
                            print("⚠️ Kullanıcı Firebase'e kaydedildi ancak yerel kayıt başarısız")
                            // Firebase'e kaydedildi ancak yerel kayıt başarısız oldu - yine de başarılı sayabiliriz
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }
    
    func loginUserWithFirebase(email: String, password: String, completion: @escaping (User?, Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase giriş hatası: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                print("❌ Firebase kullanıcı verisi alınamadı")
                completion(nil, nil)
                return
            }
            
            // Firestore'daki kullanıcı bilgilerini güncelle
            self.db.collection("users").document(firebaseUser.uid).updateData([
                "lastLoginDate": FieldValue.serverTimestamp(),
                "isLoggedIn": true
            ]) { error in
                if let error = error {
                    print("⚠️ Firestore giriş bilgisi güncellenemedi: \(error.localizedDescription)")
                    // Hata olsa da devam et
                } else {
                    print("✅ Firestore giriş bilgisi güncellendi")
                }
            }
            
            // Firebase UID'ye göre yerel kullanıcıyı bulma
            let context = self.container.viewContext
            let request: NSFetchRequest<User> = User.fetchRequest()
            request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUser.uid)
            
            do {
                let users = try context.fetch(request)
                if let existingUser = users.first {
                    // Kullanıcı yerel veritabanında var, giriş durumunu güncelle
                    existingUser.isLoggedIn = true
                    try context.save()
                    print("✅ Firebase kullanıcısı yerel veritabanında güncellendi")
                    completion(existingUser, nil)
                    return
                }
            } catch {
                print("❌ Firebase UID ile kullanıcı aranırken hata: \(error.localizedDescription)")
            }
            
            // Email'e göre kullanıcıyı ara
            request.predicate = NSPredicate(format: "email == %@", email)
            
            do {
                let users = try context.fetch(request)
                if let existingUser = users.first {
                    // Kullanıcı var, firebase UID'sini güncelle
                    existingUser.isLoggedIn = true
                    existingUser.firebaseUID = firebaseUser.uid
                    try context.save()
                    print("✅ Kullanıcı firebase UID ile güncellendi")
                    completion(existingUser, nil)
                } else {
                    // Kullanıcı yerel veritabanında yok, oluştur
                    let newUser = User(context: context)
                    
                    // Kullanıcı bilgilerini ayarla
                    newUser.id = UUID()
                    newUser.username = email.components(separatedBy: "@").first ?? "user_\(UUID().uuidString.prefix(8))"
                    newUser.email = email
                    newUser.name = firebaseUser.displayName
                    newUser.registrationDate = Date()
                    newUser.isLoggedIn = true
                    newUser.firebaseUID = firebaseUser.uid
                    
                    try context.save()
                    print("✅ Firebase kullanıcısı yerel veritabanına kaydedildi")
                    completion(newUser, nil)
                }
            } catch {
                print("❌ Firebase kullanıcısı yerel veritabanına kaydedilemedi: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
    
    func getEmailFromUsername(_ usernameOrEmail: String) -> String {
        // Eğer giriş için e-posta veya kullanıcı adı kullanılabiliyorsa
        // Kullanıcı adından e-postayı bul
        
        // E-posta formatını kontrol et
        if usernameOrEmail.contains("@") {
            return usernameOrEmail // Zaten e-posta
        }
        
        // Kullanıcı adından e-postayı bul
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@", usernameOrEmail)
        
        do {
            let users = try context.fetch(request)
            if let user = users.first, let email = user.email {
                return email
            }
        } catch {
            print("❌ Kullanıcı e-postası aranırken hata: \(error.localizedDescription)")
        }
        
        // E-posta bulunamadıysa, doğrudan kullanıcı adını döndür
        // (Firebase giriş başarısız olacak, ancak yerel giriş denemesi yapılabilir)
        return usernameOrEmail
    }
    
    // MARK: - Firebase Game Sync
    
    // Oyunu Firebase'e kaydet - şimdilik devre dışı
    func saveGameToFirebase(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        // Firebase Firestore kapalı - sadece log çıktısı
        print("⚠️ Firebase Firestore devre dışı: Oyun sadece yerel veritabanına kaydedildi")
    }
    
    // Firebase'den oyunları senkronize et - şimdilik devre dışı
    func syncGamesFromFirebase(for firebaseUID: String) {
        // Firebase Firestore kapalı - sadece log çıktısı
        print("⚠️ Firebase Firestore devre dışı: Oyun senkronizasyonu yapılamadı")
    }
    
    // UUID ile kayıtlı oyunu getir
    func getSavedGameByID(_ id: UUID) -> SavedGame? {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let games = try context.fetch(fetchRequest)
            return games.first
        } catch {
            print("❌ ID ile oyun getirme hatası: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Firebase Firestore Veri Okuma
    
    // Firestore'dan kaydedilmiş oyunları getir
    func fetchSavedGamesFromFirestore(completion: @escaping ([String: Any]?, Error?) -> Void) {
        // Kullanıcı giriş yapmış mı kontrol et
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Firestore oyunları getirilemedi: Kullanıcı giriş yapmamış")
            completion(nil, nil)
            return
        }
        
        // Kullanıcının oyunlarını sorgula
        db.collection("savedGames")
            .whereField("userID", isEqualTo: userID)
            .order(by: "dateCreated", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da kayıtlı oyun bulunamadı")
                    completion(nil, nil)
                    return
                }
                
                // Sonuçları dönüştür
                var result: [String: Any] = [:]
                var games: [[String: Any]] = []
                
                for document in documents {
                    var gameData = document.data()
                    gameData["id"] = document.documentID
                    games.append(gameData)
                }
                
                result["games"] = games
                result["count"] = games.count
                
                print("✅ Firestore'dan \(games.count) oyun yüklendi")
                completion(result, nil)
            }
    }
    
    // Firestore'dan yüksek skorları getir
    func fetchHighScoresFromFirestore(difficulty: String, limit: Int = 100, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        db.collection("highScores")
            .whereField("difficulty", isEqualTo: difficulty)
            .order(by: "totalScore", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firestore yüksek skor sorgulama hatası: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da \(difficulty) zorluğunda yüksek skor bulunamadı")
                    completion([], nil)
                    return
                }
                
                // Sonuçları dönüştür
                var scores: [[String: Any]] = []
                
                for document in documents {
                    var scoreData = document.data()
                    scoreData["id"] = document.documentID
                    scores.append(scoreData)
                }
                
                print("✅ Firestore'dan \(scores.count) yüksek skor yüklendi")
                completion(scores, nil)
            }
    }
    
    // Belirli bir kullanıcının yüksek skorlarını getir
    func fetchUserHighScoresFromFirestore(userID: String? = nil, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        // Kullanıcı ID'si belirtilmemişse, giriş yapmış kullanıcıyı kullan
        let uid = userID ?? Auth.auth().currentUser?.uid
        
        guard let uid = uid else {
            print("⚠️ Firestore kullanıcı skorları getirilemedi: Kullanıcı ID'si yok")
            completion(nil, nil)
            return
        }
        
        db.collection("highScores")
            .whereField("userID", isEqualTo: uid)
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firestore kullanıcı skorları sorgulama hatası: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da kullanıcı için skor bulunamadı")
                    completion([], nil)
                    return
                }
                
                // Sonuçları dönüştür
                var scores: [[String: Any]] = []
                
                for document in documents {
                    var scoreData = document.data()
                    scoreData["id"] = document.documentID
                    scores.append(scoreData)
                }
                
                print("✅ Firestore'dan \(scores.count) kullanıcı skoru yüklendi")
                completion(scores, nil)
            }
    }
    
    // Firestore'dan oyun yükleme
    func loadSavedGame(gameID: UUID, completion: @escaping (Result<(board: [[Int]], difficulty: String, elapsedTime: TimeInterval), Error>) -> Void) {
        let gameRef = db.collection("savedGames").document(gameID.uuidString)
        
        gameRef.getDocument { (document, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data(),
                  let difficulty = data["difficulty"] as? String,
                  let elapsedTime = data["elapsedTime"] as? TimeInterval,
                  let flatBoard = data["board"] as? [Int],
                  let size = data["size"] as? Int else {
                completion(.failure(NSError(domain: "LoadGameError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Oyun verisi eksik veya hatalı"])))
                return
            }
            
            // Düz diziyi matrise dönüştür
            var board: [[Int]] = []
            for i in stride(from: 0, to: flatBoard.count, by: size) {
                let row = Array(flatBoard[i..<min(i + size, flatBoard.count)])
                board.append(row)
            }
            
            completion(.success((board: board, difficulty: difficulty, elapsedTime: elapsedTime)))
        }
    }
    
    // MARK: - High Score Sync with Firebase
    
    // Firestore'dan yüksek skorları getir ve CoreData ile senkronize et
    func syncHighScoresFromFirestore(completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Yüksek skorlar getirilemedi: Kullanıcı giriş yapmamış")
            completion(false)
            return
        }
        
        print("🔄 Yüksek skorlar Firestore'dan senkronize ediliyor...")
        
        // Kullanıcının yüksek skorlarını getir
        db.collection("highScores")
            .whereField("userID", isEqualTo: userID)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firestore skor sorgulama hatası: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("ℹ️ Firestore'da yüksek skor bulunamadı")
                    completion(true)
                    return
                }
                
                print("📊 Bulunan yüksek skor sayısı: \(documents.count)")
                
                let context = self.container.viewContext
                
                // Her bir skoru CoreData'ya kaydet veya güncelle
                for document in documents {
                    let data = document.data()
                    
                    // Skor ID'sini kontrol et
                    guard let scoreIDString = data["scoreID"] as? String,
                          let scoreID = UUID(uuidString: scoreIDString) else {
                        continue
                    }
                    
                    // Mevcut skoru ara veya yeni oluştur
                    let fetchRequest: NSFetchRequest<HighScore> = HighScore.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", scoreID as CVarArg)
                    
                    do {
                        let existingScores = try context.fetch(fetchRequest)
                        let highScore: HighScore
                        
                        if let existingScore = existingScores.first {
                            highScore = existingScore
                        } else {
                            highScore = HighScore(context: context)
                            highScore.id = scoreID
                        }
                        
                        // Skor verilerini güncelle
                        highScore.difficulty = data["difficulty"] as? String
                        highScore.elapsedTime = data["elapsedTime"] as? Double ?? 0
                        highScore.errorCount = Int16(data["errorCount"] as? Int ?? 0)
                        highScore.hintCount = Int16(data["hintCount"] as? Int ?? 0)
                        highScore.totalScore = Int32(data["totalScore"] as? Int ?? 0)
                        highScore.playerName = data["playerName"] as? String
                        if let timestamp = data["date"] as? Timestamp {
                            highScore.date = timestamp.dateValue()
                        }
                        
                        print("✅ Yüksek skor senkronize edildi: \(scoreID)")
                    } catch {
                        print("❌ CoreData skor güncelleme hatası: \(error.localizedDescription)")
                    }
                }
                
                // Değişiklikleri kaydet
                do {
                    try context.save()
                    
                    // Sadece değişiklik olduğunda bildirim gönder
                    // Bu değişen bir şey varsa anlamına gelir
                    if documents.count > 0 {
                        print("✅ Oyunlar başarıyla senkronize edildi")
                        // Core Data'nın yenilenmesi için bildirim gönder
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                        }
                    }
                    
                    print("✅ Firebase senkronizasyonu tamamlandı")
                    completion(true)
                } catch {
                    print("❌ CoreData kaydetme hatası: \(error)")
                    completion(false)
                }
            }
    }
    
    // Uygulama başladığında ve gerektiğinde yüksek skorları senkronize et
    func refreshHighScores() {
        syncHighScoresFromFirestore { success in
            if success {
                print("✅ Yüksek skorlar başarıyla güncellendi")
            } else {
                print("⚠️ Yüksek skorlar güncellenirken bir sorun oluştu")
            }
        }
    }
    
    // Firestore'dan tamamlanmış oyunları getir
    func fetchCompletedGamesFromFirestore(limit: Int = 8, completion: @escaping ([String: Any]?, Error?) -> Void) {
        // Kullanıcı giriş yapmış mı kontrol et
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Firestore oyunları getirilemedi: Kullanıcı giriş yapmamış")
            completion(nil, nil)
            return
        }
        
        // Kullanıcının tamamlanmış oyunlarını sorgula
        db.collection("savedGames")
            .whereField("userID", isEqualTo: userID)
            .whereField("isCompleted", isEqualTo: true)  // Sadece tamamlanmış oyunları getir
            .order(by: "dateCreated", descending: true)  // En son tamamlananlar önce
            .limit(to: limit)  // Belirtilen sayıda oyun getir
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da tamamlanmış oyun bulunamadı")
                    completion(nil, nil)
                    return
                }
                
                // Sonuçları dönüştür
                var result: [String: Any] = [:]
                var games: [[String: Any]] = []
                
                for document in documents {
                    var gameData = document.data()
                    gameData["id"] = document.documentID
                    games.append(gameData)
                }
                
                result["games"] = games
                result["count"] = games.count
                
                print("✅ Firestore'dan \(games.count) tamamlanmış oyun yüklendi")
                completion(result, nil)
            }
    }
    
    // CoreData'dan kayıtlı oyunu sil
    func deleteSavedGameFromCoreData(gameID: String) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", gameID)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let gameToDelete = results.first {
                context.delete(gameToDelete)
                try context.save()
                print("✅ Oyun CoreData'dan başarıyla silindi")
            }
        } catch {
            print("❌ CoreData'dan oyun silinirken hata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Completed Games Management
    
    // Tüm tamamlanmış oyunları sil
    func deleteAllCompletedGames() {
        // Kullanıcı kontrolü: giriş yapmışsa
        guard Auth.auth().currentUser != nil else {
            print("⚠️ Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
            return
        }
        
        // Doğrudan Firestore'dan tamamlanmış oyunları sil
        deleteAllCompletedGamesFromFirestore()
    }
    
    // Firestore'dan tüm tamamlanmış oyunları sil
    func deleteAllCompletedGamesFromFirestore() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
            return
        }
        
        print("🔄 Tüm tamamlanmış oyunlar Firestore'dan siliniyor... Kullanıcı ID: \(userID)")
        
        // 1. Önce kullanıcıya ait tüm oyunları getirelim
        db.collection("savedGames")
            .whereField("userID", isEqualTo: userID)
            .whereField("isCompleted", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da kullanıcıya ait tamamlanmış oyun bulunamadı")
                    return
                }
                
                print("📊 Bulunan tamamlanmış oyun sayısı: \(documents.count)")
                
                // Tamamlanmış oyunları sil
                let batch = self.db.batch()
                
                for document in documents {
                    let documentID = document.documentID
                    print("🗑️ Siliniyor: \(documentID)")
                    let gameRef = self.db.collection("savedGames").document(documentID)
                    batch.deleteDocument(gameRef)
                }
                
                // Batch işlemini uygula
                batch.commit { error in
                    if let error = error {
                        print("❌ Firestore tamamlanmış oyun silme hatası: \(error.localizedDescription)")
                    } else {
                        print("✅ \(documents.count) tamamlanmış oyun Firestore'dan silindi")
                        
                        // Silme işleminin doğruluğunu kontrol et
                        self.verifyCompletedGameDeletion(of: documents.map { $0.documentID })
                    }
                }
            }
    }
    
    // Tamamlanmış oyunların silinmesini doğrula
    private func verifyCompletedGameDeletion(of documentIDs: [String]) {
        let group = DispatchGroup()
        var failedDeletions: [String] = []
        
        for documentID in documentIDs {
            group.enter()
            
            db.collection("savedGames").document(documentID).getDocument { document, error in
                defer { group.leave() }
                
                if let document = document, document.exists {
                    failedDeletions.append(documentID)
                    print("⚠️ Tamamlanmış oyun hala mevcut: \(documentID)")
                } else {
                    print("✅ Tamamlanmış oyun başarıyla silindi: \(documentID)")
                }
            }
        }
        
        group.notify(queue: .main) {
            if failedDeletions.isEmpty {
                print("✅ Tüm tamamlanmış oyunlar başarıyla silindi!")
            } else {
                print("⚠️ \(failedDeletions.count) tamamlanmış oyun silinemedi: \(failedDeletions)")
            }
        }
    }
}