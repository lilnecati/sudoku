# Print İfadelerini Log Fonksiyonlarına Dönüştürme Rehberi

Bu belge, Sudoku uygulamasındaki tüm `print` ifadelerini uygun log fonksiyonlarına dönüştürmek için bir rehberdir. Belirtilen bellek ve performans sorunlarını çözmek için bu dönüşümleri yapmanız önerilir.

## Dönüşüm Kuralları

1. **Emoji Bazlı Dönüşüm**:
   - ✅ → `logSuccess`
   - ❌ → `logError`
   - ⚠️ → `logWarning`
   - ℹ️ → `logInfo`
   - 🔍 → `logDebug`
   - 📝 → `logVerbose`
   - Diğer emojiler → İçeriğe göre uygun log fonksiyonu

2. **İçerik Bazlı Dönüşüm**:
   - Hata mesajları → `logError`
   - Uyarı mesajları → `logWarning`
   - Bilgi mesajları → `logInfo`
   - Debug bilgileri → `logDebug`
   - Detaylı loglar → `logVerbose`
   - Başarı mesajları → `logSuccess`

3. **Önemli Not**: LogManager.swift dosyasındaki 85. satırdaki `print(logMessage)` ifadesini değiştirmeyin! Bu, sonsuz döngüye neden olabilir.

## Dönüştürülecek Print İfadeleri

Aşağıda, projede bulunan tüm `print` ifadeleri ve bunların hangi log fonksiyonuna dönüştürülmesi gerektiği listelenmiştir:

### fix_all_errors.swift
```swift
print("✅ boardDifficultyEnum referansları düzeltildi") → logSuccess("boardDifficultyEnum referansları düzeltildi")
print("❌ Hata: \(error)") → logError("Hata: \(error)")
```

### fix_duplicate.swift
```swift
print("✅ İkinci difficultyValue3 değişkeni difficultyValue4 olarak değiştirildi!") → logSuccess("İkinci difficultyValue3 değişkeni difficultyValue4 olarak değiştirildi!")
print("❌ Hata: \(error)") → logError("Hata: \(error)")
```

### fix_sudoku.swift
```swift
print("✅ SudokuViewModel.swift başarıyla düzeltildi!") → logSuccess("SudokuViewModel.swift başarıyla düzeltildi!")
print("❌ Hata: \(error)") → logError("Hata: \(error)")
```

