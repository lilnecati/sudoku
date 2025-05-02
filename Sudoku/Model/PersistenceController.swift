import CoreData
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Network // NetworkMonitor için eklendi
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
            logSuccess("Firebase Auth configured from PersistenceController (lazy)")
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
                logError("CoreData yüklenemedi: \(error.localizedDescription)")
            } else {
                logInfo("CoreData yüklendi, Firebase dinleyicileri kullanıcı giriş yaptığında başlatılacak.") // Log mesajı güncellendi
                // CoreData yüklendikten hemen sonra Firebase dinleyicilerini başlatma
                // Bunun yerine UserLoggedIn bildirimini bekleyeceğiz.
                // DispatchQueue.main.async { [weak self] in
                //     self?.setupDeletedGamesListener()
                // }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // NotificationCenter'dan gelen oturum açma/çıkma ve ağ durumu bildirimlerini dinle
        setupNotificationObservers() // Bu fonksiyon zaten var, içine ekleme yapacağız
    } // <<< PASTE THE BLOCK HERE, AFTER THIS CLOSING BRACE
    
    // MARK: - Pending Operations Processing (MOVED HERE - CLASS SCOPE)
    
    // Bekleyen Firebase işlemlerini işle
    private func processPendingOperations() {
        // Ağ bağlantısı gerçekten var mı diye bir daha kontrol et
        guard NetworkMonitor.shared.isConnected else { 
            logInfo("Bekleyen işlemler işlenemiyor: Ağ bağlantısı yok.")
            return
        }
        
        // <<< KALDIRILDI: Artık canlı kullanıcı kontrolü burada yapılmayacak. >>>
        // guard let currentUserID = Auth.auth().currentUser?.uid else {
        //     logInfo("Bekleyen işlemler işlenemiyor: Kullanıcı giriş yapmamış.")
        //     return
        // }
        
        let context = container.newBackgroundContext() // Arka planda çalıştır
        context.perform { [weak self] in
            guard let self = self else { return }
            
            let fetchRequest: NSFetchRequest<PendingFirebaseOperation> = PendingFirebaseOperation.fetchRequest()
            // En eski işlemden başla (isteğe bağlı)
            // Explicitly specify root type for key path
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PendingFirebaseOperation.timestamp, ascending: true)]
            
            do {
                let pendingOperations = try context.fetch(fetchRequest)
                if pendingOperations.isEmpty {
                    return
                }
                
                logInfo("İşlenecek \(pendingOperations.count) adet bekleyen Firebase işlemi bulundu.")
                
                for operation in pendingOperations {
                    guard let action = operation.action,
                          let opDataType = operation.dataType,
                          let opDataID = operation.dataID else {

                        logError("Bekleyen işlemde eksik bilgi var, siliniyor: operationID=\(operation.operationID?.uuidString ?? "ID Yok")")
                        context.delete(operation)
                        continue
                    }
                    
                    // <<< YENİ: İşleme ait kaydedilmiş userID'yi kullan >>>
                    // Eğer userID nil ise, misafir işlemi olarak kabul edilebilir veya hata verilebilir.
                    // Şimdilik nil ise "guest" kullanalım.
                    let operationUserID = operation.userID ?? "guest"
                    // <<< YENİ LOG >>>
                    logDebug("Processing Operation: UserID read from CoreData: \(operation.userID ?? "nil"), Effective UserID: \(operationUserID)")
                    
                    logInfo("İşleniyor: \(action) - \(opDataType) - \(opDataID) - User: \(operationUserID)")
                    
                    operation.attemptCount += 1
                    operation.lastAttemptTimestamp = Date()
                    
                    switch action {
                    case "update", "create":
                        guard let opPayload = operation.payload else {
                            logError("Update işlemi için payload eksik, siliniyor: \(opDataID)")
                            context.delete(operation)
                            continue
                        }
                        // <<< YENİ: operationUserID'yi kullan >>>
                        self.performFirestoreUpdate(userID: operationUserID, dataType: opDataType, dataID: opDataID, payload: opPayload) { success in
                            context.perform {
                                if success {
                                    logSuccess("Bekleyen \'update\' işlemi başarıyla tamamlandı ve silindi: \(opDataID)")
                                    context.delete(operation)
                                    self.saveBackgroundContext(context)
                                } else {
                                    logError("Bekleyen \'update\' işlemi başarısız oldu (kalıcı hata veya deneme limiti?): \(opDataID)")
                                    // İŞLEM SİLME DÜZELTME - Kritik işlemler için daha uzun deneme sayısı
                                    if operation.attemptCount >= 5 {
                                        // Veri türüne göre özel işlem yap
                                        let isKritikVeri = opDataType == "achievement" || opDataType == "highScore"
                                        
                                        if isKritikVeri {
                                            logWarning("KRİTİK VERİ: 5 deneme başarısız oldu, ama silmiyoruz: \(opDataType) - \(opDataID)")
                                            // İşlem sayacını sıfırla, tekrar denenecek
                                            operation.attemptCount = 1
                                            self.saveBackgroundContext(context)
                                            
                                            // Kullanıcıya bildirim gönder
                                            DispatchQueue.main.async {
                                                NotificationCenter.default.post(
                                                    name: NSNotification.Name("CriticalOperationFailure"),
                                                    object: nil, 
                                                    userInfo: ["dataType": opDataType, "dataID": opDataID]
                                                )
                                            }
                                        } else {
                                            logError("Kritik olmayan veri, maksimum deneme sayısına ulaşıldı, işlem siliniyor: \(opDataID)")
                                        context.delete(operation)
                                        self.saveBackgroundContext(context)
                                        }
                                    } else {
                                        self.saveBackgroundContext(context)
                                    }
                                }
                            }
                        }
                    case "delete":
                        // <<< YENİ: operationUserID'yi kullan >>>
                        self.performFirestoreDelete(userID: operationUserID, dataType: opDataType, dataID: opDataID) { success in
                            context.perform {
                                if success {
                                    logSuccess("Bekleyen \'delete\' işlemi başarıyla tamamlandı ve silindi: \(opDataID)")
                                    context.delete(operation)
                                    self.saveBackgroundContext(context)
                                } else {
                                    logError("Bekleyen \'delete\' işlemi başarısız oldu (kalıcı hata veya deneme limiti?): \(opDataID)")
                                    // İŞLEM SİLME DÜZELTME - Kritik işlemler için daha uzun deneme sayısı
                                    if operation.attemptCount >= 5 {
                                        // Silme işlemleri için kritik veri kontrolü
                                        // Başarım silme işlemi olmadığı için bu kısım daha basit kalabilir
                                        logError("Maksimum deneme sayısına ulaşıldı, işlem siliniyor: \(opDataID)")
                                        context.delete(operation)
                                        self.saveBackgroundContext(context)
                                    } else {
                                        self.saveBackgroundContext(context)
                                    }
                                }
                            }
                        }
                    default:
                        logError("Bilinmeyen işlem türü, siliniyor: \(action) - \(opDataID)")
                        context.delete(operation)
                        self.saveBackgroundContext(context)
                    }
                }
            } catch {
                logError("Bekleyen işlemler getirilirken hata oluştu: \(error)")
            }
        }
    }
    
    // Firestore'a güncelleme/oluşturma işlemi yap
    private func performFirestoreUpdate(userID: String, dataType: String, dataID: String, payload: Data, completion: @escaping (Bool) -> Void) {
        // <<< YENİ LOG >>>
        logDebug("Performing Firestore Update: Received UserID Param: \(userID)") 
        guard let collectionPath = collectionPath(for: dataType, userID: userID) else {
            logError("Geçersiz dataType for update: \\(dataType)")
            completion(false)
            return
        }
        let docRef = db.collection(collectionPath).document(dataID)
        do {
            guard var dataDict = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
                logError("Payload JSON formatına çevrilemedi: \\(dataID)")
                completion(false)
                return
            }
            dataDict["lastUpdated"] = FieldValue.serverTimestamp()
            // <<< DEĞİŞİKLİK: Payload'daki userID'ye bakma, her zaman fonksiyona gelen userID'yi kullan >>>
            dataDict["userID"] = userID 
            // <<< YENİ LOG >>>
            logDebug("Performing Firestore Update: Final UserID in dataDict: \(dataDict["userID"] ?? "nil") for path: \(collectionPath)") 
            // if dataDict["userID"] == nil { // Eski kontrol kaldırıldı
            //     dataDict["userID"] = userID
            // }
            docRef.setData(dataDict, merge: true) { error in
                if let error = error {
                    logError("Firestore update/setData hatası (\(dataID)): \(error.localizedDescription)")
                    // Change conditional cast to direct cast since it always succeeds
                    let nsError = error as NSError
                    if nsError.domain == FirestoreErrorDomain &&
                        (nsError.code == FirestoreErrorCode.unavailable.rawValue ||
                         nsError.code == FirestoreErrorCode.deadlineExceeded.rawValue ||
                         nsError.code == FirestoreErrorCode.internal.rawValue ||
                         nsError.code == FirestoreErrorCode.unknown.rawValue) {
                        completion(false)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(true)
                }
            }
        } catch {
            logError("Payload JSON\'a çevrilirken hata: \(error) - \(dataID)")
            completion(false)
        }
    }
    
    // Firestore'dan silme işlemi yap
    private func performFirestoreDelete(userID: String, dataType: String, dataID: String, completion: @escaping (Bool) -> Void) {
        guard let collectionPath = collectionPath(for: dataType, userID: userID) else {
            logError("Geçersiz dataType for delete: \(dataType)")
            completion(true)
            return
        }
        let docRef = db.collection(collectionPath).document(dataID)
        docRef.delete { error in
            if let error = error {
                logError("Firestore delete hatası (\(dataID)): \(error.localizedDescription)")
                // Change conditional cast to direct cast since it always succeeds
                let nsError = error as NSError
                if nsError.domain == FirestoreErrorDomain &&
                    (nsError.code == FirestoreErrorCode.unavailable.rawValue ||
                     nsError.code == FirestoreErrorCode.deadlineExceeded.rawValue ||
                     nsError.code == FirestoreErrorCode.internal.rawValue ||
                     nsError.code == FirestoreErrorCode.unknown.rawValue) {
                    completion(false)
                } else if nsError.code == FirestoreErrorCode.notFound.rawValue {
                    logWarning("Silinecek belge zaten Firestore\'da bulunamadı (\(dataID)), işlem başarılı sayılıyor.")
                    completion(true)
                } else {
                    completion(false)
                }
            } else {
                completion(true)
            }
        }
    }
    
    // Veri tipine göre Firestore koleksiyon yolunu döndüren yardımcı fonksiyon
    private func collectionPath(for dataType: String, userID: String) -> String? {
        switch dataType {
        case "savedGame":
            return "userGames/\(userID)/savedGames"
        case "highScore":
            logWarning("highScore için koleksiyon yolu net değil, kontrol edilmeli.")
            return "highScores"
        case "completedGame":
            return "userGames/\(userID)/completedGames"
        default:
            return nil
        }
    }
    
    // Arka plan context'ini kaydetmek için yardımcı fonksiyon
    private func saveBackgroundContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else {
            return
        }
        do {
            try context.save()
            logInfo("Arka plan context kaydedildi.")
        } catch {
            let nsError = error as NSError
            logError("Arka plan context kaydetme hatası: \(nsError.localizedDescription). Kod: \(nsError.code), Domain: \(nsError.domain)")
        }
    }
    
 
    // Yeni Helper: Bekleyen işlemi kuyruğa ekle
    private func queuePendingOperation(action: String, dataType: String, dataID: String, payload: Data?) {
        logInfo("İşlem kuyruğa ekleniyor: \\(action) - \\(dataType) - \\(dataID)")
        let context = container.newBackgroundContext()
        // let currentUserID = Auth.auth().currentUser?.uid // <<< Eski yöntem kaldırıldı
        // logDebug("Queueing Operation: UserID from Auth to be saved: \\(currentUserID ?? \"nil\")") 
        
        // <<< DEĞİŞİKLİK: ID'yi CoreData'daki aktif kullanıcıdan al >>>
        let loggedInUser = PersistenceController.shared.getCurrentUser() // Kendi metodumuzu kullanalım
        let userIDToSave = loggedInUser?.firebaseUID // CoreData'daki firebaseUID'yi al
        logDebug("Queueing Operation: UserID from CoreData user to be saved: \(userIDToSave ?? "nil") (Username: \(loggedInUser?.username ?? "N/A"))")
        
        context.performAndWait { // Wait to ensure it's saved before proceeding
            let pendingOp = PendingFirebaseOperation(context: context)
            pendingOp.operationID = UUID()
            pendingOp.action = action
            pendingOp.dataType = dataType
            pendingOp.dataID = dataID
            pendingOp.userID = userIDToSave // <<< YENİ: CoreData'dan alınan ID'yi kaydet >>>
            pendingOp.payload = payload
            pendingOp.timestamp = Date()
            pendingOp.attemptCount = 0
            
            do {
                try context.save()
                // <<< YENİ LOG >>>
                logSuccess("Bekleyen işlem başarıyla kuyruğa eklendi: \(pendingOp.operationID?.uuidString ?? "ID Yok") - UserID Saved: \(userIDToSave ?? "nil")") 
            } catch {
                logError("Bekleyen işlem kuyruğa eklenirken hata: \\(error.localizedDescription)")
            }
        }
    }
    
    
    private func isFirestoreErrorTemporary(_ error: Error) -> Bool {
        let nsError = error as NSError
        let temporaryCodes: [Int] = [
            FirestoreErrorCode.unavailable.rawValue,
            FirestoreErrorCode.deadlineExceeded.rawValue,
            FirestoreErrorCode.internal.rawValue, // Often temporary
            FirestoreErrorCode.unknown.rawValue    // Can be temporary
        ]
        return nsError.domain == FirestoreErrorDomain && temporaryCodes.contains(nsError.code)
    }
    
    // MARK: - Firebase & Notification Listeners
    
    private func setupNotificationObservers() {
        // Kullanıcı giriş/çıkış bildirimlerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLoggedIn),
            name: Notification.Name("UserLoggedIn"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLoggedOut),
            name: Notification.Name("UserLoggedOut"),
            object: nil
        )
        
        // *** YENİ: Ağ bağlantısı bildirimini dinle ***
        // Remove comments for NetworkMonitor listener
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkConnected),
            name: NetworkMonitor.NetworkConnectedNotification, // Use actual notification name
            object: nil
        )
    }
    
    @objc private func handleUserLoggedIn() {
        logInfo("Kullanıcı giriş bildirimi alındı - Senkronizasyon ve bekleyen işlemler başlatılıyor")
        
        // Setup listeners first
        setupDeletedGamesListener()
        
        // Then sync data from Firestore
        syncSavedGamesFromFirestore { _ in
             logInfo("Kayıtlı oyunlar senkronizasyonu tamamlandı.")
             // Optionally trigger UI refresh if needed after sync
        }
        syncHighScoresFromFirestore { _ in 
            logInfo("Yüksek skorlar senkronizasyonu tamamlandı.")
            // Optionally trigger UI refresh if needed after sync
        }
        syncCompletedGamesFromFirestore { _ in 
             logInfo("Tamamlanmış oyun istatistikleri senkronizasyonu tamamlandı.")
             // Optionally trigger UI refresh if needed after sync
        }
        syncProfileImage { _ in
             logInfo("Profil resmi senkronizasyonu tamamlandı.")
             // Optionally trigger UI refresh if needed after sync
        }
        
        // Finally, process any pending operations
        processPendingOperations()
    }
    
    @objc private func handleUserLoggedOut() {
        logInfo("Kullanıcı çıkış bildirimi alındı - Firebase dinleyicileri durdurulacak")
        deletedGamesListener?.remove()
        deletedGamesListener = nil
        savedGamesListener?.remove()
        savedGamesListener = nil
        // Kullanıcı çıkış yaptığında bekleyen işlemleri işlemeye gerek yok
    }
    
    // *** YENİ: Ağ bağlantısı geldiğinde çağrılacak fonksiyon ***
    @objc private func handleNetworkConnected() {
        logInfo("Ağ bağlantısı bildirimi alındı - Bekleyen işlemler kontrol ediliyor")
        processPendingOperations() // Ensure this function is defined at class scope
    }
    
    // BASİTLEŞTİRİLMİŞ Silinen oyunlar dinleyicisi
    private func setupDeletedGamesListener() {
        // Önceki dinleyicileri temizle
        deletedGamesListener?.remove()
        
        if Auth.auth().currentUser == nil {
            logWarning("Silinen oyunlar dinleyicisi başlatılamadı: Kullanıcı oturum açmamış")
            return
        }
        
        logWarning("NÜKLEER ÇÖZÜM: Silinen oyunlar sistemi tamamen yeniden tasarlandı")
        logInfo("Tarih: \(Date().description)")
        
        // İlk kontrolü yap
        checkDeletedGamesManually()
        
        // Gerçek zamanlı dinleyiciyi başlat
        setupContinuousDeleteListener()
    }
    
    // Manuel kontrol - Silinen oyunlar tablosunda olup da yerel veritabanında hala mevcut olanları sil
    private func checkDeletedGamesManually() {
        guard Auth.auth().currentUser != nil else { return }
        
        logInfo("Silinen oyunlar tam taraması başlatılıyor...")
        
        // 1. Yerel oyunları al
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        do {
            let localGames = try context.fetch(fetchRequest)
            let localGameIDs = localGames.compactMap { $0.id?.uuidString.uppercased() }
            
            logInfo("Yerel oyun sayısı: \(localGameIDs.count)")
            
            if localGameIDs.isEmpty {
                logInfo("Yerel oyun bulunmadığı için silme kontrolüne gerek yok")
                return
            }
            
            // 2. Silinen oyunlar koleksiyonundaki TÜM kayıtları getir - her oyun için kontrol et
            db.collection("deletedGames").getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    logError("Silinen oyunlar getirilemedi: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    logInfo("Silinen oyun kaydı bulunamadı")
                    return
                }
                
                logInfo("Toplam \(documents.count) silinen oyun kaydı bulundu")
                var gamesToDelete = [UUID]()
                
                // Her silinen oyun için kontrol et
                for doc in documents {
                    guard let gameID = doc.data()["gameID"] as? String else { continue }
                    let upperGameID = gameID.uppercased()
                    
                    // Eğer bu oyun yerel veritabanımızda hala duruyorsa sil
                    if localGameIDs.contains(upperGameID), let uuid = UUID(uuidString: upperGameID) {
                        gamesToDelete.append(uuid)
                        logWarning("Silinen oyun bulundu: \(upperGameID) - yerel veritabanından silinecek")
                    }
                }
                
                // Tespit edilen oyunları sil
                if !gamesToDelete.isEmpty {
                    logInfo("\(gamesToDelete.count) oyun yerel veritabanından silinecek")
                    
                    for gameID in gamesToDelete {
                        DispatchQueue.main.async {
                            self.deleteLocalGameOnly(gameID: gameID)
                        }
                    }
                } else {
                    logSuccess("Silinecek oyun bulunamadı - yerel veritabanı güncel")
                }
            }
            
        } catch {
            logError("Yerel oyunlar getirilemedi: \(error.localizedDescription)")
        }
        
        // Üst kısımda eski işlem mantığı kalmıştı, kaldırıldı.
    }
    
    // YÜKSEK ÖNCELİKLİ ÇÖZÜM: SAVEDGAMES DİNLEYİCİSİ - HER ANİ VE TÜM DEĞİŞİKLİKLERİ DİNLER
    private func setupContinuousDeleteListener() {
        // Kullanıcı giriş yapmamışsa geri dön
        guard let currentUser = Auth.auth().currentUser else { return }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        
        logInfo("RADIKAL ÇÖZÜM: TÜM KAYDEDILMIŞ OYUNLARI GÖZETLEYEN SISTEM BAŞLATILIYOR!")
        logInfo("ARTIK SILINEN OYUNLAR KOLEKSIYONU KULLANILMIYOR!")
        logInfo("Cihaz: \(deviceID) | \(Date().description)")
        
        // SAVEDGAMES KOLEKSIYONUNU DOGRUDAN DINLE
        savedGamesListener = db.collection("savedGames")
            .whereField("userID", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    logError("Kaydedilmiş oyunlar dinleyicisi hatası! \(error.localizedDescription)")
                    return
                }
                
                logInfo("SavedGames değişiklik algılandı - \(Date().timeIntervalSince1970)")
                
                guard let snapshot = querySnapshot else { return }
                
                // Tüm silme olaylarını takip et
                var silinenOyunlar = [String]()
                
                for degisiklik in snapshot.documentChanges where degisiklik.type == .removed {
                    let silinmisOyunID = degisiklik.document.documentID.uppercased()
                    logWarning("SAVEDGAMES'DEN SİLİNEN OYUN ALGILANDI! ID: \(silinmisOyunID)")
                    silinenOyunlar.append(silinmisOyunID)
                }
                
                // Silinen oyunları yerel veritabanından da sil
                if !silinenOyunlar.isEmpty {
                    logInfo("\(silinenOyunlar.count) oyun Firebase'den silinmiş, yerel veritabanı güncelleniyor")
                    
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
                                    logInfo("Yerel veritabanından oyun siliniyor: \(silinmisOyunID)")
                                    context.delete(oyun)
                                    try context.save()
                                    logSuccess("Oyun yerel veritabanından silindi: \(silinmisOyunID)")
                                    
                                    // UI güncelleme bildirimi
                                    DispatchQueue.main.async {
                                        NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                                        logInfo("UI güncelleme bildirimi gönderildi")
                                    }
                                }
                            } catch {
                                logError("Yerel veritabanından silme hatası: \(error.localizedDescription)")
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
                            logInfo("Firebase'de bulunmayan yerel oyun tespit edildi: \(oyunID)")
                            
                            // Firebase'de yoksa yerel veritabanından sil
                            self.container.viewContext.delete(oyun)
                            try self.container.viewContext.save()
                            logSuccess("Firebase'de olmayan oyun yerel veritabanından silindi: \(oyunID)")
                            
                            // UI güncelleme bildirimi
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                            }
                        }
                    }
                } catch {
                    logError("Yerel-Firebase senkronizasyon hatası: \(error.localizedDescription)")
                }
            }
        
        logSuccess("SAVEDGAMES KOLEKSIYONU DİNLEYİCİSİ AKTİF - TÜM SİLME İŞLEMLERİ ALGILANACAK")
    }
    
    
    // Tam senkronizasyon kontrolü - tüm yerel oyunların ve buluttaki oyunların eşleştiğinden emin ol
    private func performFullSyncCheck() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        logInfo("Tam senkronizasyon kontrolü başlatılıyor...")
        
        // 1. Önce Firebase'de olan tüm oyunları getir
        db.collection("savedGames")
            .whereField("userID", isEqualTo: currentUser.uid)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    logError("Firebase oyunları getirme hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    logError("Firebase oyunları getirilemedi")
                    return
                }
                
                // Firebase'deki tüm oyun ID'lerini al
                let firebaseGameIDs = Set(documents.compactMap { doc -> UUID? in
                    if let idString = doc.documentID as String?, let uuid = UUID(uuidString: idString) {
                        return uuid
                    }
                    return nil
                })
                
                logInfo("Firebase'de \(firebaseGameIDs.count) kayıtlı oyun bulundu")
                
                // 2. Tüm yerel oyunları getir
                let context = self.container.viewContext
                let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
                
                do {
                    let localGames = try context.fetch(fetchRequest)
                    let localGameIDs = Set(localGames.compactMap { $0.id })
                    
                    logInfo("Yerel veritabanında \(localGameIDs.count) kayıtlı oyun bulundu")
                    
                    // 3. Yerel olup Firebase'de olmayan oyunları yedekle
                    let localOnlyGames = localGameIDs.subtracting(firebaseGameIDs)
                    if !localOnlyGames.isEmpty {
                        logInfo("\(localOnlyGames.count) oyun yalnızca yerel olarak bulundu, Firebase'e yedeklenecek")
                        // Bu oyunları Firebase'e yedekle (ileride)
                    }
                    
                    // 4. Firebase'de olup yerel olarak olmayan oyunları indir
                    let firebaseOnlyGames = firebaseGameIDs.subtracting(localGameIDs)
                    if !firebaseOnlyGames.isEmpty {
                        logInfo("\(firebaseOnlyGames.count) oyun yalnızca Firebase'de bulundu, yerel olarak eklenecek")
                        // Bu oyunları ileride indirebiliriz
                    }
                    
                } catch {
                    logError("Yerel oyunları getirme hatası: \(error.localizedDescription)")
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
                logError("Bu kullanıcı adı zaten kullanılıyor: \(username)")
                return false
            }
            
            // E-posta kontrolü
            if try context.count(for: emailCheck) > 0 {
                logError("Bu e-posta zaten kullanılıyor: \(email)")
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
            logSuccess("Kullanıcı başarıyla oluşturuldu: \(username)")
            return true
        } catch {
            logError("Kullanıcı kaydı başarısız: \(error.localizedDescription)")
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
                        logSuccess("Kullanıcı girişi başarılı: \(username)")
                        return user
                    } else {
                        logError("Şifre yanlış: \(username)")
                        return nil
                    }
                } else {
                    // Eski kullanıcılar için geriye dönük uyumluluk (salt olmadan doğrudan şifre karşılaştırma)
                    if user.password == password {
                        // Başarılı giriş - eski kullanıcı
                        logWarning("Eski format kullanıcı girişi - güvenlik güncellemesi uygulanıyor")
                        
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
            
            logError("Kullanıcı bulunamadı: \(username)")
            return nil
        } catch {
            logError("Giriş başarısız: \(error.localizedDescription)")
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
            logError("Kullanıcı bulunamadı: \(error)")
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
                    logWarning("Firestore çıkış bilgisi güncellenemedi: \(error.localizedDescription)")
                } else {
                    logSuccess("Firestore çıkış bilgisi güncellendi")
                }
            }
            
            // Firebase Authentication'dan çıkış yap
            do {
                try Auth.auth().signOut()
                logSuccess("Firebase Auth'dan çıkış yapıldı")
            } catch {
                logError("Firebase Auth çıkış hatası: \(error.localizedDescription)")
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
            logError("Kullanıcı bilgisi alınamadı: \(error)")
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
            logError("Kayıtlı oyunlar getirilemedi: \(error)")
            return []
        }
    }
    
    // Benzersiz ID ile yeni bir oyun kaydet
    func saveGame(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        // <<< YENİ LOG >>>
        logDebug("PersistenceController.saveGame called. GameID: \(gameID), Offline: \(!NetworkMonitor.shared.isConnected)")
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
            logError("Oyun kaydedilemedi: \(error)")
        }
    }
    
    // Firestore'a oyun kaydetme - Updated for Offline Support
    func saveGameToFirestore(gameID: UUID, board: [[Int]], difficulty: String, elapsedTime: TimeInterval, jsonData: Data? = nil) {
        // <<< YENİ LOG >>>
        logDebug("PersistenceController.saveGameToFirestore called. GameID: \(gameID), Offline: \(!NetworkMonitor.shared.isConnected)")
        // Kullanıcı kimliğini al - giriş yapmış kullanıcı veya misafir
        let userID = Auth.auth().currentUser?.uid ?? "guest"
        let documentID = gameID.uuidString.uppercased()
        let collectionPath = "userGames/\(userID)/savedGames"

        // Prepare data for Firestore write (including timestamps)
        let flatBoard = board.flatMap { $0 }
        let isCompleted = !flatBoard.contains(0)
        var firestoreData: [String: Any] = [ // Firestore'a gidecek veri
            "userID": userID,
            "difficulty": difficulty,
            "elapsedTime": elapsedTime,
            "dateCreated": FieldValue.serverTimestamp(), // Timestamp burada
            "board": flatBoard, // Düzleştirilmiş tahta
            "size": board.count,
            "isCompleted": isCompleted,
            "lastUpdated": FieldValue.serverTimestamp() // Timestamp burada
        ]
        // Optionally add detailed board state from jsonData if available
        if let jsonData = jsonData {
             // Attempt to decode jsonData and add relevant parts to firestoreData
             // Example: Add 'userEnteredValues', 'stats' etc. if they exist in jsonData
             if let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                 // ---> DÜZELTME BURADA <---
                 if let userValuesNested = jsonDict["userEnteredValues"] as? [[Bool]] { // userValues [[Bool]] tipinde
                    // [[Bool]] dizisini [Bool] dizisine düzleştir
                    let userValuesFlat = userValuesNested.flatMap { $0 }
                    firestoreData["userEnteredValuesFlat"] = userValuesFlat // Düzleştirilmiş halini kaydet
                    logDebug("userEnteredValues düzleştirildi ve firestoreData'ya eklendi.")
                 } else {
                    logWarning("jsonData içinden userEnteredValues [[Bool]] olarak okunamadı.")
                 }
                 // ---> Düzeltme Sonu <---
                 if let stats = jsonDict["stats"] { firestoreData["stats"] = stats }
                 // Add other fields from jsonData as needed, ensure they are Firestore compatible
                 // Be careful not to add complex nested objects that might cause issues later
                 // For example, pencil marks might need specific handling/serialization if added
             }
        }


        // Prepare data for Offline Payload (NO timestamps)
        var payloadData = firestoreData // Start with a copy
        payloadData.removeValue(forKey: "dateCreated") // Remove timestamp
        payloadData.removeValue(forKey: "lastUpdated") // Remove timestamp
        // NOTE: Ensure the nested userEnteredValues is removed from payloadData
        payloadData.removeValue(forKey: "userEnteredValues") // Explicitly remove nested version if present
        // Ensure other non-serializable Firebase types are also removed if added later

        var payload: Data?
        do {
            // ---> Şimdi payloadData'yı (timestampsız) JSON'a çeviriyoruz <---
            payload = try JSONSerialization.data(withJSONObject: payloadData, options: [])
            logDebug("Offline payload oluşturuldu, boyut: \(payload?.count ?? 0) byte")
        } catch {
             logError("Oyun verisi payload için serileştirilemedi: \(error)")
             // Handle error - maybe proceed without payload or fail queueing?
             // For now, we'll continue, but offline queueing might fail later if payload is nil
        }

        // Check network status (Requires NetworkMonitor)
        // <<< YENİ LOG >>>
        let userIDForOfflineCheck = Auth.auth().currentUser?.uid ?? "guest"
        logDebug("Offline Save Check: UserID before queueing: \(userIDForOfflineCheck)") 
        
        guard NetworkMonitor.shared.isConnected else {
            logWarning("Çevrimdışı: Oyun kaydetme işlemi kuyruğa alınıyor: \(documentID)")
            // ---> payload (timestampsız JSON) kuyruğa ekleniyor <---
            queuePendingOperation(action: "create", dataType: "savedGame", dataID: documentID, payload: payload)
                return
            }
            
        // Attempt Firestore operation
        let gameRef = db.collection(collectionPath).document(documentID)

        // Ensure userGames/[userID] doc exists (optional, but good practice)
        db.collection("userGames").document(userID).setData(["lastActivity": FieldValue.serverTimestamp()], merge: true)

        // ---> Firestore'a firestoreData (timestamp içeren) yazılıyor <---
        gameRef.setData(firestoreData, merge: true) { [weak self] error in
            if let error = error {
                logError("Firestore oyun kaydı/güncelleme hatası: \(error.localizedDescription) - ID: \(documentID)")
                // Check if error is temporary and queue if needed
                if self?.isFirestoreErrorTemporary(error) ?? false {
                    logWarning("Geçici hata: Oyun kaydetme işlemi kuyruğa alınıyor: \(documentID)")
                    // ---> Hata durumunda da timestampsız payload kuyruğa ekleniyor <---
                    self?.queuePendingOperation(action: "create", dataType: "savedGame", dataID: documentID, payload: payload)
            } else {
                    // Handle persistent error (e.g., log, inform user)
                    logError("Kalıcı Firestore hatası, işlem kuyruğa alınmadı: \(documentID)")
                }
            } else {
                logSuccess("Oyun Firebase Firestore'a kaydedildi/güncellendi: \(documentID)")
                if isCompleted {
                    logSuccess("Oyun tamamlandı olarak işaretlendi!") // This log might be misleading if called from updateSavedGame
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
                logWarning("Güncellenecek oyun bulunamadı, ID: \(gameID). Yeni oyun olarak kaydediliyor.")
                // Oyun bulunamadıysa yeni oluştur
                saveGame(gameID: gameID, board: board, difficulty: difficulty, elapsedTime: elapsedTime)
            }
        } catch {
            logError("Oyun güncellenemedi: \(error)")
        }
    }
    
    // Kayıtlı oyunları senkronize et
    func syncSavedGamesFromFirestore(completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            logWarning("Oyunlar senkronize edilemedi: Kullanıcı giriş yapmamış")
            completion(false)
            return
        }
        
        logInfo("Kayıtlı oyunlar Firestore'dan senkronize ediliyor...")
        
        let context = container.viewContext
        
        // Önce mevcut verileri kontrol edelim 
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        do {
            let existingGames = try context.fetch(fetchRequest)
            logInfo("Senkronizasyon öncesi yerel veritabanında \(existingGames.count) oyun var")
            
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
            
            // YENİ YAPI: Kullanıcının kayıtlı oyunlarını getir - userGames/[UID]/savedGames
            db.collection("userGames").document(userID).collection("savedGames")
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        logError("Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        logInfo("Firestore'da kayıtlı oyun bulunamadı")
                        completion(true)
                        return
                    }
                    
                    logInfo("Firestore'dan \(documents.count) oyun getirildi")
                    
                    var newOrUpdatedGames = 0
                    
                    // Her belge için veri formatını kontrol edelim
                    let hasNewDataFormat = self.checkNewDataFormat(documents: documents)
                    logInfo("Veri formatı kontrolü: \(hasNewDataFormat ? "Yeni format tespit edildi" : "Eski format tespit edildi")")
                    
                    // Firestore'dan gelen oyunları detaylı loglayalım
                    for (index, document) in documents.enumerated() {
                        let data = document.data()
                        logInfo("   Firebase oyun \(index+1): ID = \(document.documentID), difficulty = \(data["difficulty"] as? String ?? "nil")")
                    }
                    
                    let context = self.container.viewContext
                    
                    // Her oyunu CoreData'ya kaydet veya güncelle
                    for document in documents {
                        let documentID = document.documentID
                        let data = document.data()
                        
                        // Eğer bu ID yerel olarak silinmişse, senkronize etme
                        if recentlyDeletedIDs.contains(documentID.uppercased()) || recentlyDeletedIDs.contains(documentID.lowercased()) {
                            logInfo("ID: \(documentID) olan oyun yakın zamanda silinmiş. Senkronize edilmiyor.")
                            continue
                        }
                        
                        // Oyunu yerel veritabanında bulmaya çalış - önce UUID'yi standardize edelim
                        let standardizedID = UUID(uuidString: documentID) ?? UUID(uuidString: documentID.uppercased()) ?? UUID(uuidString: documentID.lowercased())
                        
                        if standardizedID == nil {
                            logWarning("Geçersiz UUID formatı: \(documentID). Bu oyun atlanıyor.")
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
                                    logInfo("Oyun ID: \(documentID) için değişiklik tespit edildi. Güncelleniyor...")
                                
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
                                    logInfo("Oyun ID: \(documentID) için değişiklik yok. Atlıyor.")
                                }
                            } else {
                                // Yeni oyun oluştur
                                logInfo("Yeni oyun oluşturuluyor: \(documentID)")
                                
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
                            logError("Oyun işleme hatası: \(error.localizedDescription)")
                        }
                    }
                    
                    // Değişiklikleri kaydet
                    do {
                        if context.hasChanges {
                        try context.save()
                        
                        // Sadece değişiklik olduğunda bildirim gönder
                        if newOrUpdatedGames > 0 {
                                logSuccess("\(newOrUpdatedGames) oyun başarıyla senkronize edildi")
                            // Core Data'nın yenilenmesi için bildirim gönder
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                            }
                        } else {
                                logInfo("Senkronizasyon tamamlandı, değişiklik yapılmadı.")
                            }
                        } else {
                            logInfo("Senkronizasyon tamamlandı, kaydedilecek değişiklik yok.")
                        }
                        
                        logSuccess("Firebase senkronizasyonu tamamlandı")
                        completion(true)
                    } catch {
                        logError("Core Data kaydetme hatası: \(error)")
                        completion(false)
                    }
                }
        } catch {
            logWarning("Yerel veritabanı sorgulanamadı: \(error)")
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
        
        logInfo("Format Analizi: \(newFormatCount) yeni format, \(oldFormatCount) eski format oyun")
        
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
                    logWarning("JSON karşılaştırma hatası: \(error)")
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
                    logWarning("JSON karşılaştırma hatası: \(error)")
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
            logInfo("Yüklenen oyun sayısı: \(savedGames.count)")
            
            // SavedGame nesnelerinin ID'leri için kontrol
            var idFixed = false
            for (index, game) in savedGames.enumerated() {
                if game.value(forKey: "id") == nil {
                    let newID = UUID()
                    game.setValue(newID, forKey: "id")
                    logInfo("Oyun #\(index) için eksik ID oluşturuldu: \(newID)")
                    idFixed = true
                }
            }
            
            // Değişiklikler varsa kaydet
            if context.hasChanges && idFixed {
                try context.save()
                logSuccess("Eksik ID'ler düzeltildi ve kaydedildi")
            }
            
            return savedGames
        } catch {
            logError("Kayıtlı oyunlar yüklenemedi: \(error)")
        }
        return []
    }
    
    func deleteSavedGame(_ game: SavedGame) {
        let context = container.viewContext
        
        // Debug: Oyun nesnesinin detaylarını göster
        logInfo("Silinecek oyun detayları:")
        if let gameID = game.value(forKey: "id") as? UUID {
            let gameIDString = gameID.uuidString
            logInfo("Oyun UUID: \(gameID)")
            logInfo("Oyun UUID String: \(gameIDString)")
            
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
                
                logInfo("Oyun ID \(gameIDString) silinen oyunlar listesine eklendi")
            }
            
            // Kullanıcı kontrolü
            guard let currentUser = Auth.auth().currentUser else {
                logError("Firebase'de oturum açık değil!")
                return
            }
            logInfo("Mevcut kullanıcı: \(currentUser.uid)")
            
            // Firestore'dan sil
            let documentID = gameID.uuidString.uppercased()
            logInfo("Firebase'den silinecek döküman ID: \(documentID)")
            
            // Önce dökümanı kontrol et
            db.collection("savedGames").document(documentID).getDocument { [weak self] (document, error) in
                guard let self = self else { return }
                
                if let error = error {
                    logError("Döküman kontrol hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    logWarning("Döküman zaten Firebase'de mevcut değil")
                    return
                }
                
                // Döküman verilerini kontrol et
                if let data = document.data(),
                   let documentUserID = data["userID"] as? String {
                    logInfo("Döküman sahibi: \(documentUserID)")
                    logInfo("Mevcut kullanıcı: \(currentUser.uid)")
                    
                    // Kullanıcı yetkisi kontrolü
                    if documentUserID != currentUser.uid {
                        logError("Bu dökümanı silme yetkiniz yok!")
                        return
                    }
                }
                
                // Silme işlemini gerçekleştir
                self.db.collection("savedGames").document(documentID).delete { error in
                    if let error = error {
                        logError("Firestore'dan oyun silme hatası: \(error.localizedDescription)")
                    } else {
                        logSuccess("Oyun Firestore'dan silindi: \(documentID)")
                        
                        // Silme işlemini doğrula
                        self.db.collection("savedGames").document(documentID).getDocument { (document, _) in
                            if let document = document, document.exists {
                                logWarning("Dikkat: Döküman hala Firebase'de mevcut!")
                            } else {
                                logSuccess("Doğrulandı: Döküman Firebase'den başarıyla silindi")
                            }
                        }
                    }
                }
            }
        } else {
            logError("Oyun ID'si alınamadı!")
        }
        
        // Yerel veritabanından sil
        context.delete(game)
        
        do {
            try context.save()
            logSuccess("Oyun yerel veritabanından silindi")
            
            // Oyun silindikten hemen sonra UI güncellemesi için bildirim gönder
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
            }
        } catch {
            logError("Oyun silinemedi: \(error)")
        }
    }
    
    // ID'ye göre kaydedilmiş oyunu sil
    func deleteSavedGameWithID(_ gameID: UUID) {
        let context = container.viewContext
        
        // UUID'yi uppercase olarak kullan
        let documentID = gameID.uuidString.uppercased()
        logInfo("\(documentID) ID'li oyun siliniyor...")
        
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
                logSuccess("ID'si \(gameID) olan oyun başarıyla Core Data'dan silindi")
                
                // Bildirimleri gönder - UI güncellemesi için
                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
            } else {
                logWarning("Silinecek oyun Core Data'da bulunamadı, ID: \(gameID)")
                // Core Data'da bulunamasa bile Firebase'den silmeyi dene
                deleteGameFromFirestore(gameID: gameID)
            }
        } catch {
            logError("Oyun silinemedi: \(error)")
        }
    }
    
    // Firestore'dan oyun silme - Updated for Offline Support
    func deleteGameFromFirestore(gameID: UUID) {
        let documentID = gameID.uuidString.uppercased()
        guard let userID = Auth.auth().currentUser?.uid else {
            logError("Firebase'den oyun silinemiyor: Kullanıcı oturum açmamış. ID: \(documentID)")
            // Should we queue this if user is logged out? Probably not.
            return
        }
        let collectionPath = "userGames/\(userID)/savedGames"
        
        // Simplified logic: Directly attempt delete and queue on failure/offline
        // The 'deletedGames' collection logic might need re-evaluation separately
        logInfo("Firestore'dan oyun silme işlemi deneniyor: \(documentID)")
        
        // Check network status
        guard NetworkMonitor.shared.isConnected else {
            logWarning("Çevrimdışı: Oyun silme işlemi kuyruğa alınıyor: \(documentID)")
            queuePendingOperation(action: "delete", dataType: "savedGame", dataID: documentID, payload: nil)
            return
        }
        
        // Attempt Firestore Delete
        let gameRef = db.collection(collectionPath).document(documentID)
        gameRef.delete { [weak self] error in
            if let error = error {
                let nsError = error as NSError
                // Check if it's just 'not found' which is success for delete
                if nsError.code == FirestoreErrorCode.notFound.rawValue {
                     logWarning("Silinecek oyun Firestore'da zaten bulunamadı: \(documentID)")
                     // Consider it deleted, do nothing more.
                return
            }
            
                logError("Firestore oyun silme hatası: \(error.localizedDescription) - ID: \(documentID)")
                if self?.isFirestoreErrorTemporary(error) ?? false {
                    logWarning("Geçici hata: Oyun silme işlemi kuyruğa alınıyor: \(documentID)")
                    self?.queuePendingOperation(action: "delete", dataType: "savedGame", dataID: documentID, payload: nil)
            } else {
                     logError("Kalıcı Firestore hatası, silme işlemi kuyruğa alınmadı: \(documentID)")
                }
            } else {
                logSuccess("Oyun Firestore'dan başarıyla silindi: \(documentID)")
            }
        }
    }
    
    // Silinen oyunları kontrol et - manuel tetikleme için - GELİŞTİRİLMİŞ VERSİYON 2.0
    func checkForDeletedGames() {
        // Kullanıcı giriş yapmamışsa geri dön
        guard Auth.auth().currentUser != nil else { return }
        
        logInfo("NÜKLEER KONTROL ÇAĞRILDI: TÜM silinen oyunlar kontrol edilecek")
        
        // TÜM silinen oyunları getir - filtreleme OLMADAN
        db.collection("deletedGames").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                logError("Silinen oyunlar getirilemedi: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                logInfo("Silinen oyun kaydı bulunamadı")
                return
            }
            
            logInfo("Toplam \(documents.count) silinen oyun kaydı bulundu")
            
            // Önce tüm yerel oyunları getir
            let context = self.container.viewContext
            let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
            
            do {
                let localGames = try context.fetch(fetchRequest)
                let localGameIDs = localGames.compactMap { $0.id?.uuidString.uppercased() }
                
                logInfo("YEREL OYUNLAR: \(localGameIDs.count) oyun var")
                var silinecekOyunlar = [UUID]()
                
                // Her silinen oyun için, yerelde var mı diye kontrol et
                for document in documents {
                    guard let gameID = document.data()["gameID"] as? String else { continue }
                    let upperGameID = gameID.uppercased()
                    
                    logInfo("Silinen oyun kontrolu: \(upperGameID)")
                    
                    // Yerel veritabanında bu ID'ye sahip oyun var mı?
                    if localGameIDs.contains(upperGameID), let uuid = UUID(uuidString: upperGameID) {
                        silinecekOyunlar.append(uuid)
                        logInfo("Eşleşme bulundu! \(upperGameID) silinecek")
                    }
                }
                
                // Tespit edilen oyunları sil
                if !silinecekOyunlar.isEmpty {
                    logInfo("\(silinecekOyunlar.count) oyun bulundu ve silinecek")
                    
                    for gameID in silinecekOyunlar {
                        self.deleteLocalGameOnly(gameID: gameID)
                    }
                } else {
                    logSuccess("Silinecek yerel oyun bulunamadı - zaten güncel")
                }
            } catch {
                logError("Yerel oyunlar getirilemedi: \(error.localizedDescription)")
            }
        }
    }
    
    // Sadece yerel CoreData'daki oyunu sil - Firebase'e bildirim göndermeden - GELİŞTİRİLMİŞ VERSİYON
    // Bu metod, başka bir cihazdan silinen oyunlar için kullanılır
    func deleteLocalGameOnly(gameID: UUID) {
        logInfo("GELİŞTİRİLMİŞ SİLME FONKSİYONU: \(gameID)")
        
        // UUID'yi uppercase olarak al (standart format)
        let gameIDString = gameID.uuidString.uppercased()
        
        // Context ve fetch request oluştur
        let context = container.viewContext
        
        // Tüm oyunları getir ve kendi filtreleyelim
        let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
        
        // Önce tüm oyunları çekip, UUID'leri kendimiz kontrol edelim (daha güvenilir)
        do {
            let allGames = try context.fetch(fetchRequest)
            logInfo("Toplam \(allGames.count) oyun kontrol edilecek")
            
            // Sililenecek oyunları bulalım
            var gameToDelete: SavedGame? = nil
            
            for game in allGames {
                if let gameUUID = game.id {
                    // UUID'yi uppercase formata standardize et
                    let currentGameUUID = gameUUID.uuidString.uppercased()
                    
                    // Eşleşme kontrolü - UUID karşılaştırma
                    if currentGameUUID == gameIDString {
                        gameToDelete = game
                        logInfo("Eşleşen oyun bulundu! \(currentGameUUID)")
                        break
                    }
                }
            }
            
            // Silme işlemi
            if let gameToDelete = gameToDelete {
                // CoreData'dan oyunu sil
                context.delete(gameToDelete)
                try context.save()
                logSuccess("OYUN SİLİNDİ! \(gameIDString) ID'li oyun yerel veritabanından kaldırıldı")
                
                // Bildirimleri gönder - UI güncellemesi için (güvenli olması için gecikme ile)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                    logInfo("UI Yenileme bildirimi gönderildi - Oyun listesi güncellenecek")
                }
            } else {
                logWarning("Silmek için oyun bulunamadı. ID: \(gameIDString)")
            }
        } catch {
            logError("Yerel oyun silinirken hata: \(error.localizedDescription)")
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
            logSuccess("Tüm kaydedilmiş oyunlar yerel veritabanından silindi")
            
            // Firestore'dan kullanıcıya ait tüm oyunları sil
            deleteAllUserGamesFromFirestore()
            
        } catch {
            logError("Kaydedilmiş oyunlar silinemedi: \(error)")
        }
    }
    
    // Firestore'dan kullanıcıya ait tüm oyunları sil
    func deleteAllUserGamesFromFirestore() {
        guard let userID = Auth.auth().currentUser?.uid else {
            logWarning("Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
            return
        }
        
        logInfo("Tüm oyunlar Firestore'dan siliniyor... Kullanıcı ID: \(userID)")
        
        // Düzeltme: Doğru koleksiyon yolunu kullan
        // Kullanıcıya ait savedGames koleksiyonunu al (alt koleksiyon olarak)
        let collectionPath = "userGames/\(userID)/savedGames"
        
        // Koleksiyondaki tüm belgeleri getir - isEqualTo filtresine gerek yok çünkü zaten kullanıcı koleksiyonundayız
        db.collection(collectionPath)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    logError("Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    logInfo("Firestore'da silinecek oyun bulunamadı")
                    return
                }
                
                // Toplu işlem için batch oluştur
                let batch = self.db.batch()
                
                // Tüm belgeleri batch'e ekle - doğru koleksiyon yolunu kullan
                for document in documents {
                    let docRef = self.db.collection(collectionPath).document(document.documentID)
                    batch.deleteDocument(docRef)
                }
                
                // Batch işlemini çalıştır
                batch.commit { error in
                    if let error = error {
                        logError("Firestore toplu oyun silme hatası: \(error.localizedDescription)")
                    } else {
                        logSuccess("\(documents.count) oyun Firestore'dan silindi")
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
                logSuccess("Oyun zorluk seviyesi güncellendi: \(newDifficulty)")
            }
        } catch {
            logError("Oyun zorluk seviyesi güncellenirken hata oluştu: \(error)")
        }
    }
    
    // MARK: - General
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logError("CoreData kaydetme hatası: \(error)")
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
            logError("Yüksek skor kaydedilemedi: \(error)")
            return false
        }
    }
    
    // Yüksek skor bilgilerini Firestore'a kaydet - Updated for Offline Support
    func saveHighScoreToFirestore(scoreID: String, difficulty: String, elapsedTime: TimeInterval, errorCount: Int, hintCount: Int, score: Int, playerName: String) {
        let userID = Auth.auth().currentUser?.uid ?? "guest"
        let collectionPath = "highScores"
        let documentID = scoreID // Assuming scoreID is unique UUID string
        
        var scoreData: [String: Any] = [
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
        // Add lastUpdated for consistency with pending operations update
        scoreData["lastUpdated"] = FieldValue.serverTimestamp() // <<< TIMESTAMP BURADA DA DOĞRU KULLANILIYOR
        
        var payload: Data?
        do {
             // ---> DÜZELTME: Önce timestamp'leri çıkar, sonra JSON'a çevir <---
             var payloadDict = scoreData // Kopyala
             payloadDict.removeValue(forKey: "date") // Timestamp'ı çıkar
             payloadDict.removeValue(forKey: "lastUpdated") // Timestamp'ı çıkar
             payload = try JSONSerialization.data(withJSONObject: payloadDict) // Timestampsız sözlüğü JSON'a çevir
             
             // Eski/Hatalı Kod:
             // payload = try JSONSerialization.data(withJSONObject: scoreData)
             // if var dict = try JSONSerialization.jsonObject(with: payload!) as? [String: Any] {
             //   dict.removeValue(forKey: "date")
             //   dict.removeValue(forKey: "lastUpdated")
             //   payload = try? JSONSerialization.data(withJSONObject: dict)
             // }
             // ---> Düzeltme Sonu <---
        } catch {
             logError("Skor verisi payload için serileştirilemedi: \(error)")
        }

        // Check network status
        guard NetworkMonitor.shared.isConnected else {
            logWarning("Çevrimdışı: Yüksek skor kaydetme işlemi kuyruğa alınıyor: \(documentID)")
            queuePendingOperation(action: "create", dataType: "highScore", dataID: documentID, payload: payload)
            return
        }

        // Attempt Firestore operation
        let scoreRef = db.collection(collectionPath).document(documentID)
        scoreRef.setData(scoreData, merge: true) { [weak self] error in
            if let error = error {
                logError("Firestore yüksek skor kaydı hatası: \(error.localizedDescription) - ID: \(documentID)")
                if self?.isFirestoreErrorTemporary(error) ?? false {
                    logWarning("Geçici hata: Yüksek skor kaydetme işlemi kuyruğa alınıyor: \(documentID)")
                    self?.queuePendingOperation(action: "create", dataType: "highScore", dataID: documentID, payload: payload)
            } else {
                     logError("Kalıcı Firestore hatası, işlem kuyruğa alınmadı: \(documentID)")
                }
            } else {
                logSuccess("Yüksek skor Firebase Firestore'a kaydedildi: \(documentID)")
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
            logError("Yüksek skorlar getirilemedi: \(error)")
            return []
        }
    }
    
    // MARK: - User Account Management
    
    // Kullanıcı hesabını sil
    func deleteUserAccount(completion: @escaping (Bool, Error?) -> Void) {
        // Kullanıcının giriş yapmış olduğundan emin ol
        guard let currentUser = getCurrentUser(), let firebaseUID = currentUser.firebaseUID else {
            logError("Hesap silme hatası: Kullanıcı giriş yapmamış veya Firebase UID yok")
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
            logSuccess("Yerel veritabanından \(savedGames.count) kayıtlı oyun silindi")
        } catch {
            logError("Kayıtlı oyunları silme hatası: \(error.localizedDescription)")
        }
        
        // Kullanıcının yüksek skorlarını sil
        let highScoresRequest: NSFetchRequest<HighScore> = HighScore.fetchRequest()
        highScoresRequest.predicate = NSPredicate(format: "user == %@", currentUser)
        
        do {
            let highScores = try context.fetch(highScoresRequest)
            for score in highScores {
                context.delete(score)
            }
            logSuccess("Yerel veritabanından \(highScores.count) yüksek skor silindi")
        } catch {
            logError("Yüksek skorları silme hatası: \(error.localizedDescription)")
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
                logSuccess("Yerel veritabanından \(achievements.count) başarım silindi")
            } catch {
                logError("Başarımları silme hatası: \(error.localizedDescription)")
            }
        } else {
            logInfo("Achievement entity'si bulunamadı veya kullanılabilir değil")
        }
        
        // Kullanıcıyı sil
        context.delete(currentUser)
        
        // Değişiklikleri kaydet
        do {
            try context.save()
            logSuccess("Yerel kullanıcı verileri başarıyla silindi")
        } catch {
            logError("Yerel kullanıcı verilerini silerken hata: \(error.localizedDescription)")
            completion(false, error)
            return
        }
            
        // 2. Firebase Authentication'dan kullanıcıyı sil
        Auth.auth().currentUser?.delete { [weak self] error in
            guard let self = self else { return }
                
                if let error = error {
                    logError("Firebase hesap silme hatası: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                // Firebase Auth'dan silme başarılı olduysa Firestore verilerini silmeye devam et
                logSuccess("Firebase Authentication kullanıcısı başarıyla silindi: \(firebaseUID)")

                // 3. Firestore'dan kullanıcı verilerini sil (Asenkron olarak)
                self.deleteAllUserDataFromFirestore(userID: firebaseUID) { success in
                    if success {
                        logSuccess("Firestore\'daki tüm kullanıcı verileri başarıyla silindi!")
                    } else {
                        logWarning("Firestore kullanıcı verilerini silerken bazı hatalar oluştu, ancak Auth silindi.")
                    }
                    // Yerel veriler ve Auth zaten silindiği için burada her durumda başarılı dönüyoruz
                    // Çıkış yapma bildirimi zaten yerel silme sonrası gönderilmiş olmalı,
                    // ama garanti olması için tekrar gönderilebilir veya kontrol edilebilir.
                    DispatchQueue.main.async {
                         NotificationCenter.default.post(name: Notification.Name("UserLoggedOut"), object: nil)
                    }
                    completion(true, nil) // Auth silme başarılıysa, işlemi başarılı say
                }
        }
    }
    
    // MARK: - Firestore Data Deletion Helper

    // MARK: - Firebase User Management
    
    // Profil resimlerini senkronize etmek için yeni bir fonksiyon ekle
    func syncProfileImage(completion: @escaping (Bool) -> Void = { _ in }) {
        // Kullanıcı giriş yapmış mı kontrol et
        guard let currentUser = getCurrentUser(), 
              let firebaseUID = currentUser.firebaseUID else {
                logWarning("Profil resmi senkronize edilemedi: Kullanıcı giriş yapmamış veya Firebase UID yok")
            completion(false)
            return
        }
        
            logInfo("Profil resmi Firebase'den senkronize ediliyor...")
        
        // Firebase'den kullanıcı bilgilerini al
        db.collection("users").document(firebaseUID).getDocument { [weak self] (document, error) in
            guard let self = self else { 
                completion(false)
                return 
            }
            
            if let error = error {
                    logError("Firebase profil bilgisi getirme hatası: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let document = document, document.exists,
                  let userData = document.data() else {
                    logWarning("Firebase'de kullanıcı bilgisi bulunamadı")
                completion(false)
                return
            }
            
            // Profil resmi URL'sini kontrol et
            if let photoURL = userData["photoURL"] as? String {
                // URL'leri karşılaştır
                if photoURL != currentUser.photoURL {
                        logInfo("Firebase'de farklı profil resmi bulundu, güncelleniyor...")
                    
                    // Yerel URL'yi güncelle
                    currentUser.photoURL = photoURL
                    
                    do {
                        try self.container.viewContext.save()
                            logSuccess("Profil resmi URL'si yerel veritabanında güncellendi")
                        
                        // Profil resmini indir
                        self.downloadProfileImage(forUser: currentUser, fromURL: photoURL)
                        completion(true)
                    } catch {
                            logError("Profil resmi URL'si güncellenirken hata: \(error.localizedDescription)")
                        completion(false)
                    }
                } else {
                        logSuccess("Profil resmi URL'si zaten güncel")
                    completion(true)
                }
            } else {
                    logInfo("Firebase'de profil resmi URL'si bulunamadı")
                completion(false)
            }
        }
    }
    
    func registerUserWithFirebase(username: String, password: String, email: String, name: String, completion: @escaping (Bool, Error?) -> Void) {
        // Önce Firebase Auth'a kaydet
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                    logError("Firebase kayıt hatası: \(error.localizedDescription)")
                let nsError = error as NSError
                    logError("Firebase hata detayları: \(nsError.userInfo)")
                completion(false, error)
                return
            }
            
            guard let user = authResult?.user else {
                    logError("Firebase kullanıcı oluşturma hatası")
                completion(false, nil)
                return
            }
            
            // Kullanıcı profil bilgilerini güncelle
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            
            changeRequest.commitChanges { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                        logError("Firebase profil güncelleme hatası: \(error.localizedDescription)")
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
                            logError("Firestore kullanıcı veri kaydı hatası: \(error.localizedDescription)")
                    } else {
                            logSuccess("Kullanıcı verileri Firestore'a kaydedildi: \(username)")
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
                                        logSuccess("Kullanıcı Firebase UID ile güncellendi")
                                } catch {
                                        logError("Profil resmi indirilirken hata: \(error.localizedDescription)")
                                }
                            }
                            
                                logSuccess("Kullanıcı Firebase ve yerel veritabanına kaydedildi: \(username)")
                            completion(true, nil)
                        } else {
                                logWarning("Kullanıcı Firebase'e kaydedildi ancak yerel kayıt başarısız")
                            // Firebase'e kaydedildi ancak yerel kayıt başarısız oldu - yine de başarılı sayabiliriz
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }
    
    // Firebase ile giriş yapma
    func loginUserWithFirebase(email: String, password: String, completion: @escaping (NSManagedObject?, Error?) -> Void) {
        // E-posta kontrolü
        let isEmail = email.contains("@")
        
        // Önce kullanıcı adını e-posta adresine çevirmeye çalış (e-posta değilse)
        if !isEmail {
            // Kullanıcı adına karşılık gelen e-postayı bul
            let context = container.viewContext
            let request: NSFetchRequest<User> = User.fetchRequest()
            request.predicate = NSPredicate(format: "username == %@", email)
            
            do {
                let users = try context.fetch(request)
                if let user = users.first, let userEmail = user.email, !userEmail.isEmpty {
                    // Kullanıcı bulundu, e-posta ile giriş yap
                    logInfo("Kullanıcı adı '\(email)' için e-posta bulundu: \(userEmail)")
                    
                    // Recursion yerine devam edebilmek için e-posta ile Firebase'e giriş yapalım
                    Auth.auth().signIn(withEmail: userEmail, password: password) { [weak self] authResult, error in
                        self?.handleFirebaseLoginResult(authResult: authResult, error: error, completion: completion)
                    }
                    return
                } else {
                    // Kullanıcı bulunamadı, direkt olarak giriş deneyelim (olası hata vereceğini biliyoruz)
                    logWarning("'\(email)' kullanıcı adı için e-posta bulunamadı")
                    
                    // Yine de denemeye devam edelim, belki e-posta formatındadır
                    Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
                        self?.handleFirebaseLoginResult(authResult: authResult, error: error, completion: completion)
                    }
                return
            }
            } catch {
                logError("Kullanıcı adı sorgulama hatası: \(error.localizedDescription)")
                
                // Hata durumunda bilgi döndür
                completion(nil, error)
                return
            }
                        } else {
            // E-posta ile direkt olarak giriş yap
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
                self?.handleFirebaseLoginResult(authResult: authResult, error: error, completion: completion)
            }
        }
    }
    
    // Firebase giriş sonucunu işleyen yardımcı metod
    private func handleFirebaseLoginResult(authResult: AuthDataResult?, error: Error?, completion: @escaping (NSManagedObject?, Error?) -> Void) {
                        if let error = error {
            logError("Firebase giriş hatası: \(error.localizedDescription)")
            completion(nil, error)
            return
        }
        
        guard let user = authResult?.user else {
            logError("Firebase kullanıcı verisi alınamadı")
            completion(nil, nil)
            return
        }
        
        logSuccess("Firebase girişi başarılı: \(user.uid)")
        
        // Firestore'dan kullanıcı verilerini çek
        db.collection("users").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                logError("Firestore kullanıcı bilgileri getirilemedi: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let document = document, document.exists else {
                logError("Firebase kullanıcısı Firestore'da bulunamadı")
                completion(nil, nil)
                        return
                    }
            
            logSuccess("Firestore kullanıcı bilgileri başarıyla getirildi")
            
            // Kullanıcı verilerini çıkart
            let data = document.data() ?? [:]
            let username = data["username"] as? String ?? ""
            let email = data["email"] as? String ?? user.email ?? ""
            let name = data["name"] as? String ?? ""
            
            // CoreData'da bu kullanıcıyı ara
            let context = self.container.viewContext
            let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "firebaseUID == %@", user.uid)
                
                do {
                let users = try context.fetch(fetchRequest)
                
                    if let existingUser = users.first {
                    // Firebase'den bilgileri güncelle
                        existingUser.isLoggedIn = true
                    existingUser.lastLoginDate = Date()
                    
                    // Diğer bilgileri güncelle (opsiyonel)
                    if existingUser.name == nil || existingUser.name?.isEmpty == true {
                        existingUser.name = name
                    }
                    
                    if existingUser.email == nil || existingUser.email?.isEmpty == true {
                        existingUser.email = email
                    }
                    
                    try context.save()
                        completion(existingUser, nil)
                } else {
                    // Kullanıcıyı CoreData'ya kaydet
                    let newUser = User(context: context)
                    newUser.id = UUID()
                            newUser.username = username
                    newUser.email = email
                    newUser.name = name
                    newUser.firebaseUID = user.uid
                    newUser.isLoggedIn = true
                    newUser.registrationDate = Date()
                    newUser.lastLoginDate = Date()
                    
                    try context.save()
                    completion(newUser, nil)
                }
                } catch {
                logError("CoreData kullanıcı oluşturma/güncelleme hatası: \(error.localizedDescription)")
                    completion(nil, error)
            }
        }
    }
    
    // Profil resmi yükleme yardımcı fonksiyonu - geliştirilmiş versiyon
    private func downloadProfileImage(forUser user: User, fromURL urlString: String) {
            let timestamp = Date()
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
            logInfo("[\(deviceID)] Profil resmi indiriliyor: \(urlString) | Zaman: \(timestamp)")
            
            // Önbellek temizleme
            URLCache.shared.removeAllCachedResponses()
        
        guard let url = URL(string: urlString) else {
                logError("[\(deviceID)] Geçersiz profil resmi URL'si: \(urlString)")
            return
        }
        
            // Zorla yeniden yükleme için önbellek politikasını güncelle
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 15 // 15 saniyelik timeout
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                    logError("[\(deviceID)] Profil resmi indirme hatası: \(error.localizedDescription)")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                    logInfo("[\(deviceID)] Profil resmi yanıt kodu: \(response.statusCode)")
                    
                    // Başarısız yanıt kodları için erken dönüş
                    if response.statusCode < 200 || response.statusCode >= 300 {
                        logWarning("[\(deviceID)] HTTP hatası - Başarısız yanıt kodu: \(response.statusCode)")
                        return
                    }
                }
                
                guard let data = data, !data.isEmpty else {
                    logError("[\(deviceID)] Profil resmi verisi boş veya nil")
                return
            }
            
                guard let image = UIImage(data: data) else {
                    logError("[\(deviceID)] Veriler geçerli bir görüntü değil: \(data.count) byte")
                    return
                }
                
                // Görüntü ve veri kontrolleri
                let imageSize = image.size
                let dataHash = data.hashValue
                logSuccess("Profil resmi başarıyla indirildi: \(data.count) byte, Boyut: \(imageSize.width)x\(imageSize.height), Hash: \(dataHash)")
            
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
                        
                        logSuccess("[\(deviceID)] Profil resmi yerel veritabanına kaydedildi: \(dataHash)")
                        
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
                        logError("[\(deviceID)] Profil resmi yerel olarak kaydedilemedi: \(error.localizedDescription)")
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
                logError("Kullanıcı e-postası aranırken hata: \(error.localizedDescription)")
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
            logWarning("Firebase Firestore devre dışı: Oyun sadece yerel veritabanına kaydedildi")
    }
    
    // Firebase'den oyunları senkronize et - şimdilik devre dışı
    func syncGamesFromFirebase(for firebaseUID: String) {
        // Firebase Firestore kapalı - sadece log çıktısı
            logWarning("Firebase Firestore devre dışı: Oyun senkronizasyonu yapılamadı")
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
                        logError("Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                        logInfo("Firestore'da kayıtlı oyun bulunamadı")
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
                        logInfo("Firestore'da yüksek skor bulunamadı")
                    completion(true)
                    return
                }
                
                    logInfo("Bulunan yüksek skor sayısı: \(documents.count)")
                
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
                        
                            logSuccess("Yüksek skor senkronize edildi: \(scoreID)")
                    } catch {
                            logError("CoreData skor güncelleme hatası: \(error.localizedDescription)")
                    }
                }
                
                // Değişiklikleri kaydet
                do {
                    try context.save()
                    
                    // Sadece değişiklik olduğunda bildirim gönder
                    // Bu değişen bir şey varsa anlamına gelir
                    if documents.count > 0 {
                            logSuccess("Oyunlar başarıyla senkronize edildi")
                        // Core Data'nın yenilenmesi için bildirim gönder
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                        }
                    }
                    
                        logSuccess("Firebase senkronizasyonu tamamlandı")
                    completion(true)
                } catch {
                        logError("CoreData kaydetme hatası: \(error)")
                    completion(false)
                }
            }
    }
    
    // Uygulama başladığında ve gerektiğinde yüksek skorları senkronize et
    func refreshHighScores() {
        syncHighScoresFromFirestore { success in
            if success {
                    logSuccess("Yüksek skorlar başarıyla güncellendi")
            } else {
                    logWarning("Yüksek skorlar güncellenirken bir sorun oluştu")
            }
        }
    }
    
    // Firestore'dan tamamlanmış oyunları getir
    func fetchCompletedGamesFromFirestore(limit: Int = 8, completion: @escaping ([String: Any]?, Error?) -> Void) {
        // Kullanıcı giriş yapmış mı kontrol et
        guard let userID = Auth.auth().currentUser?.uid else {
                logWarning("Firestore oyunları getirilemedi: Kullanıcı giriş yapmamış")
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
                        logError("Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                        logInfo("Firestore'da tamamlanmış oyun bulunamadı")
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
                
                    logSuccess("Firestore'dan \(games.count) tamamlanmış oyun yüklendi")
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
                    
                    logInfo("Tamamlanan oyun ID \(documentID) silinen oyunlar listesine eklendi")
                }
                
                // 2. Firestore'da kayıtlı belge varsa önce silelim
                if let document = document, document.exists {
                    gameRef.delete { [weak self] deleteError in
                        guard let self = self else { return }
                        
                        if let deleteError = deleteError {
                            logWarning("Tamamlanmış oyun kaydedilmeden önce silinemedi: \(deleteError.localizedDescription)")
                        } else {
                            logSuccess("Tamamlanmış oyun başarıyla silindi: \(documentID)")
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
        
        // Tamamlanmış oyun verilerini kaydetme yardımcı fonksiyonu - Updated for Offline Support
        private func saveCompletedGameData(gameRef: DocumentReference, gameData: [String: Any], documentID: String, gameID: UUID) {
            
            var mutableGameData = gameData // Make mutable for removing timestamps
            var payload: Data?
            do {
                 // Remove server timestamps before creating payload
                 mutableGameData.removeValue(forKey: "dateCreated")
                 mutableGameData.removeValue(forKey: "timestamp")
                 mutableGameData.removeValue(forKey: "lastUpdated") // Assume performFirestoreUpdate adds this
                 payload = try JSONSerialization.data(withJSONObject: mutableGameData)
            } catch {
                 logError("Tamamlanmış oyun verisi payload için serileştirilemedi: \(error)")
            }
            
            // Check network status
            guard NetworkMonitor.shared.isConnected else {
                logWarning("Çevrimdışı: Tamamlanmış oyun kaydetme işlemi kuyruğa alınıyor: \(documentID)")
                // Use 'update'/'create' action for completed game save (it's a setData call)
                queuePendingOperation(action: "create", dataType: "completedGame", dataID: documentID, payload: payload)
                 // Also delete locally immediately after queueing if offline?
                 // self.deleteSavedGameFromCoreData(gameID: documentID) // Decide if local delete happens now or after successful sync.
                return
            }
            
            // Attempt Firestore save
            gameRef.setData(gameData) { [weak self] error in // Use original gameData with timestamps here
                guard let self = self else { return }
                
                if let error = error {
                    logError("Tamamlanmış oyun Firestore'a kaydedilemedi: \(error.localizedDescription) - ID: \(documentID)")
                    if self.isFirestoreErrorTemporary(error) {
                         logWarning("Geçici hata: Tamamlanmış oyun kaydetme işlemi kuyruğa alınıyor: \(documentID)")
                         self.queuePendingOperation(action: "create", dataType: "completedGame", dataID: documentID, payload: payload)
                    } else {
                         logError("Kalıcı Firestore hatası, işlem kuyruğa alınmadı: \(documentID)")
                         // Maybe still delete locally even on permanent failure?
                         // self.deleteSavedGameFromCoreData(gameID: documentID)
                    }
                } else {
                    logSuccess("Tamamlanmış oyun Firestore'a kaydedildi: \(documentID)")
                    // Firebase'e kayıt başarılı olduğunda Core Data'dan sil
                    DispatchQueue.main.async {
                        // Perform local delete only AFTER successful Firestore save
                        self.deleteSavedGameFromCoreData(gameID: documentID)
                        // Trigger UI updates
                        // ... (Notifications remain the same)
                }
            }
        }
    }
    
        // CoreData'dan oyunu sil - UUID formatını düzgün şekilde işle
    func deleteSavedGameFromCoreData(gameID: String) {
        let context = container.viewContext
        
            logInfo("Core Data'dan oyun siliniyor, ID: \(gameID)")
        
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
                logError("Geçersiz UUID formatı: \(gameID)")
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
                    logSuccess("ID'si \(gameID) olan oyun başarıyla Core Data'dan silindi")
            } else {
                    logInfo("Silinecek oyun Core Data'da bulunamadı, ID: \(gameID)")
            }
        } catch {
                logError("Core Data'dan oyun silinirken hata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Completed Games Management
    
    // Tüm tamamlanmış oyunları sil
    func deleteAllCompletedGames() {
        // Kullanıcı kontrolü: giriş yapmışsa
            guard let userID = Auth.auth().currentUser?.uid else {
                logWarning("Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
            return
        }
            
            logInfo("Tüm tamamlanmış oyunları silme işlemi başlatılıyor... Kullanıcı ID: \(userID)")
        
        // Doğrudan Firestore'dan tamamlanmış oyunları sil
        deleteAllCompletedGamesFromFirestore()
    }
    
    // Firestore'dan tüm tamamlanmış oyunları sil
    func deleteAllCompletedGamesFromFirestore() {
        guard let userID = Auth.auth().currentUser?.uid else {
                logWarning("Firestore oyunları silinemedi: Kullanıcı giriş yapmamış")
            return
        }
        
            logInfo("Tüm tamamlanmış oyunlar Firestore'dan siliniyor... Kullanıcı ID: \(userID)")
        
            // Doğru koleksiyon yolunu kullan
            let collectionPath = "userGames/\(userID)/savedGames"
            
            // 1. Önce kullanıcıya ait tüm tamamlanmış oyunları getirelim
        db.collection(collectionPath)
            .whereField("isCompleted", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                        logError("Firestore oyun sorgulama hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                        logInfo("Firestore'da kullanıcıya ait tamamlanmış oyun bulunamadı")
                    return
                }
                
                    logInfo("Bulunan tamamlanmış oyun sayısı: \(documents.count)")
                    
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
                        logInfo("Siliniyor: \(document.documentID)")
                    // Doğru koleksiyon yolunu kullan
                    let gameRef = self.db.collection(collectionPath).document(documentID)
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
            
            // Doğru koleksiyon yolunu kullan
            let collectionPath = "userGames/\(userID)/savedGames"
            
            // Kullanıcının tamamlanmış oyunlarını getir
            db.collection(collectionPath)
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
        
        // MARK: - Pending Operations Processing (Ensure this section is at CLASS SCOPE)
        
        // Bekleyen Firebase işlemlerini işle
    }
    
    // MARK: - Firestore Data Deletion Helper

    // Firestore'dan belirli bir kullanıcının TÜM verilerini silmek için yeni yardımcı fonksiyon
    private func deleteAllUserDataFromFirestore(userID: String, completion: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var allOperationsSuccessful = true

        // Kullanıcı belgesini sil
        dispatchGroup.enter()
        db.collection("users").document(userID).delete { error in
            if let error = error {
                logError("Firestore kullanıcı ('users') belgesi silme hatası: \(error.localizedDescription)")
                allOperationsSuccessful = false
            } else {
                logSuccess("Firestore kullanıcı ('users') belgesi silindi: \(userID)")
            }
            dispatchGroup.leave()
        }

        // userGames alt koleksiyonlarındaki verileri sil (savedGames, completedGames)
        deleteCollection(path: "userGames/\(userID)/savedGames", group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }
        // Not: completedGames ayrı bir koleksiyonsa yolunu buraya ekle, savedGames içindeyse üstteki yeterli.
        // Eğer completedGames ayrı bir üst seviye koleksiyonsa, aşağıdaki gibi sil:
        // deleteCollection(path: "completedGames", userID: userID, group: dispatchGroup) { success in ... }

        // Diğer üst seviye koleksiyonlardaki kullanıcı verilerini sil
        deleteCollection(path: "highScores", userID: userID, group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }
        deleteCollection(path: "achievements", userID: userID, group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }
        deleteCollection(path: "userPreferences", userID: userID, group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }
        deleteCollection(path: "userStats", userID: userID, group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }
        deleteCollection(path: "userActivity", userID: userID, group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }
        deleteCollection(path: "notifications", userID: userID, group: dispatchGroup) { success in
            if !success { allOperationsSuccessful = false }
        }

        // Friends koleksiyonunu temizle (hem userID hem de friendID kontrolü)
        dispatchGroup.enter()
        db.collection("friends").whereField("userID", isEqualTo: userID).getDocuments { snapshot, error in
            if let error = error {
                logError("Firestore 'friends' (userID) getirme hatası: \(error.localizedDescription)")
                allOperationsSuccessful = false
                dispatchGroup.leave()
                return
            }
            if let documents = snapshot?.documents, !documents.isEmpty {
                let batch = self.db.batch()
                documents.forEach { batch.deleteDocument($0.reference) }
                batch.commit { error in
                    if let error = error {
                        logError("Firestore 'friends' (userID) batch delete hatası: \(error.localizedDescription)")
                        allOperationsSuccessful = false
                    } else {
                        logSuccess("Firestore 'friends' (userID) belgeleri silindi.")
                    }
                    dispatchGroup.leave()
                }
            } else {
                dispatchGroup.leave()
            }
        }

        dispatchGroup.enter()
        db.collection("friends").whereField("friendID", isEqualTo: userID).getDocuments { snapshot, error in
            if let error = error {
                logError("Firestore 'friends' (friendID) getirme hatası: \(error.localizedDescription)")
                allOperationsSuccessful = false
                dispatchGroup.leave()
                return
            }
            if let documents = snapshot?.documents, !documents.isEmpty {
                let batch = self.db.batch()
                documents.forEach { batch.deleteDocument($0.reference) }
                batch.commit { error in
                    if let error = error {
                        logError("Firestore 'friends' (friendID) batch delete hatası: \(error.localizedDescription)")
                        allOperationsSuccessful = false
                    } else {
                        logSuccess("Firestore 'friends' (friendID) belgeleri silindi.")
                    }
                    dispatchGroup.leave()
                }
            } else {
                dispatchGroup.leave()
            }
        }

        // Tüm işlemler tamamlandığında sonucu bildir
        dispatchGroup.notify(queue: .main) {
            completion(allOperationsSuccessful)
        }
    }

    // Belirli bir yoldaki koleksiyonu veya alt koleksiyonu silmek için yardımcı fonksiyon
    private func deleteCollection(path: String, userID: String? = nil, group: DispatchGroup, completion: @escaping (Bool) -> Void) {
        group.enter()
        var query: Query = db.collection(path)

        // Eğer userID belirtilmişse, sadece o kullanıcıya ait belgeleri sorgula
        if let userID = userID {
            query = query.whereField("userID", isEqualTo: userID)
        }

        query.limit(to: 500).getDocuments { snapshot, error in // Tek seferde 500 belge limitiyle sil
            if let error = error {
                logError("Firestore koleksiyon getirme hatası ('\(path)'\(userID != nil ? " for user \(userID!)" : "")): \(error.localizedDescription)")
                completion(false)
                group.leave()
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                logInfo("Silinecek belge bulunamadı: '\(path)'\(userID != nil ? " for user \(userID!)" : "")")
                completion(true) // Silinecek bir şey yoksa başarılı sayılır
                group.leave()
                return
            }

            let batch = self.db.batch()
            documents.forEach { batch.deleteDocument($0.reference) }

            batch.commit { error in
                if let error = error {
                    logError("Firestore batch delete hatası ('\(path)'\(userID != nil ? " for user \(userID!)" : "")): \(error.localizedDescription)")
                    completion(false)
                } else {
                    logSuccess("'\(path)'\(userID != nil ? " for user \(userID!)" : "") koleksiyonundan \(documents.count) belge silindi.")
                    // Eğer 500'den fazla belge varsa, fonksiyonu tekrar çağırarak kalanları sil
                    if documents.count >= 500 {
                        // Rekürsif çağrı yapmadan önce group.leave() çağrılmalı
                        group.leave()
                        self.deleteCollection(path: path, userID: userID, group: group, completion: completion)
                        return // Rekürsif çağrı yapıldığı için burada işlemi bitir
                    } else {
                        completion(true) // Silme işlemi tamamlandı
                    }
                }
                // Batch tamamlandığında veya hata oluştuğunda group.leave() çağrılır
                // Rekürsif çağrı durumu hariç
                if documents.count < 500 {
                     group.leave()
                }
            }
        }
    }

    // MARK: - Firebase User Management

    // Kullanıcının seri verilerini getir
    func getUserStreakData(for firebaseUID: String) -> (lastLogin: Date?, currentStreak: Int, highestStreak: Int)? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                // Core Data'dan Int64 olarak gelen değerleri Int'e çevir
                let currentStreak = Int(user.currentStreak)
                let highestStreak = Int(user.highestStreak)
                return (user.lastLoginDate, currentStreak, highestStreak)
            } else {
                logWarning("Seri verisi getirilemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
                return nil
            }
        } catch {
            logError("Kullanıcı seri verisi getirilirken hata: \(error.localizedDescription)")
            return nil
        }
    }

    // Kullanıcının seri verilerini güncelle
    func updateUserStreakData(for firebaseUID: String, lastLogin: Date?, currentStreak: Int, highestStreak: Int) {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.lastLoginDate = lastLogin
                // Int değerlerini Core Data için Int64'e çevir
                user.currentStreak = Int64(currentStreak)
                user.highestStreak = Int64(highestStreak)
                
                if context.hasChanges {
                    try context.save()
                    logSuccess("Kullanıcı seri verileri güncellendi (UID: \(firebaseUID))")
                }
            } else {
                logWarning("Seri verisi güncellenemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
                // İsteğe bağlı: Kullanıcı bulunamazsa oluşturulabilir mi?
                // Şu anki yapıda login/register sırasında kullanıcı oluşturuluyor,
                // bu yüzden burada bulunamaması beklenmedik bir durum olabilir.
            }
        } catch {
            logError("Kullanıcı seri verisi güncellenirken hata: \(error.localizedDescription)")
        }
    }
    
    // Kullanıcının kombo başarı verilerini getir
    func getUserComboData(for firebaseUID: String) -> (perfectCombo: Int, lastGameTime: Double, speedCombo: Int)? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                let perfectCombo = Int(user.perfectComboCount)
                let speedCombo = Int(user.speedComboCount)
                return (perfectCombo, user.lastGameTimeForSpeedCombo, speedCombo)
            } else {
                logWarning("Kombo verisi getirilemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
                return nil // Kullanıcı yoksa varsayılan (0, 0, 0) döndürebiliriz?
            }
        } catch {
            logError("Kullanıcı kombo verisi getirilirken hata: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Kullanıcının kombo başarı verilerini güncelle
    func updateUserComboData(for firebaseUID: String, perfectCombo: Int? = nil, lastGameTime: Double? = nil, speedCombo: Int? = nil) {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                var changed = false
                if let perfectCombo = perfectCombo {
                    user.perfectComboCount = Int64(perfectCombo)
                    changed = true
                }
                if let lastGameTime = lastGameTime {
                    user.lastGameTimeForSpeedCombo = lastGameTime
                    changed = true
                }
                if let speedCombo = speedCombo {
                    user.speedComboCount = Int64(speedCombo)
                    changed = true
                }
                
                if changed && context.hasChanges {
                    try context.save()
                    logSuccess("Kullanıcı kombo verileri güncellendi (UID: \(firebaseUID))")
                }
            } else {
                logWarning("Kombo verisi güncellenemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
            }
        } catch {
            logError("Kullanıcı kombo verisi güncellenirken hata: \(error.localizedDescription)")
        }
    }

    // MARK: - User Counter Management (Daily, Weekend, Cells)

    // Kullanıcının günlük tamamlama verilerini getir
    func getUserDailyCompletionData(for firebaseUID: String) -> (count: Int, lastDate: Date?)? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                let count = Int(user.dailyCompletionCount) // Int64 to Int
                return (count, user.lastCompletionDateForDailyCount)
            } else {
                logWarning("Günlük tamamlama verisi getirilemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
                return nil
            }
        } catch {
            logError("Kullanıcı günlük tamamlama verisi getirilirken hata: \(error.localizedDescription)")
            return nil
        }
    }

    // Kullanıcının günlük tamamlama verilerini güncelle
    func updateUserDailyCompletionData(for firebaseUID: String, count: Int, date: Date?) {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.dailyCompletionCount = Int64(count) // Int to Int64
                user.lastCompletionDateForDailyCount = date
                if context.hasChanges {
                    try context.save()
                    logSuccess("Kullanıcı günlük tamamlama verileri güncellendi (UID: \(firebaseUID)) - Count: \(count)")
                }
            } else {
                logWarning("Günlük tamamlama verisi güncellenemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
            }
        } catch {
            logError("Kullanıcı günlük tamamlama verisi güncellenirken hata: \(error.localizedDescription)")
        }
    }

    // Kullanıcının hafta sonu tamamlama verilerini getir
    func getUserWeekendCompletionData(for firebaseUID: String) -> (count: Int, lastDate: Date?)? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                let count = Int(user.weekendCompletionCount) // Int64 to Int
                // return (count, user.weekendCompletionCount) // Hatalı: Int64 döndürüyor
                return (count, user.lastCompletionDateForWeekendCount) // Düzeltildi: Date? döndürüyor
            } else {
                logWarning("Hafta sonu tamamlama verisi getirilemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
                return nil
            }
        } catch {
            logError("Kullanıcı hafta sonu tamamlama verisi getirilirken hata: \(error.localizedDescription)")
            return nil
        }
    }

    // Kullanıcının hafta sonu tamamlama verilerini güncelle
    func updateUserWeekendCompletionData(for firebaseUID: String, count: Int, date: Date?) {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.weekendCompletionCount = Int64(count) // Int to Int64
                user.lastCompletionDateForWeekendCount = date
                if context.hasChanges {
                    try context.save()
                    logSuccess("Kullanıcı hafta sonu tamamlama verileri güncellendi (UID: \(firebaseUID)) - Count: \(count)")
                }
            } else {
                logWarning("Hafta sonu tamamlama verisi güncellenemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
            }
        } catch {
            logError("Kullanıcı hafta sonu tamamlama verisi güncellenirken hata: \(error.localizedDescription)")
        }
    }

    // Kullanıcının toplam tamamlanan hücre sayısını getir
    func getUserTotalCellsCompleted(for firebaseUID: String) -> Int? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                return Int(user.totalCellsCompleted) // Int64 to Int
            } else {
                logWarning("Toplam hücre sayısı getirilemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
                return nil
            }
        } catch {
            logError("Kullanıcı toplam hücre sayısı getirilirken hata: \(error.localizedDescription)")
            return nil
        }
    }

    // Kullanıcının toplam tamamlanan hücre sayısını güncelle
    func updateUserTotalCellsCompleted(for firebaseUID: String, total: Int) {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.totalCellsCompleted = Int64(total) // Int to Int64
                if context.hasChanges {
                    try context.save()
                    logSuccess("Kullanıcı toplam hücre sayısı güncellendi (UID: \(firebaseUID)) - Total: \(total)")
                }
            } else {
                logWarning("Toplam hücre sayısı güncellenemedi: Kullanıcı bulunamadı (UID: \(firebaseUID))")
            }
        } catch {
            logError("Kullanıcı toplam hücre sayısı güncellenirken hata: \(error.localizedDescription)")
        }
    }

    // Kullanıcının tüm sayaçlarını sıfırla (günlük, haftasonu, hücre, kombo)
    func resetUserCounters(for firebaseUID: String) {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.dailyCompletionCount = 0
                user.lastCompletionDateForDailyCount = nil
                user.weekendCompletionCount = 0
                user.lastCompletionDateForWeekendCount = nil
                user.totalCellsCompleted = 0
                // Combo sayaçlarını da sıfırla
                user.perfectComboCount = 0
                user.lastGameTimeForSpeedCombo = 0.0
                user.speedComboCount = 0
                // Streak sayaçları checkDailyLogin içinde yönetildiği için burada sıfırlanmaz,
                // ancak gerekirse resetAchievementsData içinde ayrıca streak data sıfırlanabilir.

                if context.hasChanges {
                    try context.save()
                    logSuccess("Kullanıcının günlük, hafta sonu, hücre ve kombo sayaçları sıfırlandı (UID: \(firebaseUID))")
                } else {
                    logInfo("Kullanıcı sayaçları zaten sıfırdı veya değişiklik yoktu (UID: \(firebaseUID))")
                }
            } else {
                logWarning("Kullanıcı sayaçları sıfırlanamadı: Kullanıcı bulunamadı (UID: \(firebaseUID))")
            }
        } catch {
            logError("Kullanıcı sayaçları sıfırlanırken hata: \(error.localizedDescription)")
        }
    }

}
    
