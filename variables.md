# Sudoku Uygulaması Değişken ve Fonksiyon Dokümantasyonu

Bu dokümantasyon, Sudoku uygulamasındaki tüm dosyaları, değişkenleri ve fonksiyonları açıklamaktadır. Her dosya için değişkenler ve fonksiyonlar, satır numaraları ve kullanım amaçlarıyla birlikte listelenmiştir.

## İçindekiler

1. [ContentView.swift](#contentviewswift) - Ana uygulama görünümü
2. [SudokuViewModel.swift](#sudokuviewmodelswift) - Oyun mantığı ve durum yönetimi
3. [PersistenceController.swift](#persistencecontrollerswift) - Veri kalıcılığı ve CoreData yönetimi
4. [SudokuBoard.swift](#sudokuboardswift) - Sudoku tahtası veri modeli
5. [SudokuBoardView.swift](#sudokuboardviewswift) - Tahta görsel bileşeni
6. [GameView.swift](#gameviewswift) - Oyun ekranı
7. [MainMenuView.swift](#mainmenuviewswift) - Ana menü
8. [SavedGamesView.swift](#savedgamesviewswift) - Kaydedilmiş oyunlar ekranı
9. [ScoreboardView.swift](#scoreboardviewswift) - Skor tablosu
10. [SettingsView.swift](#settingsviewswift) - Ayarlar ekranı
11. [SudokuCellView.swift](#sudokucellviewswift) - Sudoku hücre görünümü
12. [NumberPadView.swift](#numberpadviewswift) - Sayı tuş takımı
13. [GameCompletionView.swift](#gamecompletionviewswift) - Oyun tamamlama ekranı
14. [PencilMarksView.swift](#pencilmarksviewswift) - Kalem işaretleri görünümü
15. [ScoreManager.swift](#scoremanagerswift) - Skor yönetimi
16. [PowerSavingManager.swift](#powersavingmanagerswift) - Güç tasarrufu yönetimi
17. [TutorialManager.swift](#tutorialmanagerswift) - Öğretici yönetimi
18. [LoginView.swift](#loginviewswift) - Giriş ekranı
19. [RegisterView.swift](#registerviewswift) - Kayıt ekranı
20. [TutorialView.swift](#tutorialviewswift) - Öğretici ekranı
21. [ColorExtension.swift](#colorextensionswift) - Renk uzantıları
22. [ViewTransitionExtension.swift](#viewtransitionextensionswift) - Görünüm geçiş uzantıları
23. [SudokuApp.swift](#sudokuappswift) - Uygulama giriş noktası

---

## ContentView.swift

ContentView, uygulamanın ana görünümüdür ve diğer tüm görünümleri yönetir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewContext` | 49 | `NSManagedObjectContext` | CoreData yönetilen nesne bağlamı |
| `colorScheme` | 50 | `ColorScheme` | Uygulamanın renk şeması (açık/karanlık mod) |
| `gameToLoad` | 53 | `NSManagedObject?` | Yüklenecek kaydedilmiş oyun |
| `showSavedGame` | 54 | `Bool` | Kaydedilmiş oyun ekranının gösterilip gösterilmediğini kontrol eder |
| `viewModel` | 56 | `SudokuViewModel` | Sudoku oyun mantığını yöneten view model |
| `currentPage` | 57 | `AppPage` | Şu anda görüntülenen sayfa (ana sayfa, skor tablosu, vb.) |
| `selectedDifficulty` | 59 | `Int` | Kullanıcının seçtiği zorluk seviyesi indeksi |
| `hasSeenTutorial` | 60 | `Bool` | Kullanıcının öğreticiyi görüp görmediğini belirtir |
| `powerSavingMode` | 61 | `Bool` | Güç tasarrufu modunun etkin olup olmadığını belirtir |
| `showGame` | 63 | `Bool` | Oyun ekranının gösterilip gösterilmediğini kontrol eder |
| `showTutorial` | 64 | `Bool` | Öğretici ekranının gösterilip gösterilmediğini kontrol eder |
| `showTutorialPrompt` | 65 | `Bool` | Öğretici isteminin gösterilip gösterilmediğini kontrol eder |
| `selectedCustomDifficulty` | 66 | `SudokuBoard.Difficulty` | Özel seçilen zorluk seviyesi |
| `isLoading` | 68 | `Bool` | Yükleme durumunu kontrol eder |
| `loadError` | 69 | `Error?` | Yükleme hatası |
| `titleScale` | 72 | `CGFloat` | Başlık ölçek animasyonu için |
| `titleOpacity` | 73 | `CGFloat` | Başlık opasite animasyonu için |
| `buttonsOffset` | 74 | `CGFloat` | Düğme ofset animasyonu için |
| `buttonsOpacity` | 75 | `CGFloat` | Düğme opasite animasyonu için |
| `rotationDegree` | 76 | `Double` | Döndürme animasyonu için |
| `logoNumbers` | 77 | `[Int]` | Logo animasyonu için sayılar |
| `animatingCellIndex` | 78 | `Int` | Animasyon yapılan hücre indeksi |
| `cellAnimationProgress` | 79 | `CGFloat` | Hücre animasyon ilerlemesi |
| `ContentViewTimeoutManager.shared` | 169 | `ContentViewTimeoutManager` | Zaman aşımı bildirimlerini işlemek için kullanılan singleton sınıf |
| `ContentViewTimeoutManager.isProcessing` | 170 | `Bool` | Zaman aşımı işleminin devam edip etmediğini kontrol eder |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `difficultyIcon(for:)` | 86-94 | Zorluk seviyesi için ikon seçer |
| `difficultyColor(for:)` | 97-103 | Zorluk seviyesi için renk seçer |
| `init()` | 108-114 | ContentView'ı başlatır ve TabBar görünümünü ayarlar |
| `setupSavedGameNotification()` | 117-164 | Kaydedilmiş oyunlarla ilgili bildirim dinleyicilerini ayarlar |
| `setupTimeoutNotification()` | 175-226 | Zaman aşımı bildirimlerini dinlemek için gözlemci ayarlar |
| `titleView` | 229-268 | Başlık görünümünü oluşturur |
| `continueGameButton` | 271-369 | Son kaydedilen oyunu yüklemek için kullanılan düğmeyi oluşturur |
| `gameModesSection` | 372-668 | Oyun modları bölümünü oluşturur (zorluk seviyeleri) |
| `mainContentView` | 672-760 | Ana içerik görünümünü oluşturur |
| `body` | 763-898 | Ana görünümü oluşturur ve bildirim ayarlarını yapar |
| `getSafeAreaBottom()` | 917-926 | Ekranın alt kısmındaki güvenli alan yüksekliğini döndürür |


---

## SudokuViewModel.swift

SudokuViewModel, Sudoku oyununun tüm mantığını yöneten sınıftır. Oyun durumu, zamanlayıcı, ipuçları, kalem işaretleri ve CoreData entegrasyonu dahil tüm oyun işlevselliğinden sorumludur.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `board` | 13 | `SudokuBoard` | Sudoku tahtasını temsil eden model |
| `selectedCell` | 15 | `(row: Int, column: Int)?` | Şu anda seçili olan hücre (satır, sütun) |
| `invalidCells` | 17 | `Set<Position>` | Geçersiz hücrelerin kümesi |
| `elapsedTime` | 19 | `TimeInterval` | Oyunda geçen süre (saniye cinsinden) |
| `gameState` | 21 | `GameState` | Oyunun mevcut durumu (ready, playing, paused, completed, failed) |
| `pencilMode` | 23 | `Bool` | Kalem modunun (not alma modu) etkin olup olmadığını belirtir |
| `pencilMarkCache` | 26 | `[String: Set<Int>]` | Performans iyileştirmesi için kullanılan kalem işaretleri önbelleği |
| `validValuesCache` | 27 | `[String: Set<Int>]` | Performans iyileştirmesi için kullanılan geçerli değerler önbelleği |
| `lastSelectedCell` | 28 | `(row: Int, column: Int)?` | Önceki seçilen hücreyi takip eder |
| `userEnteredValues` | 31 | `[[Bool]]` | 9x9 matris ile kullanıcının girdiği hücreleri takip eder |
| `moveCount` | 34 | `Int` | Kullanıcının yaptığı hamle sayısı - istatistik için |
| `errorCount` | 35 | `Int` | Kullanıcının yaptığı hata sayısı - 3 olduğunda oyun kaybedilir |
| `hintCount` | 36 | `Int` | Kullanıcının kullandığı ipucu sayısı |
| `remainingHints` | 37 | `Int` | Oyun başına 3 olan kalan ipucu sayısı |
| `maxErrorCount` | 38 | `Int` | Maksimum hata sayısı (3) |
| `timer` | 41 | `Timer?` | Oyun süresini takip eden zamanlayıcı |
| `startTime` | 42 | `Date?` | Oyunun başlangıç zamanı |
| `pausedElapsedTime` | 44 | `TimeInterval` | Duraklatıldığında geçen süreyi saklar |
| `enableHapticFeedback` | 74 | `Bool` | Dokunsal geri bildirimin etkin olup olmadığı (AppStorage ile depolanır) |
| `enableSounds` | 75 | `Bool` | Seslerin etkin olup olmadığı (AppStorage ile depolanır) |
| `playerName` | 76 | `String` | Kullanıcının adı (AppStorage ile depolanır) |
| `feedbackGenerator` | 79 | `UIImpactFeedbackGenerator` | Dokunsal geri bildirim motoru - titreşim için |
| `GameState` | 82-84 | `enum` | Oyun durumları (ready, playing, paused, completed, failed) |
| `savedGames` | 87 | `[NSManagedObject]` | Kaydedilmiş oyunlar listesi - CoreData ile yönetilir |
| `usedNumbers` | 90 | `[Int: Int]` | Tahtada hangi rakamın kaç kez kullanıldığını gösterir |
| `backgroundEntryTime` | ~1650 | `Date?` | Uygulamanın arka plana alındığı zaman - arka plan zamanlayıcısı için |
| `backgroundSaveTimer` | ~1660 | `Timer?` | Arka plan zamanlayıcısı - 2 dakika sonra oyunu otomatik kaydetmek için |
| `currentGameID` | 1171 | `UUID?` | Mevcut oyunun benzersiz kimliği - CoreData ile senkronizasyon için |
| `hintExplanationData` | ~580 | `HintData?` | İpucu açıklama verileri - kullanıcıya ipucu gösterirken kullanılır |
| `appState` | ~1750 | `AppState` | Uygulamanın durumunu izler (foreground, background) |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `resetGameState()` | 47-71 | Tüm istatistikleri ve oyun durumunu sıfırlar |
| `init(difficulty:)` | 94-100 | Belirli zorlukta ViewModel'i başlatır ve bildirim gözlemcilerini ayarlar |
| `setupNotificationObservers()` | ~105 | Uygulama durum değişikliklerini dinlemek için bildirimleri ayarlar |
| `newGame(difficulty:)` | 111-137 | Belirtilen zorluk seviyesinde yeni bir oyun başlatır |
| `selectCell(row:column:)` | 140-154 | Belirtilen hücreyi seçer ve dokunsal geri bildirim sağlar |
| `setValueAtSelectedCell(_:)` | 157-170 | Seçili hücreye değer atar, doğruluk kontrolü yapar |
| `togglePencilMark(at:col:value:)` | ~300 | Belirli bir hücrede kalem işaretini açar/kapatır |
| `useHint()` | ~550 | Kullanıcıya bir ipucu sağlar ve kalan ipucu sayısını azaltır |
| `checkGameCompletion()` | ~600 | Oyunun tamamlanıp tamamlanmadığını kontrol eder |
| `togglePause()` | ~650 | Oyunu duraklatır veya devam ettirir |
| `startTimer()` | ~700 | Oyun zamanlayıcısını başlatır |
| `stopTimer()` | ~750 | Oyun zamanlayıcısını durdurur |
| `saveGame(forceNewSave:)` | 1174-1210 | Mevcut oyun durumunu CoreData'ya kaydeder |
| `loadGame(from:)` | 1288-1366 | CoreData'dan bir oyunu yükler |
| `loadBoardFromData(_:)` | 1396-1589 | JSON verilerinden tahta durumunu yükler |
| `deleteSavedGame(_:)` | ~1600 | Kaydedilmiş bir oyunu siler |
| `pauseGameFromBackground()` | 1734-1738 | Uygulama arka plana alındığında oyunu duraklatır |
| `setupBackgroundTimer()` | ~1740 | Arka plan zamanlayıcısını ayarlar (2 dakika) |
| `cancelBackgroundTimer()` | ~1780 | Arka plan zamanlayıcısını iptal eder |
| `resetGameAfterTimeout()` | 1788-1820 | Zaman aşımından sonra oyunu kaydeder ve sıfırlar |
| `shouldSaveGameAfterTimeout()` | 1850-1866 | Zaman aşımından sonra oyunun kaydedilmeye uygun olup olmadığını kontrol eder (en az 1 dk oynanmış ve 1 hamle yapılmış olmalı) |
| `createGameStateJSONForTimeout()` | 1888-1900 | Zaman aşımı için oyun durumunu JSON'a dönüştürür |

### Önemli Özellikler

#### Arka Plan Davranışı
- Uygulama arka plana alındığında otomatik olarak duraklatılır
- Arka planda 2 dakika veya daha uzun süre kalırsa, oyun otomatik olarak kayıtlara eklenir
- Oyunun otomatik kaydedilebilmesi için en az 1 dakika oynanmış ve en az 1 hamle yapılmış olması gerekir
- Kaydedilen oyun "(Arka Plan)" eki ile kaydedilir

#### İpucu Sistemi
- Her oyunda 3 ipucu hakkı vardır
- İpuçları çeşitli zorluk seviyelerinde sunulur (nakedSingle, hiddenSingle, vb.)
- İpuçları adım adım açıklamalarla sunulur

#### Performans Optimizasyonu
- Kalem işaretleri ve geçerli değerler için önbellek kullanımı
- Dokunsal geri bildirim ve ses efektleri için AppStorage kullanımı
- Verimli JSON serileştirme ve CoreData entegrasyonu

---

## PersistenceController.swift

PersistenceController, CoreData ile veri kalıcılığını yöneten sınıftır.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `shared` | ~10 | `PersistenceController` | Singleton örneği |
| `container` | ~15 | `NSPersistentContainer` | CoreData kalıcı konteyner |
| `viewContext` | ~20 | `NSManagedObjectContext` | Ana yönetilen nesne bağlamı |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init(inMemory:)` | ~25 | Kalıcılık denetleyicisini başlatır |
| `getAllSavedGames()` | 103-110 | Tüm kayıtlı oyunları getirir |
| `saveGame(gameID:board:difficulty:elapsedTime:jsonData:)` | ~120 | Yeni bir oyun kaydeder |
| `updateSavedGame(gameID:board:difficulty:elapsedTime:jsonData:)` | ~150 | Mevcut bir oyunu günceller |
| `deleteSavedGame(_:)` | ~180 | Bir oyunu siler |
| `deleteAllSavedGames()` | ~200 | Tüm kayıtlı oyunları siler |
| `updateGameDifficulty(gameID:newDifficulty:)` | ~220 | Bir oyunun zorluk seviyesini günceller |

---

## SudokuBoard.swift

SudokuBoard, Sudoku tahtasının veri modelidir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `board` | ~10 | `[[Int?]]` | Sudoku tahtasının mevcut durumunu temsil eden 2D dizi |
| `solution` | ~15 | `[[Int]]` | Sudoku bulmacasının çözümünü içeren 2D dizi |
| `fixedCells` | ~20 | `[[Bool]]` | Hangi hücrelerin sabit (başlangıçta verilen) olduğunu belirten 2D dizi |
| `difficulty` | ~25 | `Difficulty` | Sudoku bulmacasının zorluk seviyesi |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init(difficulty:)` | ~30 | Belirtilen zorluk seviyesinde yeni bir Sudoku tahtası oluşturur |
| `generateBoard(difficulty:)` | ~50 | Belirtilen zorluk seviyesinde bir Sudoku bulmacası oluşturur |
| `getValue(row:column:)` | ~100 | Belirtilen konumdaki değeri döndürür |
| `setValue(row:column:value:)` | ~110 | Belirtilen konuma bir değer atar |
| `isFixed(at:col:)` | ~120 | Belirtilen hücrenin sabit olup olmadığını kontrol eder |
| `getSolutionValue(row:column:)` | ~130 | Belirtilen konumdaki çözüm değerini döndürür |
| `isValidMove(row:column:value:)` | ~140 | Bir hamlenin geçerli olup olmadığını kontrol eder |
| `isBoardComplete()` | ~150 | Tahtanın tamamlanıp tamamlanmadığını kontrol eder |
| `getBoardArray()` | ~160 | Tahtayı 2D Int dizisi olarak döndürür |

---

## SudokuBoardView.swift

SudokuBoardView, oyun tahtasının görsel bileşenini oluşturan ve kullanıcı etkileşimlerini yöneten görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | 4 | `SudokuViewModel` | Oyun mantığını yöneten view model |
| `colorScheme` | 5 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `cellSize` | 8 | `CGFloat` | Hücre boyutu - performans için önbelleklenir |
| `gridSize` | 9 | `CGFloat` | Izgara boyutu - performans için önbelleklenir |
| `lastCalculatedFrame` | 10 | `CGRect` | Son hesaplanan çerçeve - gereksiz yeniden hesaplamaları önler |
| `cellPadding` | 13 | `CGFloat` | Hücre dolgu değeri |
| `boldLineWidth` | 14 | `CGFloat` | Kalın çizgi genişliği |
| `normalLineWidth` | 15 | `CGFloat` | Normal çizgi genişliği |
| `originalCellBackground` | 18 | `Color` | Orijinal hücre arka plan rengi |
| `selectedRowColBackground` | 19 | `Color` | Seçili satır/sütun arka plan rengi |
| `selectedCellBackground` | 20 | `Color` | Seçili hücre arka plan rengi |
| `matchingValueBackground` | 21 | `Color` | Eşleşen değer arka plan rengi |
| `invalidValueBackground` | 22 | `Color` | Geçersiz değer arka plan rengi |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 25-98 | Ana görünüm yapısını oluşturur, hücre boyutlarını ve geometrik hesaplamaları yapar |
| `updateSizes(from:cellSize:)` | 101-112 | Tahta boyutlarını günceller ve optimize eder |
| `gridOverlay` | 115-121 | Izgara çizgilerini çizer |
| `gridCellLines` | 124-146 | İnce hücre çizgilerini oluşturur |
| `gridLines` | 149-178 | Kalın ızgara çizgilerini oluşturur |
| `cellView(row:column:)` | 181-195 | Her bir hücreyi oluşturur ve özelliklerini belirler |
| `isHighlighted(row:column:)` | ~220 | Hücrenin vurgulanmış olup olmadığını kontrol eder |
| `hasSameValue(row:column:)` | ~240 | Hücrenin seçili hücre ile aynı değere sahip olup olmadığını kontrol eder |
| `isHintTargetCell(row:column:)` | ~260 | Hücrenin ipucu hedefi olup olmadığını kontrol eder |
| `pencilMarksView(row:column:)` | ~280 | Kalem işaretlerini görüntüleyen görünümü oluşturur |

### Önemli Özellikler

- Responsive tasarım: Farklı ekran boyutlarına uyum sağlar
- Performans optimizasyonu: `drawingGroup()`, önbellek kullanımı ve gereksiz yeniden hesaplamaları önler
- Katmanlı UI yapısı: Arka plan, hücreler ve çizgilerden oluşan katmanlar
- Karanlık/açık tema desteği: Renk şemasına göre farklı renklerçili satır/sütun arka plan rengi |
| `selectedCellBackground` | 20 | `Color` | Seçili hücre arka plan rengi |
| `matchingValueBackground` | 21 | `Color` | Eşleşen değer arka plan rengi |
| `invalidValueBackground` | 22 | `Color` | Geçersiz değer arka plan rengi |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 24-86 | Ana görünümü oluşturur |
| `updateSizes(from:cellSize:)` | 89-99 | Boyutları günceller - sabit bir hücre boyutu için optimize edilmiştir |
| `gridOverlay` | 102-110 | Izgara çizgilerini çizer |
| `gridCellLines` | 113-135 | İnce hücre çizgilerini çizer |
| `gridLines` | 138-164 | Kalın ızgara çizgilerini çizer |
| `cellView(row:column:)` | 167-215 | Hücre görünümünü oluşturur |
| `pencilMarksView(row:column:)` | 218-237 | Kalem işaretleri görünümünü oluşturur |
| `getCellBackgroundColor(row:column:isSelected:)` | 240-268 | Hücre arka plan rengini hesaplar |
| `getTextColor(isOriginal:isSelected:cellValue:)` | 271-283 | Metin rengini hesaplar |
| `isHintTargetCell(row:column:)` | 286-299 | Bir hücrenin ipucu hedefi olup olmadığını kontrol eder |
| `isHighlighted(row:column:)` | 302-317 | Bir hücrenin vurgulanmış olup olmadığını kontrol eder |
| `hasSameValue(row:column:)` | 320-332 | Bir hücrenin seçili hücreyle aynı değere sahip olup olmadığını kontrol eder |


---

## SudokuViewModel.swift

SudokuViewModel, Sudoku oyun mantığını yöneten ve kullanıcı etkileşimleri ile oyun durumunu takip eden sınıftır.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `board` | 13 | `SudokuBoard` | Sudoku tahtasının veri modeli |
| `selectedCell` | 15 | `(row: Int, column: Int)?` | Seçili hücrenin satır ve sütun bilgisi |
| `invalidCells` | 17 | `Set<Position>` | Geçersiz hücrelerin konumlarını içeren küme |
| `elapsedTime` | 19 | `TimeInterval` | Oyun süresini saniye cinsinden tutan değişken |
| `gameState` | 21 | `GameState` | Oyunun mevcut durumu (hazır, oynuyor, duraklatılmış, tamamlanmış, başarısız) |
| `pencilMode` | 23 | `Bool` | Kalem modunun aktif olup olmadığını belirten bayrak |
| `pencilMarkCache` | 26 | `[String: Set<Int>]` | Kalem işaretlerini önbellekte tutan sözlük |
| `validValuesCache` | 27 | `[String: Set<Int>]` | Geçerli değerleri önbellekte tutan sözlük |
| `lastSelectedCell` | 28 | `(row: Int, column: Int)?` | Son seçilen hücre bilgisi |
| `userEnteredValues` | 31 | `[[Bool]]` | Kullanıcının girdiği değerleri takip eden matris |
| `moveCount` | 34 | `Int` | Toplam hamle sayısı |
| `errorCount` | 35 | `Int` | Toplam hata sayısı |
| `hintCount` | 36 | `Int` | Kullanılan ipucu sayısı |
| `remainingHints` | 37 | `Int` | Kalan ipucu hakkı |
| `maxErrorCount` | 38 | `Int` | İzin verilen maksimum hata sayısı (3) |
| `timer` | 41 | `Timer?` | Oyun süresini takip eden zamanlayıcı |
| `startTime` | 42 | `Date?` | Oyunun başlangıç zamanı |
| `pausedElapsedTime` | 44 | `TimeInterval` | Duraklatıldığında saklanan geçen süre |
| `enableHapticFeedback` | 74 | `Bool` | Dokunsal geri bildirimin etkin olup olmadığı |
| `enableSounds` | 75 | `Bool` | Ses geri bildiriminin etkin olup olmadığı |
| `playerName` | 76 | `String` | Oyuncu adı |
| `feedbackGenerator` | 79 | `UIImpactFeedbackGenerator` | Dokunsal geri bildirim motoru |
| `savedGames` | 87 | `[NSManagedObject]` | Kaydedilmiş oyunların listesi |
| `usedNumbers` | 90 | `[Int: Int]` | Kullanılan rakamların sayısını takip eden sözlük |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `resetGameState()` | 47-71 | Oyun durumunu sıfırlar, yeni oyun başlatırken kullanılır |
| `init(difficulty:)` | 94-109 | Sınıfı belirtilen zorluk seviyesiyle başlatır |
| `newGame(difficulty:)` | 115-133 | Yeni bir oyun başlatır ve tüm değerleri sıfırlar |
| `selectCell(row:column:)` | 136-150 | Belirtilen hücreyi seçer ve dokunsal geri bildirim sağlar |
| `setValueAtSelectedCell(_:)` | 153-237 | Seçili hücreye değer atar, doğruluk kontrolü yapar ve hata durumunu yönetir |
| `checkGameCompletion()` | 242-258 | Oyunun tamamlanma durumunu kontrol eder |
| `validateBoard()` | 261-282 | Tüm tahtanın geçerliliğini kontrol eder ve geçersiz hücreleri işaretler |
| `invalidatePencilMarksCache(forRow:column:)` | 287-300 | Kalem işaretleri önbelleğini belirli bir bölge için geçersiz kılar |

### Önemli Özellikler

- **Otomatik Kaydetme**: Oyun arka plana alındıktan sonra 2 dakika veya daha uzun süre geçerse, oyun otomatik olarak kayıtlara eklenir ve ana menüye dönülür. Oyunun kayıtlara eklenebilmesi için en az 1 dakika oynanmış ve en az 1 hamle yapılmış olması gerekir. Oyun "(Arka Plan)" eki ile kaydedilir.
- **Performans Optimizasyonları**: Kalem işaretleri ve geçerli değerler için önbellekleme mekanizmaları kullanılır.
- **Hata Yönetimi**: Maksimum 3 hata yapılabilir, sonrasında oyun kaybedilir.
- **İpucu Sistemi**: Her oyunda 3 ipucu hakkı vardır.

---

## GameView.swift

GameView, oyun ekranının görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | ~10 | `SudokuViewModel` | Sudoku oyun mantığını yöneten view model |
| `showMainMenu` | ~15 | `Binding<Bool>` | Ana menünün gösterilip gösterilmediğini kontrol eden bağlama |
| `isPaused` | ~20 | `Bool` | Oyunun duraklatılıp duraklatılmadığını kontrol eder |
| `showCompletionView` | ~25 | `Bool` | Tamamlama görünümünün gösterilip gösterilmediğini kontrol eder |
| `showFailedView` | ~30 | `Bool` | Başarısızlık görünümünün gösterilip gösterilmediğini kontrol eder |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | ~40 | Oyun ekranını oluşturur |
| `gameHeader()` | ~60 | Oyun başlığı ve duraklatma düğmesini içeren üst bilgi |
| `gameStats()` | ~80 | Oyun istatistiklerini (süre, hatalar, vb.) gösteren bölüm |
| `gameControls()` | ~100 | Oyun kontrol düğmelerini (ipucu, silme, vb.) içeren bölüm |
| `pauseMenu()` | ~120 | Duraklatma menüsü |


---

## MainMenuView.swift

MainMenuView, ana menü ekranının görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | ~10 | `SudokuViewModel` | Sudoku oyun mantığını yöneten view model |
| `showGame` | ~15 | `Binding<Bool>` | Oyun ekranının gösterilip gösterilmediğini kontrol eden bağlama |
| `selectedDifficulty` | ~20 | `Binding<Difficulty>` | Seçilen zorluk seviyesini tutan bağlama |
| `showDifficultySelection` | ~25 | `Bool` | Zorluk seçimi menüsünün gösterilip gösterilmediğini kontrol eder |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | ~30 | Ana menü ekranını oluşturur |
| `difficultySelectionView()` | ~50 | Zorluk seçimi menüsünü oluşturur |
| `mainMenuButtons()` | ~70 | Ana menü düğmelerini oluşturur |
| `startGame(difficulty:)` | ~90 | Belirtilen zorluk seviyesinde yeni bir oyun başlatır |

---

## SavedGamesView.swift

SavedGamesView, kaydedilmiş oyunlar ekranının görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | ~10 | `SudokuViewModel` | Sudoku oyun mantığını yöneten view model |
| `savedGames` | ~15 | `[SavedGame]` | Kaydedilmiş oyunların listesi |
| `showDeleteConfirmation` | ~20 | `Bool` | Silme onayının gösterilip gösterilmediğini kontrol eder |
| `gameToDelete` | ~25 | `SavedGame?` | Silinecek oyun |


### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | ~30 | Kaydedilmiş oyunlar ekranını oluşturur |
| `loadSavedGames()` | ~50 | Kaydedilmiş oyunları yükler |
| `loadGame(game:)` | ~70 | Belirtilen oyunu yükler |
| `deleteGame(game:)` | ~90 | Belirtilen oyunu siler |
| `formatElapsedTime(_:)` | ~110 | Geçen süreyi biçimlendirir |


---

## SudokuCellView.swift

SudokuCellView, Sudoku tahtasındaki her bir hücrenin görünümünü ve davranışını yöneten bileşendir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `row` | 3 | `Int` | Hücrenin bulunduğu satır |
| `column` | 4 | `Int` | Hücrenin bulunduğu sütun |
| `value` | 5 | `Int?` | Hücrenin değeri (boşsa nil) |
| `isFixed` | 6 | `Bool` | Hücrenin sabit (orijinal) olup olmadığı |
| `isUserEntered` | 7 | `Bool` | Hücrenin kullanıcı tarafından girilip girilmediği |
| `isSelected` | 8 | `Bool` | Hücrenin seçili olup olmadığı |
| `isHighlighted` | 9 | `Bool` | Hücrenin vurgulanmış olup olmadığı |
| `isMatchingValue` | 10 | `Bool` | Hücrenin seçili hücreyle aynı değere sahip olup olmadığı |
| `isInvalid` | 11 | `Bool` | Hücrenin geçersiz olup olmadığı |
| `pencilMarks` | 12 | `Set<Int>` | Hücredeki kalem işaretleri |
| `isHintTarget` | 13 | `Bool` | Hücrenin ipucu hedefi olup olmadığı |
| `onCellTapped` | 14 | `() -> Void` | Hücreye tıklandığında çağrılacak fonksiyon |
| `colorScheme` | 16 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `powerManager` | 17 | `PowerSavingManager` | Güç tasarrufu yöneticisi |
| `animateSelection` | 18 | `Bool` | Seçim animasyonunu tetikleyen bayrak |
| `animateValue` | 19 | `Bool` | Değer animasyonunu tetikleyen bayrak |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 21-151 | Hücre görünümünü oluşturan ana görünüm |
| `cellBackground` | 154-162 | Hücre arka planını oluşturan görünüm |
| `getCellBackgroundColor()` | 165-187 | Hücre arka plan rengini hesaplayan fonksiyon |
| `getCellBorderColor()` | 190-212 | Hücre kenar rengini hesaplayan fonksiyon |
| `getTextColor()` | 215-232 | Hücre metin rengini hesaplayan fonksiyon |

### Önemli Özellikler

- **Animasyonlar**: Güç tasarrufu modu etkin değilse, hücre seçimi ve değer değişikliklerinde animasyonlar gösterilir.
- **Renk Teması**: Turkuaz (teal) renk teması kullanılır, ipucu hedefleri için mavi renk kullanılır.
- **Dokunsal Geri Bildirim**: Hücre seçildiğinde dokunsal geri bildirim sağlanır.
- **Kalem İşaretleri**: Hücre boşsa ve kalem işaretleri varsa, bu işaretler gösterilir.

---

## SudokuBoard.swift

SudokuBoard, Sudoku tahtasının mantığını ve veri yapısını yöneten temel sınıftır.

### Enum

| Enum | Satır | Açıklama |
|------|-------|----------|
| `Difficulty` | 5-40 | Sudoku zorluk seviyelerini tanımlayan enum (easy, medium, hard, expert) |

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `board` | 45 | `[[Int?]]` | Mevcut tahta durumunu tutan 9x9 matris |
| `originalBoard` | 46 | `[[Int?]]` | Başlangıç tahta durumunu tutan 9x9 matris |
| `solution` | 47 | `[[Int?]]` | Tahtanın çözümünü tutan 9x9 matris |
| `fixedCells` | 48 | `Set<String>` | Değiştirilemez hücrelerin koordinatlarını tutan küme |
| `pencilMarks` | 49 | `[String: Set<Int>]` | Hücrelerdeki kalem işaretlerini tutan sözlük |
| `completeCheckCache` | 52 | `Bool?` | Tahtanın tamamlanma durumunu önbellekleyen değişken |
| `filledCheckCache` | 53 | `Int?` | Doldurulmuş hücre sayısını önbellekleyen değişken |
| `validPlacementCache` | 54 | `[String: Bool]` | Geçerli yerleştirmeleri önbellekleyen sözlük |
| `difficulty` | 57 | `Difficulty` | Tahtanın zorluk seviyesi |
| `fixed` | 60 | `[[Bool]]` | Sabit hücreleri belirten 9x9 matris |


### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init(difficulty:)` | 64-74 | Belirli bir zorluk seviyesinde yeni bir tahta oluşturur |
| `init(board:solution:fixed:difficulty:)` | 77-96 | Kaydedilmiş oyundan tahta yükler |
| `getValue(row:column:)` | 101-104 | Belirli bir hücrenin değerini döndürür |
| `getValue(at:col:)` | 107-109 | Alternatif isimle hücre değerini döndürür |
| `setValue(row:column:value:)` | 113-129 | Belirli bir hücreye değer atar |
| `setValue(at:col:value:)` | 133-135 | Alternatif isimle hücreye değer atar |
| `isOriginalValue(row:column:)` | 138-141 | Hücrenin sabit olup olmadığını kontrol eder |
| `isFixed(at:col:)` | 144-146 | Alternatif isimle hücrenin sabit olup olmadığını kontrol eder |
| `getSolutionValue(row:column:)` | 149-152 | Çözümdeki hücre değerini döndürür |
| `getOriginalValue(at:col:)` | 155-161 | Orijinal hücre değerini döndürür |
| `isCorrectValue(row:column:value:)` | 164-167 | Bir değerin doğru olup olmadığını kontrol eder |
| `togglePencilMark(row:column:value:)` | 172-188 | Kalem işaretini ekler veya kaldırır |
| `togglePencilMark(at:col:value:)` | 191-193 | Alternatif isimle kalem işaretini ekler veya kaldırır |
| `isPencilMarkSet(row:column:value:)` | 196-201 | Kalem işaretinin var olup olmadığını kontrol eder |
| `hasPencilMarks(row:column:)` | 204-209 | Hücrede kalem işaretleri olup olmadığını kontrol eder |
| `getPencilMarks(row:column:)` | 212-217 | Hücredeki kalem işaretlerini döndürür |
| `getPencilMarks(at:col:)` | 220-222 | Alternatif isimle kalem işaretlerini döndürür |
| `isComplete()` | 227-286 | Tahtanın tamamlanıp tamamlanmadığını kontrol eder |
| `isBoardFilledEnough()` | 289-313 | Tahtanın yeterince dolu olup olmadığını kontrol eder |
| `hasEmptyCells()` | 316-325 | Tahtada boş hücre olup olmadığını kontrol eder |
| `isValidPlacement(row:column:value:)` | 328-369 | Bir değerin belirli bir hücreye yerleştirilebilir olup olmadığını kontrol eder |
| `resetToOriginal()` | 374-387 | Tahtayı başlangıç durumuna sıfırlar |
| `invalidateCaches()` | 390-394 | Önbellekleri temizler |
| `isValidIndex(row:column:)` | 399-401 | İndekslerin geçerli olup olmadığını kontrol eder |
| `generateBoard()` | 406-479 | Yeni bir Sudoku tahtası oluşturur |
| `generateSolution()` | 482-486 | Sudoku çözümü oluşturur |
| `generateSimpleSolution()` | 489-524 | Basit bir çözüm oluşturur |
| `shuffleSolution()` | 527-542 | Çözümü rastgele karıştırır |
| `shuffleRowsAndColumns()` | 545-586 | Satırları ve sütunları karıştırır |
| `swapRows(_:_:)` | 589-601 | İki satırı takas eder |
| `swapColumns(_:_:)` | 604-616 | İki sütunu takas eder |
| `swapRowBlocks(_:_:)` | 619-629 | İki satır bloğunu takas eder |
| `swapColumnBlocks(_:_:)` | 632-642 | İki sütun bloğunu takas eder |
| `createBalancedStartingBoard()` | 645-726 | Dengeli bir başlangıç tahtası oluşturur |
| `getPossibleValues(row:column:)` | 729-740 | Bir hücreye yerleştirilebilecek olası değerleri döndürür |
| `solveSudoku()` | 743-768 | Tahtayı çözer (geri izleme algoritması) |
| `removeRandomCells(count:)` | 771-907 | Rastgele hücreleri kaldırır |
| `getCluesToShow()` | 910-914 | Gösterilecek ipucu sayısını belirler |
| `markFixedCells()` | 917-928 | Sabit hücreleri işaretler |
| `saveState()` | 974-976 | Oyun durumunu kaydeder |
| `getBoardArray()` | 979-989 | Tahtayı 2D Int dizisine dönüştürür |
| `loadFromSavedState(_:)` | 992-1037 | Kaydedilmiş oyun durumundan SudokuBoard nesnesi oluşturur |
| `solveSudokuElimination(_:)` | 1040-1109 | Constraint Propagation ve Elimine yöntemi ile çözüm bulur |
| `applyConstraintPropagation(_:)` | 1112-1142 | Constraint Propagation tekniğini uygular |
| `applyNakedSingles(_:)` | 1145-1165 | Tek olasılığı olan hücreleri doldurur |
| `applyHiddenSingles(_:)` | 1168-1190 | Birim içinde sadece bir hücrede olabilen değerleri bulur |
| `findHiddenSinglesInRow(_:board:)` | 1193-1224 | Bir satırda hidden singles bulur |
| `findHiddenSinglesInColumn(_:board:)` | 1227-1258 | Bir sütunda hidden singles bulur |
| `findHiddenSinglesInBlock(_:_:board:)` | 1261-1297 | Bir 3x3 blokta hidden singles bulur |
| `applyPointingPairs(_:)` | 1300-1344 | Pointing Pairs/Triples tekniğini uygular |
| `removeValueFromOtherBlocksInRow(_:row:exceptBlockCol:board:)` | 1347-1370 | Bir satırın diğer bloklarındaki hücrelerden belirli bir değeri çıkarır |
| `removeValueFromOtherBlocksInColumn(_:col:exceptBlockRow:board:)` | 1373-1396 | Bir sütunun diğer bloklarındaki hücrelerden belirli bir değeri çıkarır |
| `isBoardValid(_:)` | 1399-1446 | Tahtanın geçerli olup olmadığını kontrol eder |
| `isCompleteSolution(_:)` | 1449-1461 | Tahtanın tamamen doldurulup doldurulmadığını kontrol eder |
| `possibleValues(for:col:in:)` | 1464-1500 | Belirli bir hücre için olası değerleri bulur |


### Önemli Özellikler

- **Zorluk Seviyeleri**: Kolay, Orta, Zor ve Uzman olmak üzere dört zorluk seviyesi bulunur.
- **Çözüm Algoritması**: Tahtayı çözmek için geri izleme algoritması ve Constraint Propagation teknikleri kullanılır.
- **Kalem İşaretleri**: Kullanıcının notlar alabilmesi için kalem işaretleri desteklenir.
- **Performans Önbellekleri**: Sık kullanılan işlemlerin sonuçları önbelleklenir.
- **Tahta Oluşturma**: Geçerli bir çözümü olan tahtalar oluşturmak için özel algoritmalar kullanılır.

---

## PencilMarksView.swift

PencilMarksView, Sudoku hücrelerinde kalem işaretlerini (notları) gösteren görünüm bileşenidir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `pencilMarks` | 3 | `Set<Int>` | Gösterilecek kalem işaretlerinin kümesi |
| `cellSize` | 4 | `CGFloat` | Hücrenin boyutu |


### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 6-59 | Kalem işaretlerini 3x3 grid şeklinde gösteren görünüm |


### Önemli Özellikler

- **3x3 Grid Düzeni**: Kalem işaretleri, hücre içinde 3x3'lük bir grid düzeninde gösterilir.
- **Boyut Uyumu**: Hücre boyutuna göre otomatik olarak ölçeklenen yazı tipi ve yerleşim.
- **Performans Optimizasyonu**: Sadece var olan kalem işaretleri gösterilir, boş alanlar için placeholder kullanılır.

---

## ScoreboardView.swift

ScoreboardView, skor tablosu ekranının görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `scoreManager` | ~10 | `ScoreManager` | Skorları yöneten sınıf |
| `scores` | ~15 | `[Score]` | Skorların listesi |
| `selectedDifficulty` | ~20 | `Difficulty` | Gösterilecek skorların zorluk seviyesi |


### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | ~30 | Skor tablosu ekranını oluşturur |
| `loadScores()` | ~50 | Skorları yükler |
| `formatElapsedTime(_:)` | ~70 | Geçen süreyi biçimlendirir |


---

## SettingsView.swift

SettingsView, ayarlar ekranının görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | ~10 | `SudokuViewModel` | Sudoku oyun mantığını yöneten view model |
| `showLoginView` | ~15 | `Bool` | Giriş görünümünün gösterilip gösterilmediğini kontrol eder |
| `showRegisterView` | ~20 | `Bool` | Kayıt görünümünün gösterilip gösterilmediğini kontrol eder |
| `showDeleteConfirmation` | ~25 | `Bool` | Silme onayının gösterilip gösterilmediğini kontrol eder |
| `showTutorial` | ~30 | `Bool` | Öğreticinin gösterilip gösterilmediğini kontrol eder |
| `powerSavingEnabled` | ~35 | `Bool` | Güç tasarrufu modunun etkin olup olmadığını kontrol eder |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | ~40 | Ayarlar ekranını oluşturur |
| `userSection()` | ~60 | Kullanıcı ayarları bölümünü oluşturur |
| `gameSection()` | ~80 | Oyun ayarları bölümünü oluşturur |
| `dataSection()` | ~100 | Veri ayarları bölümünü oluşturur |
| `deleteAllSavedGames()` | ~120 | Tüm kaydedilmiş oyunları siler |
| `resetScoreboard()` | ~140 | Skor tablosunu sıfırlar |