### SudokuViewModel.swift
```swift
print("🆕 İlk çalıştırma, otomatik kaydetme devre dışı") → logInfo("İlk çalıştırma, otomatik kaydetme devre dışı")
print("🔄 Yeni oyun başlatıldı, otomatik kaydetme etkinleştirildi") → logInfo("Yeni oyun başlatıldı, otomatik kaydetme etkinleştirildi")
print("Hücre seçili değil!") → logWarning("Hücre seçili değil!")
print("setValueAtSelectedCell: \(value ?? 0) -> (\(row), \(col)), pencilMode: \(pencilMode)") → logDebug("setValueAtSelectedCell: \(value ?? 0) -> (\(row), \(col)), pencilMode: \(pencilMode)")
print("Sabit hücre değiştirilemez: (\(row), \(col))") → logWarning("Sabit hücre değiştirilemez: (\(row), \(col))")
print("Hücre zaten doğru değere sahip: \(currentValue!)") → logDebug("Hücre zaten doğru değere sahip: \(currentValue!)")
print("❌ Oyun kaybedildi! Kayıtlı oyun silindi.") → logError("Oyun kaybedildi! Kayıtlı oyun silindi.")
print("✅ Tamamlanan oyun kayıtlardan silindi") → logSuccess("Tamamlanan oyun kayıtlardan silindi")
print("📱 Oyun tamamlandı! handleGameCompletion() çağrılıyor...") → logInfo("Oyun tamamlandı! handleGameCompletion() çağrılıyor...")
print("Game completed!") → logSuccess("Game completed!")
print("✅ Oyun tamamlandı olarak işaretlendi!") → logSuccess("Oyun tamamlandı olarak işaretlendi!")
print("🔄 SavedGames yenileme bildirimi gönderildi") → logInfo("SavedGames yenileme bildirimi gönderildi")
print("Değer giriliyor: \(value ?? 0) -> (\(row), \(col))") → logDebug("Değer giriliyor: \(value ?? 0) -> (\(row), \(col))")
print("setValue sonucu: \(success)") → logDebug("setValue sonucu: \(success)")
print("Not eklendi/çıkarıldı: \(value) -> (\(row), \(col)), notlar: \(board.getPencilMarks(at: row, col: col))") → logDebug("Not eklendi/çıkarıldı: \(value) -> (\(row), \(col)), notlar: \(board.getPencilMarks(at: row, col: col))")
print("Tüm notlar temizlendi: (\(row), \(col))") → logDebug("Tüm notlar temizlendi: (\(row), \(col))")
print("saveGame fonksiyonu çalıştı") → logDebug("saveGame fonksiyonu çalıştı")
print("Oyun tamamlandığı veya başarısız olduğu için kaydedilmiyor") → logInfo("Oyun tamamlandığı veya başarısız olduğu için kaydedilmiyor")
print("JSON veri boyutu: \(jsonData.count) byte") → logDebug("JSON veri boyutu: \(jsonData.count) byte")
print("Mevcut oyun güncelleniyor, ID: \(gameID)") → logInfo("Mevcut oyun güncelleniyor, ID: \(gameID)")
print("✅ Oyun başarıyla güncellendi, ID: \(gameID)") → logSuccess("Oyun başarıyla güncellendi, ID: \(gameID)")
print("Yeni oyun kaydediliyor") → logInfo("Yeni oyun kaydediliyor")
print("✅ Yeni oyun başarıyla kaydedildi, ID: \(newGameID)") → logSuccess("Yeni oyun başarıyla kaydedildi, ID: \(newGameID)")
print("Kaydetme işlemi tamamlandı") → logInfo("Kaydetme işlemi tamamlandı")
print("❌ JSON oluşturma veya kaydetme hatası: \(error)") → logError("JSON oluşturma veya kaydetme hatası: \(error)")
print("⏭️ Otomatik kaydetme devre dışı, işlem atlanıyor") → logInfo("Otomatik kaydetme devre dışı, işlem atlanıyor")
print("⏭️ Otomatik kaydetme atlandı (oyun çok yeni başladı veya hamle yapılmadı)") → logInfo("Otomatik kaydetme atlandı (oyun çok yeni başladı veya hamle yapılmadı)")
print("💾 Otomatik kaydetme başladı...") → logInfo("Otomatik kaydetme başladı...")
print("✅ Otomatik kaydetme tamamlandı.") → logSuccess("Otomatik kaydetme tamamlandı.")
print("ℹ️ Oyun \(gameState) durumunda olduğu için otomatik kaydedilmedi.") → logInfo("Oyun \(gameState) durumunda olduğu için otomatik kaydedilmedi.")
print("Kayıtlı oyun yükleniyor: \(savedGame)") → logInfo("Kayıtlı oyun yükleniyor: \(savedGame)")
print("🔄 Kayıtlı oyun yükleniyor, otomatik kaydetme etkinleştirildi") → logInfo("Kayıtlı oyun yükleniyor, otomatik kaydetme etkinleştirildi")
print("❌ Oyun verisi bulunamadı") → logError("Oyun verisi bulunamadı")
print("Kaydedilmiş oyun ID'si ayarlandı: \(gameID)") → logDebug("Kaydedilmiş oyun ID'si ayarlandı: \(gameID)")
print("Kaydedilmiş oyun ID'si (string'den) ayarlandı: \(gameID)") → logDebug("Kaydedilmiş oyun ID'si (string'den) ayarlandı: \(gameID)")
print("Kaydedilmiş oyun için yeni ID oluşturuldu: \(self.currentGameID!)") → logDebug("Kaydedilmiş oyun için yeni ID oluşturuldu: \(self.currentGameID!)")
print("Kayıtlı oyun yükleniyor, zorluk seviyesi: \(difficultyString)") → logInfo("Kayıtlı oyun yükleniyor, zorluk seviyesi: \(difficultyString)")
print("❌ Oyun tahta verisi yüklenemedi") → logError("Oyun tahta verisi yüklenemedi")
print("⚠️ userEnteredValues boş, tahta üzerinden hesaplanıyor") → logWarning("userEnteredValues boş, tahta üzerinden hesaplanıyor")
print("✅ Kullanıcı tarafından girilen değerler yüklendi: \(self.userEnteredValues.flatMap { $0.filter { $0 } }.count) değer") → logSuccess("Kullanıcı tarafından girilen değerler yüklendi: \(self.userEnteredValues.flatMap { $0.filter { $0 } }.count) değer")
print("✅ Oyun istatistikleri güncellendi") → logSuccess("Oyun istatistikleri güncellendi")
print("ℹ️ userEnteredValues zaten loadBoardFromData fonksiyonundan alındı - tekrar yüklemeye gerek yok") → logInfo("userEnteredValues zaten loadBoardFromData fonksiyonundan alındı - tekrar yüklemeye gerek yok")
print("⚠️ İstatistikleri yüklerken hata: \(error)") → logWarning("İstatistikleri yüklerken hata: \(error)")
print("✅ İstatistikler başarıyla yüklendi") → logSuccess("İstatistikler başarıyla yüklendi")
print("⚠️ İstatistikler yüklenemedi: \(error)") → logWarning("İstatistikler yüklenemedi: \(error)")
print("✅ Oyun başarıyla yüklendi, ID: \(currentGameID?.uuidString ?? "ID yok")") → logSuccess("Oyun başarıyla yüklendi, ID: \(currentGameID?.uuidString ?? "ID yok")")
```

