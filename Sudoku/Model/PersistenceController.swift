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
    
    // Firebase dinleyicileri
    private var savedGamesListener: ListenerRegistration?
    private var deletedGamesListener: ListenerRegistration?
    
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
            } else {
                print("📡 CoreData yüklendi, Firebase dinleyicileri başlatılıyor...")
                // CoreData yüklendikten hemen sonra Firebase dinleyicilerini başlat
                DispatchQueue.main.async { [weak self] in
                    self?.setupDeletedGamesListener()
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // NotificationCenter'dan gelen oturum açma/çıkma bildirimlerini dinle
        setupNotificationObservers()
    }
    
    // MARK: - Firebase & Notification Listeners
    
    private func setupNotificationObservers() {
        // Kullanıcı giriş/çıkış bildirimlerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLoggedIn),
            name: NSNotification.Name("UserLoggedIn"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLoggedOut),
            name: NSNotification.Name("UserLoggedOut"),
            object: nil
        )
    }
    
    @objc private func handleUserLoggedIn() {
        print("🔔 Kullanıcı giriş bildirimi alındı - Firebase dinleyicileri başlatılıyor")
        setupDeletedGamesListener()
    }
    
    @objc private func handleUserLoggedOut() {
        print("🔔 Kullanıcı çıkış bildirimi alındı - Firebase dinleyicileri durdurulacak")
        deletedGamesListener?.remove()
        deletedGamesListener = nil
        savedGamesListener?.remove()
        savedGamesListener = nil
    }
    
    // BASİTLEŞTİRİLMİŞ Silinen oyunlar dinleyicisi
    private func setupDeletedGamesListener() {
        // Önceki dinleyicileri temizle
        deletedGamesListener?.remove()
        
        if Auth.auth().currentUser == nil {
            print("⚠️ Silinen oyunlar dinleyicisi başlatılamadı: Kullanıcı oturum açmamış")
            return
        }
        
        print("🔴 NÜKLEER ÇÖZÜM: Silinen oyunlar sistemi tamamen yeniden tasarlandı")
        print("📅 Tarih: \(Date().description)")
        
        // İlk kontrolü yap
        checkDeletedGamesManually()
        
        // Gerçek zamanlı dinleyiciyi başlat
        setupContinuousDeleteListener()
    }
    
    // Manuel kontrol - Silinen oyunlar tablosunda olup da yerel veritabanında hala mevcut olanları sil
    private func checkDeletedGamesManually() {
        guard Auth.auth().currentUser != nil else { return }
        
        print("🔎 Silinen oyunlar tam taraması başlatılıyor...")
        
        // 1. Yerel oyunları al
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        do {
            let localGames = try context.fetch(fetchRequest)
            let localGameIDs = localGames.compactMap { $0.id?.uuidString.uppercased() }
            
            print("📊 Yerel oyun sayısı: \(localGameIDs.count)")
            
            if localGameIDs.isEmpty {
                print("ℹ️ Yerel oyun bulunmadığı için silme kontrolüne gerek yok")
                return
            }
            
            // 2. Silinen oyunlar koleksiyonundaki TÜM kayıtları getir - her oyun için kontrol et
            db.collection("deletedGames").getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Silinen oyunlar getirilemedi: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("ℹ️ Silinen oyun kaydı bulunamadı")
                    return
                }
                
                print("🔍 Toplam \(documents.count) silinen oyun kaydı bulundu")
                var gamesToDelete = [UUID]()
                
                // Her silinen oyun için kontrol et
                for doc in documents {
                    guard let gameID = doc.data()["gameID"] as? String else { continue }
                    let upperGameID = gameID.uppercased()
                    
                    // Eğer bu oyun yerel veritabanımızda hala duruyorsa sil
                    if localGameIDs.contains(upperGameID), let uuid = UUID(uuidString: upperGameID) {
                        gamesToDelete.append(uuid)
                        print("🚨 Silinen oyun bulundu: \(upperGameID) - yerel veritabanından silinecek")
                    }
                }
                
                // Tespit edilen oyunları sil
                if !gamesToDelete.isEmpty {
                    print("🧹 \(gamesToDelete.count) oyun yerel veritabanından silinecek")
                    
                    for gameID in gamesToDelete {
                        DispatchQueue.main.async {
                            self.deleteLocalGameOnly(gameID: gameID)
                        }
                    }
                } else {
                    print("✅ Silinecek oyun bulunamadı - yerel veritabanı güncel")
                }
            }
            
        } catch {
            print("❌ Yerel oyunlar getirilemedi: \(error.localizedDescription)")
        }
        
        // Üst kısımda eski işlem mantığı kalmıştı, kaldırıldı.
    }
    
    // YÜKSEK ÖNCELİKLİ ÇÖZÜM: SAVEDGAMES DİNLEYİCİSİ - HER ANİ VE TÜM DEĞİŞİKLİKLERİ DİNLER
    private func setupContinuousDeleteListener() {
        // Kullanıcı giriş yapmamışsa geri dön
        guard let currentUser = Auth.auth().currentUser else { return }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        
        print("🟥 RADIKAL ÇÖZÜM: TÜM KAYDEDILMIŞ OYUNLARI GÖZETLEYEN SISTEM BAŞLATILIYOR!")
        print("👏 ARTIK SILINEN OYUNLAR KOLEKSIYONU KULLANILMIYOR!")
        print("💡 Cihaz: \(deviceID) | \(Date().description)")
        
        // SAVEDGAMES KOLEKSIYONUNU DOGRUDAN DINLE
        savedGamesListener = db.collection("savedGames")
            .whereField("userID", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Kaydedilmiş oyunlar dinleyicisi hatası! \(error.localizedDescription)")
                    return
                }
                
                print("🚨 SavedGames değişiklik algılandı - \(Date().timeIntervalSince1970)")
                
                guard let snapshot = querySnapshot else { return }
                
                // Tüm silme olaylarını takip et
                var silinenOyunlar = [String]()
                
                for degisiklik in snapshot.documentChanges where degisiklik.type == .removed {
                    let silinmisOyunID = degisiklik.document.documentID.uppercased()
                    print("🔴🔴🔴 SAVEDGAMES'DEN SİLİNEN OYUN ALGILANDI! ID: \(silinmisOyunID)")
                    silinenOyunlar.append(silinmisOyunID)
                }
                
                // Silinen oyunları yerel veritabanından da sil
                if !silinenOyunlar.isEmpty {
                    print("💥 \(silinenOyunlar.count) oyun Firebase'den silinmiş, yerel veritabanı güncelleniyor")
                    
                    // Yerel veritabanından al
                    let context = self.container.viewContext
                    let request = NSFetchRequest<SavedGame>(entityName: "SavedGame")
                    
                    // Her silinen oyun için
                    for silinmisOyunID in silinenOyunlar {
                        if let uuid = UUID(uuidString: silinmisOyunID) {
                            do {
                                // Silinen oyunu bul
                                request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                                let results = try context.fetch(request)
                                
                                // Bulunursa sil
                                if let oyun = results.first {
                                    print("💣 Yerel veritabanından oyun siliniyor: \(silinmisOyunID)")
                                    context.delete(oyun)
                                    try context.save()
                                    print("✅ Oyun yerel veritabanından silindi: \(silinmisOyunID)")
                                    
                                    // UI güncelleme bildirimi
                                    DispatchQueue.main.async {
                                        NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                                        print("📢 UI güncelleme bildirimi gönderildi")
                                    }
                                }
                            } catch {
                                print("❌ Yerel veritabanından silme hatası: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // Firebase'den tüm mevcut oyunları al
                let firebaseOyunIDs = Set(snapshot.documents.map { $0.documentID.uppercased() })
                
                // Yerel veritabanındaki tüm oyunları kontrol et
                do {
                    let yerelOyunlar = try self.container.viewContext.fetch(SavedGame.fetchRequest())
                    
                    // Firebase'de olmayan yerel oyunları bul
                    for oyun in yerelOyunlar {
                        if let oyunID = oyun.id?.uuidString.uppercased(), !firebaseOyunIDs.contains(oyunID) {
                            print("🔍 Firebase'de bulunmayan yerel oyun tespit edildi: \(oyunID)")
                            
                            // Firebase'de yoksa yerel veritabanından sil
                            self.container.viewContext.delete(oyun)
                            try self.container.viewContext.save()
                            print("✅ Firebase'de olmayan oyun yerel veritabanından silindi: \(oyunID)")
                            
                            // UI güncelleme bildirimi
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                            }
                        }
                    }
                } catch {
                    print("❌ Yerel-Firebase senkronizasyon hatası: \(error.localizedDescription)")
                }
            }
        
        print("🟩 SAVEDGAMES KOLEKSIYONU DİNLEYİCİSİ AKTİF - TÜM SİLME İŞLEMLERİ ALGILANACAK")
    }
    
    
    // Tam senkronizasyon kontrolü - tüm yerel oyunların ve buluttaki oyunların eşleştiğinden emin ol
    private func performFullSyncCheck() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        print("🔄 Tam senkronizasyon kontrolü başlatılıyor...")
        
        // 1. Önce Firebase'de olan tüm oyunları getir
        db.collection("savedGames")
            .whereField("userID", isEqualTo: currentUser.uid)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firebase oyunları getirme hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ Firebase oyunları getirilemedi")
                    return
                }
                
                // Firebase'deki tüm oyun ID'lerini al
                let firebaseGameIDs = Set(documents.compactMap { doc -> UUID? in
                    if let idString = doc.documentID as String?, let uuid = UUID(uuidString: idString) {
                        return uuid
                    }
                    return nil
                })
                
                print("🔎 Firebase'de \(firebaseGameIDs.count) kayıtlı oyun bulundu")
                
                // 2. Tüm yerel oyunları getir
                let context = self.container.viewContext
                let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
                
                do {
                    let localGames = try context.fetch(fetchRequest)
                    let localGameIDs = Set(localGames.compactMap { $0.id })
                    
                    print("🔎 Yerel veritabanında \(localGameIDs.count) kayıtlı oyun bulundu")
                    
                    // 3. Yerel olup Firebase'de olmayan oyunları yedekle
                    let localOnlyGames = localGameIDs.subtracting(firebaseGameIDs)
                    if !localOnlyGames.isEmpty {
                        print("ℹ️ \(localOnlyGames.count) oyun yalnızca yerel olarak bulundu, Firebase'e yedeklenecek")
                        // Bu oyunları Firebase'e yedekle (ileride)
                    }
                    
                    // 4. Firebase'de olup yerel olarak olmayan oyunları indir
                    let firebaseOnlyGames = firebaseGameIDs.subtracting(localGameIDs)
                    if !firebaseOnlyGames.isEmpty {
                        print("ℹ️ \(firebaseOnlyGames.count) oyun yalnızca Firebase'de bulundu, yerel olarak eklenecek")
                        // Bu oyunları ileride indirebiliriz
                    }
                    
                } catch {
                    print("❌ Yerel oyunları getirme hatası: \(error.localizedDescription)")
                }
            }
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
                "difficulty": difficulty,
                "isCompleted": false  // Yeni eklenen oyunlar tamamlanmamış olarak işaretlenir
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
                        "difficulty": difficulty,
                        "isCompleted": false  // Güncellenmiş oyunlar tamamlanmamış olarak işaretlenir
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
            
            // Silinen oyunları izlemek için son 24 saat içinde silinen ID'leri kontrol et
            let deletedGamesKey = "recentlyDeletedGameIDs"
            var recentlyDeletedIDs: [String] = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
            
            // 24 saatten eski silinen ID'leri temizle (Unix timestamp olarak saklıyoruz)
            let currentTimestamp = Date().timeIntervalSince1970
            let oneDayInSeconds: TimeInterval = 86400 // 24 saat
            
            // Silinen ID'lerin zaman damgalarını al
            let deletedTimestampsKey = "deletedGameTimestamps"
            let deletedTimestamps = UserDefaults.standard.dictionary(forKey: deletedTimestampsKey) as? [String: Double] ?? [:]
            
            // Eski kayıtları temizle (24 saatten eski)
            var updatedDeletedIDs: [String] = []
            var updatedDeletedTimestamps: [String: Double] = [:]
            
            for id in recentlyDeletedIDs {
                if let timestamp = deletedTimestamps[id],
                   currentTimestamp - timestamp < oneDayInSeconds {
                    // Hala geçerli (24 saat geçmemiş)
                    updatedDeletedIDs.append(id)
                    updatedDeletedTimestamps[id] = timestamp
                }
            }
            
            // Güncellenmiş listeleri sakla
            UserDefaults.standard.set(updatedDeletedIDs, forKey: deletedGamesKey)
            UserDefaults.standard.set(updatedDeletedTimestamps, forKey: deletedTimestampsKey)
            
            // Mevcut silinen ID'lerin son halini güncelle
            recentlyDeletedIDs = updatedDeletedIDs
            
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
                    
                    var newOrUpdatedGames = 0
                    
                    // Her belge için veri formatını kontrol edelim
                    let hasNewDataFormat = self.checkNewDataFormat(documents: documents)
                    print("🔍 Veri formatı kontrolü: \(hasNewDataFormat ? "Yeni format tespit edildi" : "Eski format tespit edildi")")
                    
                    // Firestore'dan gelen oyunları detaylı loglayalım
                    for (index, document) in documents.enumerated() {
                        let data = document.data()
                        print("   🔥 Firebase oyun \(index+1): ID = \(document.documentID), difficulty = \(data["difficulty"] as? String ?? "nil")")
                    }
                    
                    let context = self.container.viewContext
                    
                    // Her oyunu CoreData'ya kaydet veya güncelle
                    for document in documents {
                        let documentID = document.documentID
                        let data = document.data()
                        
                        // Eğer bu ID yerel olarak silinmişse, senkronize etme
                        if recentlyDeletedIDs.contains(documentID.uppercased()) || recentlyDeletedIDs.contains(documentID.lowercased()) {
                            print("⏭️ ID: \(documentID) olan oyun yakın zamanda silinmiş. Senkronize edilmiyor.")
                            continue
                        }
                        
                        // Oyunu yerel veritabanında bulmaya çalış - önce UUID'yi standardize edelim
                        let standardizedID = UUID(uuidString: documentID) ?? UUID(uuidString: documentID.uppercased()) ?? UUID(uuidString: documentID.lowercased())
                        
                        if standardizedID == nil {
                            print("⚠️ Geçersiz UUID formatı: \(documentID). Bu oyun atlanıyor.")
                            continue
                        }
                        
                        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", standardizedID! as CVarArg)
                        
                        do {
                            let matchingGames = try context.fetch(fetchRequest)
                            
                            // Firestore'dan oyun verilerini çıkaralım
                            let difficulty = data["difficulty"] as? String ?? "Kolay"
                            let dateCreated = (data["dateCreated"] as? Timestamp)?.dateValue() ?? Date()
                            let elapsedTime = data["elapsedTime"] as? Double ?? 0
                            
                            // Oyun yerel veritabanında varsa güncelle
                            if let existingGame = matchingGames.first {
                                // Güncellemeden önce değişiklik olup olmadığını kontrol edelim
                                let hasChanged = existingGame.difficulty != difficulty ||
                                existingGame.elapsedTime != elapsedTime ||
                                self.hasBoardStateChanged(existingGame: existingGame, firestoreData: data, newFormat: hasNewDataFormat)
                                
                                if hasChanged {
                                    print("🔄 Oyun ID: \(documentID) için değişiklik tespit edildi. Güncelleniyor...")
                                    
                                    // Oyunu güncelle
                                    existingGame.difficulty = difficulty
                                    existingGame.dateCreated = dateCreated
                                    existingGame.elapsedTime = elapsedTime
                                    
                                    // Tahta durumunu güncelle
                                    if hasNewDataFormat {
                                        // Yeni format (boardState bir map)
                                        if let boardData = data["boardState"] as? [String: Any],
                                           let boardJSON = try? JSONSerialization.data(withJSONObject: boardData) {
                                            existingGame.boardState = boardJSON
                                            newOrUpdatedGames += 1
                                        }
                                    } else {
                                        // Eski format (flat board)
                                        if let flatBoard = data["board"] as? [Int],
                                           let size = data["size"] as? Int {
                                            
                                            // Düz diziyi matrise dönüştür
                                            var board: [[Int]] = []
                                            for i in stride(from: 0, to: flatBoard.count, by: size) {
                                                let row = Array(flatBoard[i..<min(i + size, flatBoard.count)])
                                                board.append(row)
                                            }
                                            
                                            // Tahta verisini JSON olarak kaydet
                                            let boardDict: [String: Any] = [
                                                "board": board,
                                                "difficulty": difficulty,
                                                "isCompleted": data["isCompleted"] as? Bool ?? false
                                            ]
                                            
                                            if let boardJSON = try? JSONSerialization.data(withJSONObject: boardDict) {
                                                existingGame.boardState = boardJSON
                                                newOrUpdatedGames += 1
                                            }
                                        }
                                    }
                                } else {
                                    print("ℹ️ Oyun ID: \(documentID) için değişiklik yok. Atlıyor.")
                                }
                            } else {
                                // Yeni oyun oluştur
                                print("➕ Yeni oyun oluşturuluyor: \(documentID)")
                                
                                let newGame = SavedGame(context: context)
                                newGame.id = standardizedID
                                newGame.difficulty = difficulty
                                newGame.dateCreated = dateCreated
                                newGame.elapsedTime = elapsedTime
                                
                                // Tahta durumunu ayarla
                                if hasNewDataFormat {
                                    // Yeni format (boardState bir map)
                                    if let boardData = data["boardState"] as? [String: Any],
                                       let boardJSON = try? JSONSerialization.data(withJSONObject: boardData) {
                                        newGame.boardState = boardJSON
                                        newOrUpdatedGames += 1
                                    }
                                } else {
                                    // Eski format (flat board)
                                    if let flatBoard = data["board"] as? [Int],
                                       let size = data["size"] as? Int {
                                        
                                        // Düz diziyi matrise dönüştür
                                        var board: [[Int]] = []
                                        for i in stride(from: 0, to: flatBoard.count, by: size) {
                                            let row = Array(flatBoard[i..<min(i + size, flatBoard.count)])
                                            board.append(row)
                                        }
                                        
                                        // Tahta verisini JSON olarak kaydet
                                        let boardDict: [String: Any] = [
                                            "board": board,
                                            "difficulty": difficulty,
                                            "isCompleted": data["isCompleted"] as? Bool ?? false
                                        ]
                                        
                                        if let boardJSON = try? JSONSerialization.data(withJSONObject: boardDict) {
                                            newGame.boardState = boardJSON
                                            newOrUpdatedGames += 1
                                        }
                                    }
                                }
                            }
                        } catch {
                            print("❌ Oyun işleme hatası: \(error.localizedDescription)")
                        }
                    }
                    
                    // Değişiklikleri kaydet
                    do {
                        if context.hasChanges {
                            try context.save()
                            
                            // Sadece değişiklik olduğunda bildirim gönder
                            if newOrUpdatedGames > 0 {
                                print("✅ \(newOrUpdatedGames) oyun başarıyla senkronize edildi")
                                // Core Data'nın yenilenmesi için bildirim gönder
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                                }
                            } else {
                                print("ℹ️ Senkronizasyon tamamlandı, değişiklik yapılmadı.")
                            }
                        } else {
                            print("ℹ️ Senkronizasyon tamamlandı, kaydedilecek değişiklik yok.")
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
    
    // Yeni format tespiti için iyileştirilmiş yardımcı fonksiyon
    private func checkNewDataFormat(documents: [QueryDocumentSnapshot]) -> Bool {
        var newFormatCount = 0
        var oldFormatCount = 0
        
        for document in documents {
            let data = document.data()
            
            // Yeni formatta, boardState bir map olacak
            if let _ = data["boardState"] as? [String: Any] {
                newFormatCount += 1
            }
            // Eski formatta, board bir dizi olacak
            else if let _ = data["board"] as? [Int] {
                oldFormatCount += 1
            }
        }
        
        print("📊 Format Analizi: \(newFormatCount) yeni format, \(oldFormatCount) eski format oyun")
        
        // Çoğunluğa göre karar ver
        return newFormatCount >= oldFormatCount
    }
    
    // BoardState değişimini kontrol et
    private func hasBoardStateChanged(existingGame: SavedGame, firestoreData: [String: Any], newFormat: Bool) -> Bool {
        // Mevcut oyunun boardState'ini kontrol et
        guard let existingBoardData = existingGame.boardState else {
            return true // Eğer mevcut veri yoksa, değişiklik var sayalım
        }
        
        if newFormat {
            // Yeni format için kontrol
            if let boardData = firestoreData["boardState"] as? [String: Any],
               let newBoardJSON = try? JSONSerialization.data(withJSONObject: boardData) {
                // Veri boyutu farklıysa, içerik değişmiştir
                if existingBoardData.count != newBoardJSON.count {
                    return true
                }
                
                // Daha detaylı karşılaştırma için verileri decode edip karşılaştıralım
                do {
                    let existingDict = try JSONSerialization.jsonObject(with: existingBoardData) as? [String: Any]
                    let newDict = try JSONSerialization.jsonObject(with: newBoardJSON) as? [String: Any]
                    
                    // Board veya difficulty değişmişse
                    if let existingBoard = existingDict?["board"] as? [[Int]],
                       let newBoard = newDict?["board"] as? [[Int]],
                       !self.areArraysEqual(existingBoard, newBoard) {
                        return true
                    }
                    
                    if let existingDifficulty = existingDict?["difficulty"] as? String,
                       let newDifficulty = newDict?["difficulty"] as? String,
                       existingDifficulty != newDifficulty {
                        return true
                    }
                    
                    // isCompleted durumu değişmişse
                    if let existingCompleted = existingDict?["isCompleted"] as? Bool,
                       let newCompleted = newDict?["isCompleted"] as? Bool,
                       existingCompleted != newCompleted {
                        return true
                    }
                } catch {
                    print("⚠️ JSON karşılaştırma hatası: \(error)")
                    return true // Hata durumunda güvenli tarafta kal
                }
            }
        } else {
            // Eski format için kontrol (board array)
            if let flatBoard = firestoreData["board"] as? [Int],
               let size = firestoreData["size"] as? Int {
                
                // Düz diziyi matrise dönüştür
                var board: [[Int]] = []
                for i in stride(from: 0, to: flatBoard.count, by: size) {
                    let row = Array(flatBoard[i..<min(i + size, flatBoard.count)])
                    board.append(row)
                }
                
                // Mevcut veriyi karşılaştır
                do {
                    if let existingDict = try JSONSerialization.jsonObject(with: existingBoardData) as? [String: Any],
                       let existingBoard = existingDict["board"] as? [[Int]] {
                        
                        if !self.areArraysEqual(existingBoard, board) {
                            return true
                        }
                    }
                } catch {
                    print("⚠️ JSON karşılaştırma hatası: \(error)")
                    return true
                }
            }
        }
        
        return false
    }
    
    // İki dizi karşılaştırma yardımcı fonksiyonu
    private func areArraysEqual(_ array1: [[Int]], _ array2: [[Int]]) -> Bool {
        guard array1.count == array2.count else { return false }
        
        for i in 0..<array1.count {
            guard i < array2.count && array1[i].count == array2[i].count else { return false }
            
            for j in 0..<array1[i].count {
                guard j < array2[i].count && array1[i][j] == array2[i][j] else { return false }
            }
        }
        
        return true
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
        
        // UUID'yi uppercase olarak kullan
        let documentID = gameID.uuidString.uppercased()
        print("🔄 \(documentID) ID'li oyun siliniyor...")
        
        // ID'ye göre oyunu bul
        let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", gameID as CVarArg)
        
        do {
            let games = try context.fetch(request)
            
            if let existingGame = games.first {
                // Silinen oyunu "son silinen oyunlar" listesine ekle
                let deletedGamesKey = "recentlyDeletedGameIDs"
                var recentlyDeletedIDs = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
                
                // Eğer zaten listede yoksa ekle
                if !recentlyDeletedIDs.contains(documentID) {
                    recentlyDeletedIDs.append(documentID)
                    UserDefaults.standard.set(recentlyDeletedIDs, forKey: deletedGamesKey)
                    
                    // Silme zamanını kaydet
                    let deletedTimestampsKey = "deletedGameTimestamps"
                    var deletedTimestamps = UserDefaults.standard.dictionary(forKey: deletedTimestampsKey) as? [String: Double] ?? [:]
                    deletedTimestamps[documentID] = Date().timeIntervalSince1970
                    UserDefaults.standard.set(deletedTimestamps, forKey: deletedTimestampsKey)
                }
                
                // Önce Firestore'dan silme işlemini başlat
                deleteGameFromFirestore(gameID: gameID)
                
                // Ardından Core Data'dan sil
                context.delete(existingGame)
                try context.save()
                print("✅ ID'si \(gameID) olan oyun başarıyla Core Data'dan silindi")
                
                // Bildirimleri gönder - UI güncellemesi için
                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
            } else {
                print("❓ Silinecek oyun Core Data'da bulunamadı, ID: \(gameID)")
                // Core Data'da bulunamasa bile Firebase'den silmeyi dene
                deleteGameFromFirestore(gameID: gameID)
            }
        } catch {
            print("❌ Oyun silinemedi: \(error)")
        }
    }
    
    // Firestore'dan oyun silme - TAMAMEN BASİTLEŞTİRİLMİŞ YENI ÇÖZÜM
    func deleteGameFromFirestore(gameID: UUID) {
        // UUID'yi uppercase olarak kullan
        let documentID = gameID.uuidString.uppercased()
        
        print("🟠 SON ÇÖZÜM: Oyun silme işlemi başlıyor \(Date())")
        print("📍 Oyun: \(documentID)")
        
        if Auth.auth().currentUser == nil {
            print("❌ Kullanıcı oturum açmamış")
            return
        }
        
        // SADECE VE SADECE "gameID" alanını ekle - BU KADAR!
        let deletedGameData: [String: Any] = [
            "gameID": documentID,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Silinen oyunlar koleksiyonuna ekle
        print("🔴 NKLEER ÇÖZÜM 4.0: Oyun ID silinen oyunlar listesine benzersiz ID ile ekleniyor: \(documentID)")
        
        // FARKLI BİR YAKLAŞIM: Her silme işlemi için yeni bir benzersiz belge ID kullan
        // Böylece her silme işlemi yeni bir belge olarak görülecek ve diğer cihazlar bu değişikliği kesinlikle algılayacak
        db.collection("deletedGames").addDocument(data: deletedGameData) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ HATA: \(error.localizedDescription)")
                return
            }
            
            print("✅ ADIM 1 TAMAM: Oyun silinen oyunlar listesine eklendi")
            
            // 3 saniye bekleyerek oyunu Firebase'den sil
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("🟠 ADIM 2: Oyun Firestore'dan siliniyor...")
                
                self.db.collection("savedGames").document(documentID).delete { error in
                    if let error = error {
                        print("❌ Hata: \(error.localizedDescription)")
                    } else {
                        print("✅ ADIM 2 TAMAM: Oyun silindi: \(documentID)")
                    }
                    
                    // Manuel kontrol tetikle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.checkDeletedGamesManually()
                    }
                }
            }
        }
    }
    
    // Silinen oyunları kontrol et - manuel tetikleme için - GELİŞTİRİLMİŞ VERSİYON 2.0
    func checkForDeletedGames() {
        // Kullanıcı giriş yapmamışsa geri dön
        guard Auth.auth().currentUser != nil else { return }
        
        print("🔴 NÜKLEER KONTROL ÇAĞRILDI: TÜM silinen oyunlar kontrol edilecek")
        
        // TÜM silinen oyunları getir - filtreleme OLMADAN
        db.collection("deletedGames").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Silinen oyunlar getirilemedi: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("ℹ️ Silinen oyun kaydı bulunamadı")
                return
            }
            
            print("📊 Toplam \(documents.count) silinen oyun kaydı bulundu")
            
            // Önce tüm yerel oyunları getir
            let context = self.container.viewContext
            let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
            
            do {
                let localGames = try context.fetch(fetchRequest)
                let localGameIDs = localGames.compactMap { $0.id?.uuidString.uppercased() }
                
                print("💾 YEREL OYUNLAR: \(localGameIDs.count) oyun var")
                var silinecekOyunlar = [UUID]()
                
                // Her silinen oyun için, yerelde var mı diye kontrol et
                for document in documents {
                    guard let gameID = document.data()["gameID"] as? String else { continue }
                    let upperGameID = gameID.uppercased()
                    
                    print("🕵️ Silinen oyun kontrolu: \(upperGameID)")
                    
                    // Yerel veritabanında bu ID'ye sahip oyun var mı?
                    if localGameIDs.contains(upperGameID), let uuid = UUID(uuidString: upperGameID) {
                        silinecekOyunlar.append(uuid)
                        print("🔥 Eşleşme bulundu! \(upperGameID) silinecek")
                    }
                }
                
                // Tespit edilen oyunları sil
                if !silinecekOyunlar.isEmpty {
                    print("🧹 \(silinecekOyunlar.count) oyun bulundu ve silinecek")
                    
                    for gameID in silinecekOyunlar {
                        self.deleteLocalGameOnly(gameID: gameID)
                    }
                } else {
                    print("✅ Silinecek yerel oyun bulunamadı - zaten güncel")
                }
            } catch {
                print("❌ Yerel oyunlar getirilemedi: \(error.localizedDescription)")
            }
        }
    }
    
    // Sadece yerel CoreData'daki oyunu sil - Firebase'e bildirim göndermeden - GELİŞTİRİLMİŞ VERSİYON
    // Bu metod, başka bir cihazdan silinen oyunlar için kullanılır
    func deleteLocalGameOnly(gameID: UUID) {
        print("🔵 GELİŞTİRİLMİŞ SİLME FONKSİYONU: \(gameID)")
        
        // UUID'yi uppercase olarak al (standart format)
        let gameIDString = gameID.uuidString.uppercased()
        
        // Context ve fetch request oluştur
        let context = container.viewContext
        
        // Tüm oyunları getir ve kendi filtreleyelim
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        // Önce tüm oyunları çekip, UUID'leri kendimiz kontrol edelim (daha güvenilir)
        do {
            let allGames = try context.fetch(fetchRequest)
            print("💾 Toplam \(allGames.count) oyun kontrol edilecek")
            
            // Sililenecek oyunları bulalım
            var gameToDelete: SavedGame? = nil
            
            for game in allGames {
                if let gameUUID = game.id {
                    // UUID'yi uppercase formata standardize et
                    let currentGameUUID = gameUUID.uuidString.uppercased()
                    
                    // Eşleşme kontrolü - UUID karşılaştırma
                    if currentGameUUID == gameIDString {
                        gameToDelete = game
                        print("🔍 Eşleşen oyun bulundu! \(currentGameUUID)")
                        break
                    }
                }
            }
            
            // Silme işlemi
            if let gameToDelete = gameToDelete {
                // CoreData'dan oyunu sil
                context.delete(gameToDelete)
                try context.save()
                print("✅ OYUN SİLİNDİ! \(gameIDString) ID'li oyun yerel veritabanından kaldırıldı")
                
                // Bildirimleri gönder - UI güncellemesi için (güvenli olması için gecikme ile)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                    print("📢 UI Yenileme bildirimi gönderildi - Oyun listesi güncellenecek")
                }
            } else {
                print("🔎 Silmek için oyun bulunamadı. ID: \(gameIDString)")
            }
        } catch {
            print("❌ Yerel oyun silinirken hata: \(error.localizedDescription)")
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
    
    // MARK: - User Account Management
    
    // Kullanıcı hesabını sil
    func deleteUserAccount(completion: @escaping (Bool, Error?) -> Void) {
        // Kullanıcının giriş yapmış olduğundan emin ol
        guard let currentUser = getCurrentUser(), let firebaseUID = currentUser.firebaseUID else {
            print("❌ Hesap silme hatası: Kullanıcı giriş yapmamış veya Firebase UID yok")
            completion(false, NSError(domain: "AccountError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı giriş yapmamış"]))
            return
        }
        
        // Önce kullanıcının yerel verilerini sil, sonra Firebase'i sil
        // Bu şekilde Firebase silme işlemi başarısız olsa bile yerel veriler silinmiş olur
        
        // 1. Yerel veritabanından kullanıcıyı ve verilerini sil
        let context = self.container.viewContext
        
        // Kullanıcının kayıtlı oyunlarını sil
        let savedGamesRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        savedGamesRequest.predicate = NSPredicate(format: "user == %@", currentUser)
        
        do {
            let savedGames = try context.fetch(savedGamesRequest)
            for game in savedGames {
                context.delete(game)
            }
            print("✅ Yerel veritabanından \(savedGames.count) kayıtlı oyun silindi")
        } catch {
            print("❌ Kayıtlı oyunları silme hatası: \(error.localizedDescription)")
        }
        
        // Kullanıcının yüksek skorlarını sil
        let highScoresRequest: NSFetchRequest<HighScore> = HighScore.fetchRequest()
        highScoresRequest.predicate = NSPredicate(format: "user == %@", currentUser)
        
        do {
            let highScores = try context.fetch(highScoresRequest)
            for score in highScores {
                context.delete(score)
            }
            print("✅ Yerel veritabanından \(highScores.count) yüksek skor silindi")
        } catch {
            print("❌ Yüksek skorları silme hatası: \(error.localizedDescription)")
        }
        
        // Kullanıcının başarımlarını sil
        if NSEntityDescription.entity(forEntityName: "Achievement", in: context) != nil {
            let achievementsRequest = NSFetchRequest<NSManagedObject>(entityName: "Achievement")
            achievementsRequest.predicate = NSPredicate(format: "user == %@", currentUser)
            
            do {
                let achievements = try context.fetch(achievementsRequest)
                for achievement in achievements {
                    context.delete(achievement)
                }
                print("✅ Yerel veritabanından \(achievements.count) başarım silindi")
            } catch {
                print("❌ Başarımları silme hatası: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ Achievement entity'si bulunamadı veya kullanılabilir değil")
        }
        
        // Kullanıcıyı sil
        context.delete(currentUser)
        
        // Değişiklikleri kaydet
        do {
            try context.save()
            print("✅ Yerel kullanıcı verileri başarıyla silindi")
        } catch {
            print("❌ Yerel kullanıcı verilerini silerken hata: \(error.localizedDescription)")
            completion(false, error)
            return
        }
            
        // 2. Firebase Authentication'dan kullanıcıyı sil
        Auth.auth().currentUser?.delete { [weak self] error in
            guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firebase hesap silme hatası: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                // 2. Firestore'dan kullanıcı verilerini sil
                self.db.collection("users").document(firebaseUID).delete { error in
                    if let error = error {
                        print("❌ Firestore kullanıcı silme hatası: \(error.localizedDescription)")
                        // Firebase Auth'dan silindiği için devam ediyoruz
                    }
                    
                    // Ek olarak, kullanıcı ile ilgili tüm diğer koleksiyonları da temizleyelim
                    print("🚩 Firestore'daki tüm kullanıcı verilerini silme işlemi başlatılıyor...")
                    
                    // 3. Firestore'dan kullanıcının kayıtlı oyunlarını sil
                    self.db.collection("savedGames").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                        if let error = error {
                            print("❌ Firestore kayıtlı oyunları getirme hatası: \(error.localizedDescription)")
                        } else if let snapshot = snapshot {
                            // Tüm kayıtlı oyunları sil
                            for document in snapshot.documents {
                                self.db.collection("savedGames").document(document.documentID).delete()
                            }
                            print("✅ Firestore'dan \(snapshot.documents.count) kayıtlı oyun silindi")
                        }
                        
                        // 4. Firestore'dan kullanıcının tamamlanmış oyunlarını sil
                        self.db.collection("completedGames").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                            if let error = error {
                                print("❌ Firestore tamamlanmış oyunları getirme hatası: \(error.localizedDescription)")
                            } else if let snapshot = snapshot {
                                // Tüm tamamlanmış oyunları sil
                                for document in snapshot.documents {
                                    self.db.collection("completedGames").document(document.documentID).delete()
                                }
                                print("✅ Firestore'dan \(snapshot.documents.count) tamamlanmış oyun silindi")
                            }
                            
                            // Firestore'dan başarımları sil
                            self.db.collection("achievements").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                if let error = error {
                                    print("❌ Firestore başarımları getirme hatası: \(error.localizedDescription)")
                                } else if let snapshot = snapshot {
                                    // Tüm başarımları sil
                                    for document in snapshot.documents {
                                        self.db.collection("achievements").document(document.documentID).delete()
                                    }
                                    print("✅ Firestore'dan \(snapshot.documents.count) başarım silindi")
                                }
                                
                                // Ek koleksiyonları da temizleyelim
                                // 1. highScores koleksiyonu
                                self.db.collection("highScores").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                    if let error = error {
                                        print("❌ Firestore yüksek skorları getirme hatası: \(error.localizedDescription)")
                                    } else if let snapshot = snapshot {
                                        for document in snapshot.documents {
                                            self.db.collection("highScores").document(document.documentID).delete()
                                        }
                                        print("✅ Firestore'dan \(snapshot.documents.count) yüksek skor silindi")
                                    }
                                    
                                    // 2. userPreferences koleksiyonu
                                    self.db.collection("userPreferences").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                        if let error = error {
                                            print("❌ Firestore kullanıcı tercihlerini getirme hatası: \(error.localizedDescription)")
                                        } else if let snapshot = snapshot {
                                            for document in snapshot.documents {
                                                self.db.collection("userPreferences").document(document.documentID).delete()
                                            }
                                            print("✅ Firestore'dan \(snapshot.documents.count) kullanıcı tercihi silindi")
                                        }
                                        
                                        // 3. userStats koleksiyonu
                                        self.db.collection("userStats").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                            if let error = error {
                                                print("❌ Firestore kullanıcı istatistiklerini getirme hatası: \(error.localizedDescription)")
                                            } else if let snapshot = snapshot {
                                                for document in snapshot.documents {
                                                    self.db.collection("userStats").document(document.documentID).delete()
                                                }
                                                print("✅ Firestore'dan \(snapshot.documents.count) kullanıcı istatistiği silindi")
                                            }
                                            
                                            // 4. userActivity koleksiyonu
                                            self.db.collection("userActivity").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                                if let error = error {
                                                    print("❌ Firestore kullanıcı aktivitelerini getirme hatası: \(error.localizedDescription)")
                                                } else if let snapshot = snapshot {
                                                    for document in snapshot.documents {
                                                        self.db.collection("userActivity").document(document.documentID).delete()
                                                    }
                                                    print("✅ Firestore'dan \(snapshot.documents.count) kullanıcı aktivitesi silindi")
                                                }
                                                
                                                // 5. notifications koleksiyonu
                                                self.db.collection("notifications").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                                    if let error = error {
                                                        print("❌ Firestore bildirimlerini getirme hatası: \(error.localizedDescription)")
                                                    } else if let snapshot = snapshot {
                                                        for document in snapshot.documents {
                                                            self.db.collection("notifications").document(document.documentID).delete()
                                                        }
                                                        print("✅ Firestore'dan \(snapshot.documents.count) bildirim silindi")
                                                    }
                                                    
                                                    // 6. friends koleksiyonu (hem kullanıcının arkadaşları hem de kullanıcıyı arkadaş olarak ekleyenler)
                                                    self.db.collection("friends").whereField("userID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                                        if let error = error {
                                                            print("❌ Firestore arkadaşları getirme hatası: \(error.localizedDescription)")
                                                        } else if let snapshot = snapshot {
                                                            for document in snapshot.documents {
                                                                self.db.collection("friends").document(document.documentID).delete()
                                                            }
                                                            print("✅ Firestore'dan \(snapshot.documents.count) arkadaşlık kaydı silindi (kullanıcının arkadaşları)")
                                                        }
                                                        
                                                        self.db.collection("friends").whereField("friendID", isEqualTo: firebaseUID).getDocuments(source: .default) { snapshot, error in
                                                            if let error = error {
                                                                print("❌ Firestore arkadaş olarak ekleyenleri getirme hatası: \(error.localizedDescription)")
                                                            } else if let snapshot = snapshot {
                                                                for document in snapshot.documents {
                                                                    self.db.collection("friends").document(document.documentID).delete()
                                                                }
                                                                print("✅ Firestore'dan \(snapshot.documents.count) arkadaşlık kaydı silindi (kullanıcıyı arkadaş olarak ekleyenler)")
                                                            }
                                                            
                                                            print("✅ Firestore'daki tüm kullanıcı verileri başarıyla silindi!")
                                                            
                                                            // Çıkış yapma bildirimi gönder
                                                            NotificationCenter.default.post(name: Notification.Name("UserLoggedOut"), object: nil)
                                                            
                                                            completion(true, nil)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // MARK: - Firebase User Management
        
        // Profil resimlerini senkronize etmek için yeni bir fonksiyon ekle
        func syncProfileImage(completion: @escaping (Bool) -> Void = { _ in }) {
            // Kullanıcı giriş yapmış mı kontrol et
            guard let currentUser = getCurrentUser(),
                  let firebaseUID = currentUser.firebaseUID else {
                print("⚠️ Profil resmi senkronize edilemedi: Kullanıcı giriş yapmamış veya Firebase UID yok")
                completion(false)
                return
            }
            
            print("🔄 Profil resmi Firebase'den senkronize ediliyor...")
            
            // Firebase'den kullanıcı bilgilerini al
            db.collection("users").document(firebaseUID).getDocument { [weak self] (document, error) in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if let error = error {
                    print("❌ Firebase profil bilgisi getirme hatası: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let document = document, document.exists,
                      let userData = document.data() else {
                    print("⚠️ Firebase'de kullanıcı bilgisi bulunamadı")
                    completion(false)
                    return
                }
                
                // Profil resmi URL'sini kontrol et
                if let photoURL = userData["photoURL"] as? String {
                    // URL'leri karşılaştır
                    if photoURL != currentUser.photoURL {
                        print("🔄 Firebase'de farklı profil resmi bulundu, güncelleniyor...")
                        
                        // Yerel URL'yi güncelle
                        currentUser.photoURL = photoURL
                        
                        do {
                            try self.container.viewContext.save()
                            print("✅ Profil resmi URL'si yerel veritabanında güncellendi")
                            
                            // Profil resmini indir
                            self.downloadProfileImage(forUser: currentUser, fromURL: photoURL)
                            completion(true)
                        } catch {
                            print("❌ Profil resmi URL'si güncellenirken hata: \(error.localizedDescription)")
                            completion(false)
                        }
                    } else {
                        print("✅ Profil resmi URL'si zaten güncel")
                        completion(true)
                    }
                } else {
                    print("ℹ️ Firebase'de profil resmi URL'si bulunamadı")
                    completion(false)
                }
            }
        }
        
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
                
                // Firestore'daki kullanıcı bilgilerini al ve güncelle
                self.db.collection("users").document(firebaseUser.uid).getDocument { [weak self] (document, error) in
                    guard let self = self else { return }
                    
                    var userProfile: [String: Any] = [
                        "lastLoginDate": FieldValue.serverTimestamp(),
                        "isLoggedIn": true
                    ]
                    
                    if let document = document, document.exists {
                        // Kullanıcı zaten var, bilgileri alalım
                        let userData = document.data() ?? [:]
                        
                        // Profil resmi URL'sini al
                        if let photoURL = userData["photoURL"] as? String {
                            print("📸 Kullanıcının Firestore'da kayıtlı profil resmi bulundu: \(photoURL)")
                            userProfile["photoURL"] = photoURL
                        } else if let photoURL = firebaseUser.photoURL?.absoluteString {
                            print("📸 Kullanıcının Firebase Auth'ta kayıtlı profil resmi bulundu: \(photoURL)")
                            userProfile["photoURL"] = photoURL
                        }
                        
                        // Firestore'da profil bilgilerini güncelle
                        self.db.collection("users").document(firebaseUser.uid).updateData(userProfile) { error in
                            if let error = error {
                                print("⚠️ Firestore giriş bilgisi güncellenemedi: \(error.localizedDescription)")
                            } else {
                                print("✅ Firestore giriş bilgisi güncellendi")
                            }
                        }
                    } else {
                        // Kullanıcı belki ilk kez Firebase ile giriş yapıyor, kayıt edelim
                        if let photoURL = firebaseUser.photoURL?.absoluteString {
                            userProfile["photoURL"] = photoURL
                        }
                        userProfile["email"] = email
                        userProfile["name"] = firebaseUser.displayName ?? "Kullanıcı"
                        // Kullanıcı adı olarak e-postanın @ işaretinden önceki kısmını kullanmak yerine
                        // benzersiz bir kullanıcı adı oluşturuyoruz
                        userProfile["username"] = "user_" + UUID().uuidString.prefix(8).lowercased()
                        userProfile["registrationDate"] = FieldValue.serverTimestamp()
                        
                        self.db.collection("users").document(firebaseUser.uid).setData(userProfile) { error in
                            if let error = error {
                                print("⚠️ Firestore yeni kullanıcı kaydedilemedi: \(error.localizedDescription)")
                            } else {
                                print("✅ Kullanıcı Firestore'a kaydedildi")
                            }
                        }
                    }
                    
                    // Firebase UID'ye göre yerel kullanıcıyı bulma
                    let context = self.container.viewContext
                    let request: NSFetchRequest<User> = User.fetchRequest()
                    request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUser.uid)
                    
                    do {
                        let users = try context.fetch(request)
                        if let existingUser = users.first {
                            // Kullanıcı yerel veritabanında var, giriş durumunu ve profil resmi URL'sini güncelle
                            existingUser.isLoggedIn = true
                            
                            // Profil resmi URL'sini güncelle
                            if let photoURL = userProfile["photoURL"] as? String {
                                existingUser.photoURL = photoURL
                                print("✅ Profil resmi URL'si güncellendi: \(photoURL)")
                                
                                // Profil resmini hemen indirmeyi başlat
                                self.downloadProfileImage(forUser: existingUser, fromURL: photoURL)
                            }
                            
                            try context.save()
                            print("✅ Firebase kullanıcısı yerel veritabanında güncellendi")
                            
                            // Giriş bildirimini gönder
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                            }
                            
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
                            
                            // Profil resmi URL'sini güncelle
                            if let photoURL = userProfile["photoURL"] as? String {
                                existingUser.photoURL = photoURL
                                print("✅ Varolan kullanıcının profil resmi URL'si güncellendi: \(photoURL)")
                                
                                // Profil resmini hemen indirmeyi başlat
                                self.downloadProfileImage(forUser: existingUser, fromURL: photoURL)
                            }
                            
                            try context.save()
                            print("✅ Kullanıcı firebase UID ile güncellendi")
                            
                            // Giriş bildirimini gönder
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                            }
                            
                            completion(existingUser, nil)
                            return
                        }
                        
                        // Kullanıcı yerel veritabanında yok, oluştur
                        let newUser = User(context: context)
                        
                        // Kullanıcı bilgilerini ayarla
                        newUser.id = UUID()
                        
                        // Firebase'den kullanıcı adını al veya benzersiz bir kullanıcı adı oluştur
                        if let username = document?.data()?["username"] as? String, !username.isEmpty {
                            newUser.username = username
                            print("✅ Firebase'den kullanıcı adı alındı: \(username)")
                        } else {
                            // Benzersiz bir kullanıcı adı oluştur
                            newUser.username = "user_" + UUID().uuidString.prefix(8).lowercased()
                            print("✅ E-postadan kullanıcı adı oluşturuldu: \(newUser.username ?? "")")
                        }
                        newUser.email = email
                        newUser.name = firebaseUser.displayName ?? newUser.username
                        newUser.registrationDate = Date()
                        newUser.isLoggedIn = true
                        newUser.firebaseUID = firebaseUser.uid
                        
                        // Profil resmi URL'sini ayarla
                        if let photoURL = userProfile["photoURL"] as? String {
                            newUser.photoURL = photoURL
                            print("✅ Yeni kullanıcının profil resmi URL'si ayarlandı: \(photoURL)")
                            
                            // Profil resmini hemen indirmeyi başlat
                            self.downloadProfileImage(forUser: newUser, fromURL: photoURL)
                        }
                        
                        try context.save()
                        print("✅ Firebase kullanıcısı yerel veritabanına kaydedildi")
                        
                        // Profil resmi olmasa bile giriş bildirimini gönder
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                        }
                        
                        completion(newUser, nil)
                    } catch {
                        print("❌ Firebase kullanıcısı yerel veritabanına kaydedilemedi: \(error.localizedDescription)")
                        completion(nil, error)
                    }
                }
            }
        }
        
    // Profil resmi yükleme yardımcı fonksiyonu - geliştirilmiş versiyon
    private func downloadProfileImage(forUser user: User, fromURL urlString: String) {
            let timestamp = Date()
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
            print("🔄 [\(deviceID)] Profil resmi indiriliyor: \(urlString) | Zaman: \(timestamp)")
            
            // Önbellek temizleme
            URLCache.shared.removeAllCachedResponses()
            
            guard let url = URL(string: urlString) else {
                print("❌ [\(deviceID)] Geçersiz profil resmi URL'si: \(urlString)")
                return
            }
            
            // Zorla yeniden yükleme için önbellek politikasını güncelle
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 15 // 15 saniyelik timeout
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [\(deviceID)] Profil resmi indirme hatası: \(error.localizedDescription)")
                    return
                }
                
                if let response = response as? HTTPURLResponse {
                    print("📡 [\(deviceID)] Profil resmi yanıt kodu: \(response.statusCode)")
                    
                    // Başarısız yanıt kodları için erken dönüş
                    if response.statusCode < 200 || response.statusCode >= 300 {
                        print("⚠️ [\(deviceID)] HTTP hatası - Başarısız yanıt kodu: \(response.statusCode)")
                        return
                    }
                }
                
                guard let data = data, !data.isEmpty else {
                    print("❌ [\(deviceID)] Profil resmi verisi boş veya nil")
                    return
                }
                
                guard let image = UIImage(data: data) else {
                    print("❌ [\(deviceID)] Veriler geçerli bir görüntü değil: \(data.count) byte")
                    return
                }
                
                // Görüntü ve veri kontrolleri
                let imageSize = image.size
                let dataHash = data.hashValue
                print("✅ [\(deviceID)] Profil resmi başarıyla indirildi: \(data.count) byte, Boyut: \(imageSize.width)x\(imageSize.height), Hash: \(dataHash)")
                
                DispatchQueue.main.async {
                    // Önceki resmi kaydet (sorun olursa geri dönmek için)
                    let previousImageData = user.profileImage
                    
                    // CoreData'ya profil resmini kaydet
                    user.profileImage = data
                    user.photoURL = urlString // URL'yi her zaman güncelle
                    
                    do {
                        try self.container.viewContext.save()
                        
                        // Veri tabanını senkronize et
                        self.container.viewContext.refreshAllObjects()
                        
                        print("✅ [\(deviceID)] Profil resmi yerel veritabanına kaydedildi: \(dataHash)")
                        
                        // UI güncellemesi için bildirimler
                        NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
                        
                        // Kullanıcı giriş bildirimini de gönder
                        NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                        
                        // UserDefaults'a da güncelleme zamanını kaydet (isteğe bağlı)
                        if let uid = user.firebaseUID {
                            UserDefaults.standard.set(Date(), forKey: "LastProfileImageUpdate_\(uid)")
                            UserDefaults.standard.synchronize() // Hemen senkronize et
                        }
                    } catch {
                        print("❌ [\(deviceID)] Profil resmi yerel olarak kaydedilemedi: \(error.localizedDescription)")
                        // Eski resmi geri yükle
                        user.profileImage = previousImageData
                        try? self.container.viewContext.save()
                    }
                }
            }
            
            task.resume()
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
                if let user = users.first, let email = user.email, !email.isEmpty {
                    return email
                }
            } catch {
                print("❌ Kullanıcı e-postası aranırken hata: \(error.localizedDescription)")
            }
            
            // E-posta bulunamadıysa, doğrudan kullanıcı adını döndür
            // Bu Firebase'de e-posta formatı kontrolünde başarısız olabilir, ama loginUser
            // fonksiyonunda önce yerel giriş denediğimiz için sorun olmayacak
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
        
        // Tamamlanmış oyunu kaydet - istatistikler için Firebase'e kaydet, ancak kayıtlı oyunlardan sil
        func saveCompletedGame(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, errorCount: Int, hintCount: Int) {
            logInfo("Tamamlanmış oyun kaydediliyor ve kaldırılıyor, ID: \(gameID)")
            
            // Önce Firebase'e tamamlanmış olarak kaydet (istatistikler için)
            let flatBoard = board.flatMap { $0 }
            let userID = Auth.auth().currentUser?.uid ?? "guest"
            
            // Firestore'da kayıt için doküman oluştur - UUID'yi uppercase olarak standardize et
            let documentID = gameID.uuidString.uppercased()
            let gameRef = db.collection("savedGames").document(documentID)
            
            // Tamamlanmış oyun verisi - daha kapsamlı veri yapısı
            // Tüm tekrarlanan anahtarları temizleyerek yeni bir sözlük oluşturuyoruz
            let gameData: [String: Any] = [
                "userID": userID,
                "difficulty": difficulty,
                "elapsedTime": elapsedTime,
                "dateCreated": FieldValue.serverTimestamp(),
                "timestamp": FieldValue.serverTimestamp(),
                "size": board.count,
                "isCompleted": true,
                "errorCount": errorCount,
                "hintCount": hintCount,
                "board": flatBoard,
                "boardSize": 9,
                "dateCompleted": Date().timeIntervalSince1970
            ]
            
            // Önce mevcut belgeyi kontrol edelim - varsa silip tekrar oluşturacağız
            gameRef.getDocument { [weak self] (document, error) in
                guard let self = self else { return }
                
                // 1. Silinen oyunları takip listesine ekle (Senkronizasyon için)
                let deletedGamesKey = "recentlyDeletedGameIDs"
                var recentlyDeletedIDs = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
                
                // Oyun ID'sini standardize et ve eğer listede yoksa ekle
                if !recentlyDeletedIDs.contains(documentID) {
                    recentlyDeletedIDs.append(documentID)
                    UserDefaults.standard.set(recentlyDeletedIDs, forKey: deletedGamesKey)
                    
                    // Silme zamanını da kaydet
                    let deletedTimestampsKey = "deletedGameTimestamps"
                    var deletedTimestamps = UserDefaults.standard.dictionary(forKey: deletedTimestampsKey) as? [String: Double] ?? [:]
                    deletedTimestamps[documentID] = Date().timeIntervalSince1970
                    UserDefaults.standard.set(deletedTimestamps, forKey: deletedTimestampsKey)
                    
                    print("📝 Tamamlanan oyun ID \(documentID) silinen oyunlar listesine eklendi")
                }
                
                // 2. Firestore'da kayıtlı belge varsa önce silelim
                if let document = document, document.exists {
                    gameRef.delete { [weak self] deleteError in
                        guard let self = self else { return }
                        
                        if let deleteError = deleteError {
                            print("⚠️ Tamamlanmış oyun kaydedilmeden önce silinemedi: \(deleteError.localizedDescription)")
                        } else {
                            print("✅ Tamamlanmış oyun kaydedilmeden önce başarıyla silindi: \(documentID)")
                        }
                        
                        // Silme işleminden sonra yeni veriyi kaydet
                        self.saveCompletedGameData(gameRef: gameRef, gameData: gameData, documentID: documentID, gameID: gameID)
                    }
                } else {
                    // Doğrudan kaydet - silmeye gerek yok
                    self.saveCompletedGameData(gameRef: gameRef, gameData: gameData, documentID: documentID, gameID: gameID)
                }
            }
        }
        
        // Tamamlanmış oyun verilerini kaydetme yardımcı fonksiyonu
        private func saveCompletedGameData(gameRef: DocumentReference, gameData: [String: Any], documentID: String, gameID: UUID) {
            // Firestore'a kaydet
            gameRef.setData(gameData) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Tamamlanmış oyun Firestore'a kaydedilemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Tamamlanmış oyun Firestore'a kaydedildi: \(documentID)")
                    
                    // Firebase'e kayıt başarılı olduğunda Core Data'dan sil
                    DispatchQueue.main.async {
                        // Core Data'dan silme işlemini gerçekleştir
                        self.deleteSavedGameFromCoreData(gameID: documentID)
                        
                        // UI güncellemelerini daha tutarlı hale getirmek için
                        // tüm bildirimleri tek bir yerde toplayalım
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // İstatistikleri güncelle
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshStatistics"), object: nil)
                            
                            // Oyun listesini güncelle - daha uzun bir gecikme ile
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("📣 Tamamlanmış oyun kaydedildi, UI güncelleme bildirimi gönderiliyor")
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                            }
                        }
                    }
                }
            }
        }
        
        // CoreData'dan oyunu sil - UUID formatını düzgün şekilde işle
        func deleteSavedGameFromCoreData(gameID: String) {
            let context = container.viewContext
            
            print("🔄 Core Data'dan oyun siliniyor, ID: \(gameID)")
            
            // ID'yi normalize et - büyük/küçük harf ve UUID formatı sorunlarını ele al
            var normalizedUUID: UUID?
            
            // Doğrudan verilen ID'yi dene
            if let uuid = UUID(uuidString: gameID) {
                normalizedUUID = uuid
            }
            // Büyük harfe çevirip dene
            else if let uuid = UUID(uuidString: gameID.uppercased()) {
                normalizedUUID = uuid
            }
            // Küçük harfe çevirip dene
            else if let uuid = UUID(uuidString: gameID.lowercased()) {
                normalizedUUID = uuid
            }
            
            // Geçerli bir UUID elde edemedik
            if normalizedUUID == nil {
                print("❌ Geçersiz UUID formatı: \(gameID)")
                return
            }
            
            // ID'ye göre oyunu bul
            let request: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", normalizedUUID! as CVarArg)
            
            do {
                let games = try context.fetch(request)
                
                if let existingGame = games.first {
                    // Oyunu Core Data'dan sil
                    context.delete(existingGame)
                    try context.save()
                    print("✅ ID'si \(gameID) olan oyun başarıyla Core Data'dan silindi")
                } else {
                    print("ℹ️ Silinecek oyun Core Data'da bulunamadı, ID: \(gameID)")
                }
            } catch {
                print("❌ Core Data'dan oyun silinirken hata: \(error.localizedDescription)")
            }
        }
        
        // MARK: - Completed Games Management
        
        // Tüm tamamlanmış oyunları sil
        func deleteAllCompletedGames() {
            // Kullanıcı kontrolü: giriş yapmışsa
            guard let userID = Auth.auth().currentUser?.uid else {
                print("⚠️ Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
                return
            }
            
            print("🔄 Tüm tamamlanmış oyunları silme işlemi başlatılıyor... Kullanıcı ID: \(userID)")
            
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
            
            // 1. Önce kullanıcıya ait tüm tamamlanmış oyunları getirelim
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
                    
                    // 2. Silinen oyunları takip için ID'leri kaydet
                    let deletedGamesKey = "recentlyDeletedGameIDs"
                    var recentlyDeletedIDs = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
                    let deletedTimestampsKey = "deletedGameTimestamps"
                    var deletedTimestamps = UserDefaults.standard.dictionary(forKey: deletedTimestampsKey) as? [String: Double] ?? [:]
                    let currentTimestamp = Date().timeIntervalSince1970
                    
                    for document in documents {
                        let documentID = document.documentID
                        if !recentlyDeletedIDs.contains(documentID) {
                            recentlyDeletedIDs.append(documentID)
                            deletedTimestamps[documentID] = currentTimestamp
                        }
                    }
                    
                    // Güncellenmiş silinen ID'leri kaydet
                    UserDefaults.standard.set(recentlyDeletedIDs, forKey: deletedGamesKey)
                    UserDefaults.standard.set(deletedTimestamps, forKey: deletedTimestampsKey)
                    
                    // 3. Tamamlanmış oyunları toplu olarak sil
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
                            
                            // 4. Silme işlemini doğrula
                            self.verifyCompletedGameDeletion(of: documents.map { $0.documentID })
                            
                            // 5. UI güncellemesi için bildirim gönder
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshStatistics"), object: nil)
                                
                                // Oyun listesi güncellemesini geciktir
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                                }
                            }
                        }
                    }
                }
        }
        
        // Tamamlanmış oyunları senkronize et
        func syncCompletedGamesFromFirestore(completion: @escaping (Bool) -> Void) {
            guard let userID = Auth.auth().currentUser?.uid else {
                print("⚠️ Tamamlanmış oyunlar senkronize edilemedi: Kullanıcı giriş yapmamış")
                completion(false)
                return
            }
            
            print("🔄 Tamamlanmış oyunlar Firestore'dan senkronize ediliyor...")
            
            // Silinen oyunlar listesini al
            let deletedGamesKey = "recentlyDeletedGameIDs"
            let recentlyDeletedIDs = UserDefaults.standard.stringArray(forKey: deletedGamesKey) ?? []
            
            // Kullanıcının tamamlanmış oyunlarını getir
            db.collection("savedGames")
                .whereField("userID", isEqualTo: userID)
                .whereField("isCompleted", isEqualTo: true)
                .getDocuments { snapshot, error in
                    // Eğer hata varsa erken çık
                    if let error = error {
                        print("❌ Firestore tamamlanmış oyun sorgulama hatası: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("ℹ️ Firestore'da tamamlanmış oyun bulunamadı")
                        completion(true)  // Başarılı, ama oyun yok
                        return
                    }
                    
                    if documents.isEmpty {
                        print("ℹ️ Firestore'da tamamlanmış oyun bulunamadı")
                        completion(true)  // Başarılı, ama oyun yok
                        return
                    }
                    
                    print("📊 Bulunan tamamlanmış oyun sayısı: \(documents.count)")
                    
                    // İstatistikler için veri hazırla
                    var stats: [String: Int] = [
                        "Easy": 0,
                        "Medium": 0,
                        "Hard": 0,
                        "Expert": 0,
                        "total": 0
                    ]
                    
                    var totalElapsedTime: TimeInterval = 0
                    var totalErrorCount: Int = 0
                    var totalHintCount: Int = 0
                    
                    // Her belge için istatistikleri güncelle
                    for document in documents {
                        let data = document.data()
                        let documentID = document.documentID
                        
                        // Eğer bu oyun silinmiş listesindeyse, atla
                        if recentlyDeletedIDs.contains(documentID) ||
                            recentlyDeletedIDs.contains(documentID.uppercased()) ||
                            recentlyDeletedIDs.contains(documentID.lowercased()) {
                            print("⏭️ ID: \(documentID) olan tamamlanmış oyun yakın zamanda silinmiş. Atlanıyor.")
                            continue
                        }
                        
                        // İstatistikleri güncelle
                        if let difficulty = data["difficulty"] as? String {
                            stats[difficulty] = (stats[difficulty] ?? 0) + 1
                            stats["total"] = (stats["total"] ?? 0) + 1
                        }
                        
                        if let elapsedTime = data["elapsedTime"] as? TimeInterval {
                            totalElapsedTime += elapsedTime
                        }
                        
                        if let errorCount = data["errorCount"] as? Int {
                            totalErrorCount += errorCount
                        }
                        
                        if let hintCount = data["hintCount"] as? Int {
                            totalHintCount += hintCount
                        }
                    }
                    
                    // İstatistikleri kaydet
                    let userDefaults = UserDefaults.standard
                    userDefaults.set(stats, forKey: "CompletedGameStats")
                    userDefaults.set(totalElapsedTime, forKey: "TotalGameTime")
                    userDefaults.set(totalErrorCount, forKey: "TotalErrorCount")
                    userDefaults.set(totalHintCount, forKey: "TotalHintCount")
                    
                    print("✅ Tamamlanmış oyun istatistikleri güncellendi: \(stats)")
                    
                    // UI güncellemesi için bildirim gönder
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshStatistics"), object: nil)
                    }
                    
                    completion(true)
                }
        }
        
        // Tamamlanmış oyunların silinmesini doğrula
        private func verifyCompletedGameDeletion(of documentIDs: [String]) {
            // Eğer silinecek belge yoksa doğrudan çık
            if documentIDs.isEmpty {
                print("ℹ️ Doğrulanacak silinen belge yok")
                return
            }
            
            // Firestore referansını yerel bir değişkene kaydedelim
            let firestore = db
            let group = DispatchGroup()
            var failedDeletions: [String] = []
            
            for documentID in documentIDs {
                group.enter()
                
                firestore.collection("savedGames").document(documentID).getDocument { document, error in
                    defer { group.leave() }
                    
                    if let document = document, document.exists {
                        failedDeletions.append(documentID)
                        print("⚠️ Tamamlanmış oyun hala mevcut: \(documentID)")
                    } else {
                        print("✅ Tamamlanmış oyun başarıyla silindi: \(documentID)")
                    }
                }
            }
            
            // self'i closure içinde kullanmadan ikinci try işlemini tanımlayalım
            func retryDeletingGames(_ gamesIDs: [String], using firestoreDB: Firestore) {
                print("🔄 \(gamesIDs.count) adet silinemeyen oyunu tekrar silmeyi deniyorum...")
                
                let batch = firestoreDB.batch()
                for gameID in gamesIDs {
                    let gameRef = firestoreDB.collection("savedGames").document(gameID)
                    batch.deleteDocument(gameRef)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ İkinci silme denemesi başarısız: \(error.localizedDescription)")
                    } else {
                        print("✅ İkinci silme denemesi başarılı!")
                    }
                }
            }
            
            // Hiç self kullanmadan işlemleri tamamlayalım
            group.notify(queue: .main) {
                if failedDeletions.isEmpty {
                    print("✅ Tüm tamamlanmış oyunlar başarıyla silindi!")
                } else {
                    print("⚠️ \(failedDeletions.count) tamamlanmış oyun silinemedi: \(failedDeletions)")
                    
                    // Başarısız olanları tekrar silmeyi dene
                    if !failedDeletions.isEmpty {
                        retryDeletingGames(failedDeletions, using: firestore)
                    }
                }
            }
        }
    }