### SecurityManager.swift
```swift
print("✅ Resim yerel olarak kaydedildi") → logSuccess("Resim yerel olarak kaydedildi")
print("❌ Resim yerel olarak kaydedilemedi: \(error)") → logError("Resim yerel olarak kaydedilemedi: \(error)")
print("❌ Geçersiz Cloudinary URL: \(uploadURL)") → logError("Geçersiz Cloudinary URL: \(uploadURL)")
print("🚀 Cloudinary'ye yükleme başlatılıyor: \(uploadURL)") → logInfo("Cloudinary'ye yükleme başlatılıyor: \(uploadURL)")
print("👤 Kullanıcı: \(userId)") → logInfo("Kullanıcı: \(userId)")
print("🔑 Preset: \(uploadPreset)") → logInfo("Preset: \(uploadPreset)")
print("🏷️ Benzersiz profil resmi ID: \(uniquePublicId)") → logInfo("Benzersiz profil resmi ID: \(uniquePublicId)")
print("❌ Cloudinary yükleme hatası: \(error.localizedDescription)") → logError("Cloudinary yükleme hatası: \(error.localizedDescription)")
print("📡 Cloudinary yanıt kodu: \(httpResponse.statusCode)") → logDebug("Cloudinary yanıt kodu: \(httpResponse.statusCode)")
print("📋 Yanıt başlıkları:") → logDebug("Yanıt başlıkları:")
print("\(key): \(value)") → logVerbose("\(key): \(value)")
print("❌ Başarısız yanıt kodu: \(httpResponse.statusCode)") → logError("Başarısız yanıt kodu: \(httpResponse.statusCode)")
print("❌ Yanıt verisi boş") → logError("Yanıt verisi boş")
print("📄 Cloudinary yanıtı: \(responseString)") → logDebug("Cloudinary yanıtı: \(responseString)")
print("✅ JSON yanıtı alındı") → logSuccess("JSON yanıtı alındı")
print("🔗 Yüklenen resim URL: \(secureUrl)") → logInfo("Yüklenen resim URL: \(secureUrl)")
print("✅ Resim URL'si CoreData'ya kaydedildi") → logSuccess("Resim URL'si CoreData'ya kaydedildi")
print("🔄 Profil resmi URL'si Firebase'e gönderiliyor...") → logInfo("Profil resmi URL'si Firebase'e gönderiliyor...")
print("❌ Firebase profil resmi güncelleme hatası: \(error.localizedDescription)") → logError("Firebase profil resmi güncelleme hatası: \(error.localizedDescription)")
print("✅ Profil resmi URL'si Firebase'e kaydedildi") → logSuccess("Profil resmi URL'si Firebase'e kaydedildi")
print("⚠️ Kullanıcının Firebase UID'si yok, Firebase güncellemesi yapılamadı") → logWarning("Kullanıcının Firebase UID'si yok, Firebase güncellemesi yapılamadı")
print("❌ CoreData kayıt hatası: \(error.localizedDescription)") → logError("CoreData kayıt hatası: \(error.localizedDescription)")
print("❌ JSON'da secure_url alanı bulunamadı") → logError("JSON'da secure_url alanı bulunamadı")
print("❌ Cloudinary hata detayı: \(error)") → logError("Cloudinary hata detayı: \(error)")
print("❌ Yanıt JSON formatında değil") → logError("Yanıt JSON formatında değil")
print("❌ JSON ayrıştırma hatası: \(error.localizedDescription)") → logError("JSON ayrıştırma hatası: \(error.localizedDescription)")
```

### SudokuApp.swift
```swift
print("📱 Sudoku app initializing...") → logInfo("Sudoku app initializing...")
print("📊 Debug mode active") → logDebug("Debug mode active")
print("🔋 Power Saving Manager initialized") → logInfo("Power Saving Manager initialized")
print("✅ AchievementManager başlatıldı") → logSuccess("AchievementManager başlatıldı")
print("🔄 Uygulama \(Int(timeSinceBackground)) saniye sonra geri döndü - Splash ekranı gösterilecek") → logInfo("Uygulama \(Int(timeSinceBackground)) saniye sonra geri döndü - Splash ekranı gösterilecek")
print("✅ Oyunlar başarıyla senkronize edildi") → logSuccess("Oyunlar başarıyla senkronize edildi")
print("⚠️ Oyun senkronizasyonunda sorun oluştu") → logWarning("Oyun senkronizasyonunda sorun oluştu")
print("🔄 Uygulama arka plana alındı: \(Date())") → logInfo("Uygulama arka plana alındı: \(Date())")
print("✅ Firebase yapılandırması başarıyla tamamlandı") → logSuccess("Firebase yapılandırması başarıyla tamamlandı")
print("⚠️ Firebase zaten yapılandırılmış") → logWarning("Firebase zaten yapılandırılmış")
print("👤 Kullanıcı çıkış yaptı") → logInfo("Kullanıcı çıkış yaptı")
print("👤 Kullanıcı giriş yaptı: \(user.username ?? "N/A")") → logInfo("Kullanıcı giriş yaptı: \(user.username ?? "N/A")")
print("🔆 GameScreenOpened bildirim alındı - GameView tarafından ekran kararması engelleniyor") → logInfo("GameScreenOpened bildirim alındı - GameView tarafından ekran kararması engelleniyor")
print("🔅 GameScreenClosed bildirim alındı - Ekran kararması GameView tarafından etkinleştirildi") → logInfo("GameScreenClosed bildirim alındı - Ekran kararması GameView tarafından etkinleştirildi")
```

### MainMenuView.swift
```swift
print("📱 ReturnToMainMenu bildirimi alındı - Ana sayfaya dönülüyor") → logInfo("ReturnToMainMenu bildirimi alındı - Ana sayfaya dönülüyor")
print("🔊 Ana sayfaya yönlendiriliyor (zaman aşımı sonrası)") → logInfo("Ana sayfaya yönlendiriliyor (zaman aşımı sonrası)")
print("Son kaydedilmiş oyun yükleniyor... ID: \(lastGame.value(forKey: "id") ?? "ID yok")") → logInfo("Son kaydedilmiş oyun yükleniyor... ID: \(lastGame.value(forKey: "id") ?? "ID yok")")
print("Kaydedilmiş oyun bulunamadı, yeni oyun başlatılıyor") → logInfo("Kaydedilmiş oyun bulunamadı, yeni oyun başlatılıyor")
print("Yükleme hatası: \(error)") → logError("Yükleme hatası: \(error)")
```

### ContentView.swift
```swift
print("📱 ContentView onAppear - Device: \(UIDevice.current.model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)") → logInfo("ContentView onAppear - Device: \(UIDevice.current.model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
```

### PersistenceController.swift
```swift
print("✅ [\(deviceID)] Profil resmi yerel veritabanına kaydedildi: \(dataHash)") → logSuccess("[\(deviceID)] Profil resmi yerel veritabanına kaydedildi: \(dataHash)")
print("❌ [\(deviceID)] Profil resmi yerel olarak kaydedilemedi: \(error.localizedDescription)") → logError("[\(deviceID)] Profil resmi yerel olarak kaydedilemedi: \(error.localizedDescription)")
print("❌ Kullanıcı e-postası aranırken hata: \(error.localizedDescription)") → logError("Kullanıcı e-postası aranırken hata: \(error.localizedDescription)")
print("⚠️ Firebase Firestore devre dışı: Oyun sadece yerel veritabanına kaydedildi") → logWarning("Firebase Firestore devre dışı: Oyun sadece yerel veritabanına kaydedildi")
print("⚠️ Firebase Firestore devre dışı: Oyun senkronizasyonu yapılamadı") → logWarning("Firebase Firestore devre dışı: Oyun senkronizasyonu yapılamadı")
print("❌ ID ile oyun getirme hatası: \(error.localizedDescription)") → logError("ID ile oyun getirme hatası: \(error.localizedDescription)")
print("⚠️ Firestore oyunları getirilemedi: Kullanıcı giriş yapmamış") → logWarning("Firestore oyunları getirilemedi: Kullanıcı giriş yapmamış")
print("✅ Firestore'dan \(games.count) oyun yüklendi") → logSuccess("Firestore'dan \(games.count) oyun yüklendi")
print("❌ Firestore yüksek skor sorgulama hatası: \(error.localizedDescription)") → logError("Firestore yüksek skor sorgulama hatası: \(error.localizedDescription)")
print("ℹ️ Firestore'da \(difficulty) zorluğunda yüksek skor bulunamadı") → logInfo("Firestore'da \(difficulty) zorluğunda yüksek skor bulunamadı")
print("✅ Firestore'dan \(scores.count) yüksek skor yüklendi") → logSuccess("Firestore'dan \(scores.count) yüksek skor yüklendi")
print("⚠️ Firestore kullanıcı skorları getirilemedi: Kullanıcı ID'si yok") → logWarning("Firestore kullanıcı skorları getirilemedi: Kullanıcı ID'si yok")
print("❌ Firestore kullanıcı skorları sorgulama hatası: \(error.localizedDescription)") → logError("Firestore kullanıcı skorları sorgulama hatası: \(error.localizedDescription)")
print("ℹ️ Firestore'da kullanıcı için skor bulunamadı") → logInfo("Firestore'da kullanıcı için skor bulunamadı")
print("✅ Firestore'dan \(scores.count) kullanıcı skoru yüklendi") → logSuccess("Firestore'dan \(scores.count) kullanıcı skoru yüklendi")
print("⚠️ Yüksek skorlar getirilemedi: Kullanıcı giriş yapmamış") → logWarning("Yüksek skorlar getirilemedi: Kullanıcı giriş yapmamış")
print("🔄 Yüksek skorlar Firestore'dan senkronize ediliyor...") → logInfo("Yüksek skorlar Firestore'dan senkronize ediliyor...")
print("❌ Firestore skor sorgulama hatası: \(error.localizedDescription)") → logError("Firestore skor sorgulama hatası: \(error.localizedDescription)")
print("❌ Firestore tamamlanmış oyun silme hatası: \(error.localizedDescription)") → logError("Firestore tamamlanmış oyun silme hatası: \(error.localizedDescription)")
print("✅ \(documents.count) tamamlanmış oyun Firestore'dan silindi") → logSuccess("\(documents.count) tamamlanmış oyun Firestore'dan silindi")
print("⚠️ Tamamlanmış oyunlar senkronize edilemedi: Kullanıcı giriş yapmamış") → logWarning("Tamamlanmış oyunlar senkronize edilemedi: Kullanıcı giriş yapmamış")
print("🔄 Tamamlanmış oyunlar Firestore'dan senkronize ediliyor...") → logInfo("Tamamlanmış oyunlar Firestore'dan senkronize ediliyor...")
print("❌ Firestore tamamlanmış oyun sorgulama hatası: \(error.localizedDescription)") → logError("Firestore tamamlanmış oyun sorgulama hatası: \(error.localizedDescription)")
print("ℹ️ Firestore'da tamamlanmış oyun bulunamadı") → logInfo("Firestore'da tamamlanmış oyun bulunamadı")
print("📊 Bulunan tamamlanmış oyun sayısı: \(documents.count)") → logInfo("Bulunan tamamlanmış oyun sayısı: \(documents.count)")
print("⏭️ ID: \(documentID) olan tamamlanmış oyun yakın zamanda silinmiş. Atlanıyor.") → logInfo("ID: \(documentID) olan tamamlanmış oyun yakın zamanda silinmiş. Atlanıyor.")
print("✅ Tamamlanmış oyun istatistikleri güncellendi: \(stats)") → logSuccess("Tamamlanmış oyun istatistikleri güncellendi: \(stats)")
print("ℹ️ Doğrulanacak silinen belge yok") → logInfo("Doğrulanacak silinen belge yok")
print("⚠️ Tamamlanmış oyun hala mevcut: \(documentID)") → logWarning("Tamamlanmış oyun hala mevcut: \(documentID)")
print("✅ Tamamlanmış oyun başarıyla silindi: \(documentID)") → logSuccess("Tamamlanmış oyun başarıyla silindi: \(documentID)")
print("🔄 \(gamesIDs.count) adet silinemeyen oyunu tekrar silmeyi deniyorum...") → logInfo("\(gamesIDs.count) adet silinemeyen oyunu tekrar silmeyi deniyorum...")
print("❌ İkinci silme denemesi başarısız: \(error.localizedDescription)") → logError("İkinci silme denemesi başarısız: \(error.localizedDescription)")
print("✅ İkinci silme denemesi başarılı!") → logSuccess("İkinci silme denemesi başarılı!")
print("✅ Tüm tamamlanmış oyunlar başarıyla silindi!") → logSuccess("Tüm tamamlanmış oyunlar başarıyla silindi!")
print("⚠️ \(failedDeletions.count) tamamlanmış oyun silinemedi: \(failedDeletions)") → logWarning("\(failedDeletions.count) tamamlanmış oyun silinemedi: \(failedDeletions)")
```
print("📢 Dil değişikliği algılandı - ContentView yenileniyor") → logInfo("Dil değişikliği algılandı - ContentView yenileniyor")
```

### fix_difficulty.swift
```swift
print("✅ difficulty2Value değişkeni başarıyla düzeltildi!") → logSuccess("difficulty2Value değişkeni başarıyla düzeltildi!")
print("❌ Hata: \(error)") → logError("Hata: \(error)")
```

## Dönüşüm Sonrası Beklenen Faydalar

1. **Performans İyileştirmesi**: Üretim modunda gereksiz loglar gösterilmeyecek, bu da performansı artıracak.
2. **Daha İyi Hata Ayıklama**: Her log, hangi dosyadan, hangi fonksiyondan ve hangi satırdan geldiğini gösterecek.
3. **Merkezi Yönetim**: Tüm loglar merkezi bir sistem üzerinden yönetilebilecek.
4. **Seviye Bazlı Filtreleme**: Log seviyelerini ayarlayarak hangi tür logların görüntüleneceğini kontrol edebilirsiniz.

## Dönüşüm Sonrası Yapılması Gerekenler

1. Tüm dönüşümleri yaptıktan sonra uygulamayı test edin.
2. Performans sorunlarının çözülüp çözülmediğini kontrol edin.
3. Gerekirse log seviyelerini ayarlayın.
