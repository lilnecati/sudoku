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
- Karanlık/açık tema desteği: Renk şemasına göre farklı renkler

## GameView.swift

GameView, Sudoku oyununun ana oyun ekranını oluşturan ve oyun mantığını görsel arayüz ile birleştiren görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | 7 | `SudokuViewModel` | Oyun mantığını yöneten view model |
| `showDifficultyPicker` | 8 | `Bool` | Zorluk seviyesi seçiciyi gösterme durumu |
| `showingGameComplete` | 9 | `Bool` | Oyun tamamlandı ekranını gösterme durumu |
| `showSettings` | 10 | `Bool` | Ayarlar ekranını gösterme durumu |
| `presentationMode` | 12 | `PresentationMode` | Görünüm sunum modunu yönetme |
| `dismiss` | 13 | `DismissAction` | Görünümü kapatma aksiyonu |
| `colorScheme` | 14 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `timeDisplay` | 18 | `String` | Gösterilecek zaman metni |
| `boardKey` | 19 | `String` | Tahtayı yenileme için benzersiz anahtar |
| `timerUpdateInterval` | 20 | `TimeInterval` | Zamanlayıcı güncelleme aralığı |
| `isPremiumUnlocked` | 23 | `Bool` | Premium özelliklerin açık olma durumu |
| `showNoHintsMessage` | 26 | `Bool` | İpucu mesajını gösterme durumu |
| `isHeaderVisible` | 29 | `Bool` | Başlık bölümünün görünürlüğü |
| `isBoardVisible` | 30 | `Bool` | Tahta görünürlüğü |
| `isControlsVisible` | 31 | `Bool` | Kontroller bölümünün görünürlüğü |
| `tutorialManager` | 34 | `TutorialManager` | Eğitim rehberini yöneten nesne |
| `showTutorialButton` | 35 | `Bool` | Eğitim butonunu gösterme durumu |
| `gradientColors` | 38-42 | `[Color]` | Arka plan degrade renkleri |
| `difficultyColors` | 45-50 | `[SudokuBoard.Difficulty: Color]` | Zorluk seviyelerine göre renkler |
| `showCompletionView` | 70 | `Bool` | Tamamlama ekranını gösterme durumu |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init(difficulty:)` | 52-55 | Belirli bir zorluk seviyesi ile yeni oyun başlatma |
| `init(savedGame:)` | 57-65 | Kaydedilmiş bir oyundan başlatma |
| `init(existingViewModel:)` | 67-68 | Var olan bir viewModel ile başlatma |
| `body` | 72-180 | Ana görünüm yapısını oluşturur |
| `headerView` | ~230-300 | Üst bilgi bölümünü oluşturur |
| `controlsView` | ~320-410 | Oyun kontrolleri bölümünü oluşturur |
| `overlayViews` | ~415-530 | Açılır göstergeleri oluşturur |
| `difficultyPickerView` | ~535-605 | Zorluk seviyesi seçici görünümünü oluşturur |
| `congratulationsView` | ~610-720 | Tebrik ekranını oluşturur |
| `gameOverView` | ~725-780 | Oyun bitti ekranını oluşturur |

### Önemli Özellikler

- Dinamik UI animasyonları: Sayfalar arası geçişler ve bileşen animasyonları
- Arka plan davranışı yönetimi: Oyun 2 dakika arka planda kalırsa otomatik kayıt
- Eğitim rehberi: Yeni kullanıcılar için interaktif kullanım kılavuzu
- Performans optimizasyonları: `drawingGroup()` ve `fixedSize` kullanımı

## MainMenuView.swift

MainMenuView, Sudoku uygulamasının ana menüsünü oluşturan ve kullanıcıya oyun başlatma, devam etme, skor tablosu ve ayarlar gibi seçenekler sunan görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `colorScheme` | 5 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `hasSavedGame` | 6 | `Bool` | Kaydedilmiş oyun olup olmadığı durumu |



### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 8-99 | Ana görünüm yapısını oluşturur |
| `checkForSavedGame()` | 101-112 | Kaydedilmiş oyun olup olmadığını kontrol eder |
| `loadLastGame()` | 114-126 | En son kaydedilmiş oyunu yükler |



### Önemli Özellikler

- Dinamik UI: Kaydedilmiş oyun varsa "Devam Et" butonu görünür
- Görsel stil: Gradyan arka plan ve sistem ikonları ile modern tasarım
- Gezinme yapısı: SwiftUI NavigationView ile sayfa geçişleri
- Renk yönetimi: ColorManager kullanarak tutarlı renk paleti

## ScoreboardView.swift

ScoreboardView, oyuncu performansını, istatistiklerini ve tamamlanan oyunların skor geçmişini görüntüleyen görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `colorScheme` | 5 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `selectedDifficulty` | 6 | `SudokuBoard.Difficulty` | Seçili zorluk seviyesi |
| `statistics` | 7 | `ScoreboardStatistics` | Skor tablosu istatistikleri |
| `recentScores` | 8 | `[NSManagedObject]` | Son oyunların listesi |
| `showingDetail` | 9 | `Bool` | Detay görünümünü gösterme durumu |
| `selectedTab` | 10 | `Int` | Seçili sekme (Genel/Zorluk) |
| `selectedScore` | 11 | `NSManagedObject?` | Görüntülenmek üzere seçilen skor |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 13-73 | Ana görünüm yapısını oluşturur |
| `statisticsView` | 75-112 | Performans istatistikleri görünümünü oluşturur |
| `gameStatsView` | 114-160 | Oyun istatistikleri görünümünü oluşturur |
| `recentGamesView` | 162-205 | Son oyunlar listesini gösterir |
| `difficultyComparisonView` | ~220-270 | Zorluk seviyelerine göre istatistikleri karşılaştırır |
| `tabButton(title:tag:)` | ~280-310 | Sekme butonlarını oluşturur |
| `formatTime(_:)` | ~360-370 | Zaman aralığını biçimlendirir |
| `loadData()` | ~265-320 | Skor ve istatistik verilerini yükler |

### Önemli Özellikler

- Sekmeli ara yüz: Genel istatistikler ve zorluk seviyesine göre karşılaştırma
- Detaylı istatistikler: En yüksek skor, ortalama skor, tamamlanan oyunlar ve daha fazlası
- Etkileşimli liste: Son oyunların detaylarını görüntülemek için dokunulabilir öğeler
- Dinamik veri güncelleme: Sekme ve zorluk seviyesi değişikliklerinde otomatik güncelleme

## SettingsView.swift

SettingsView, kullanıcının uygulama tercihlerini ve ayarlarını yönetebileceği görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `presentationMode` | 6 | `PresentationMode` | Görünüm sunum modunu yönetme |
| `colorScheme` | 7 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `defaultDifficulty` | 10 | `String` | Varsayılan zorluk seviyesi (AppStorage) |
| `darkMode` | 11 | `Bool` | Karanlık mod aktivasyonu (AppStorage) |
| `enableHapticFeedback` | 12 | `Bool` | Dokunsal geri bildirim aktivasyonu (AppStorage) |
| `enableSoundEffects` | 13 | `Bool` | Ses efektleri aktivasyonu (AppStorage) |
| `useSystemAppearance` | 14 | `Bool` | Sistem görünümünü kullanma durumu (AppStorage) |
| `textSizeString` | 15 | `String` | Metin boyutu tercihi (AppStorage) |
| `prefersDarkMode` | 16 | `Bool` | Karanlık mod tercihi (AppStorage) |
| `powerSavingMode` | 17 | `Bool` | Güç tasarrufu modu aktivasyonu (AppStorage) |
| `autoPowerSaving` | 18 | `Bool` | Otomatik güç tasarrufu aktivasyonu (AppStorage) |
| `powerManager` | 21 | `PowerSavingManager` | Güç tasarrufu yöneticisi |
| `username` | 23 | `String` | Kullanıcı adı |
| `password` | 24 | `String` | Şifre |
| `email` | 25 | `String` | E-posta |
| `name` | 26 | `String` | İsim |
| `showLoginView` | 27 | `Bool` | Giriş görünümünü gösterme durumu |
| `showRegisterView` | 28 | `Bool` | Kayıt görünümünü gösterme durumu |
| `errorMessage` | 29 | `String` | Hata mesajı |
| `showError` | 30 | `Bool` | Hata gösterme durumu |
| `isRefreshing` | 31 | `Bool` | Yenileme durumu |
| `currentUser` | 34 | `NSManagedObject?` | Mevcut kullanıcı bilgisi |



### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `getBatteryIcon()` | 37-47 | Pil seviyesine göre ikon döndürür |
| `getBatteryColor()` | 50-58 | Pil seviyesine göre renk döndürür |
| `profileCircle(initial:)` | 69-82 | Profil dairesi görünümünü oluşturur |
| `logoutButton(action:)` | 84-102 | Çıkış butonu görünümünü oluşturur |
| `loginButton(action:)` | 104-121 | Giriş butonu görünümünü oluşturur |
| `registerButton(action:)` | 123-143 | Kayıt butonu görünümünü oluşturur |
| `websiteLink(url:displayText:)` | 145-163 | Web sitesi bağlantı görünümünü oluşturur |
| `resetAllSettings()` | 166-180 | Tüm ayarları varsayılan değerlerine sıfırlar |
| `userProfileSection()` | 182-214 | Kullanıcı profili bölümünü oluşturur |
| `body` | 216-331 | Ana görünüm yapısını oluşturur |
| `settingsSection(title:systemImage:content:)` | 335-379 | Ayarlar bölümü görünümünü oluşturur |
| `gameSettingsView()` | 382-492 | Oyun ayarları görünümünü oluşturur |
| `appearanceSettingsView()` | 546-641 | Görünüm ayarları görünümünü oluşturur |
| `aboutView()` | 644-723 | Hakkında bölümü görünümünü oluşturur |


### Önemli Özellikler

- Güç tasarrufu yönetimi: Pil seviyesine göre otomatik güç tasarrufu modu
- Tema desteği: Karanlık/açık tema ve sistem teması ile uyum
- Oyun zorluk ayarları: Varsayılan zorluk seviyesi tercihi
- Erişilebilirlik: Metin boyutu ayarları ve görsel tercihler
- Geribildirim kontrolleri: Dokunsal geri bildirim ve ses efektleri ayarları

## NumberPadView.swift

NumberPadView, Sudoku oyununda kullanıcının hücrelere değer girmesini sağlayan sanal numara tuş takımını oluşturan görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewModel` | 4 | `SudokuViewModel` | Oyun mantığını yöneten view model |
| `isEnabled` | 5 | `Bool` | Tuş takımının etkin olup olmadığı durumu |
| `colorScheme` | 6 | `ColorScheme` | Uygulama renk şeması (açık/karanlık mod) |
| `columns` | 9-14 | `[GridItem]` | LazyVGrid için sütun yapılandırması |
| `disabledOpacity` | 18 | `Double` | Devre dışı olduğunda opasite değeri |
| `buttonColors` | 19-29 | `[Int: Color]` | Her numara için belirlenmiş renkler |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 31-81 | Ana görünüm yapısını oluşturur |
| `numberButton(for:)` | 84-166 | Belirli bir numara için tuş görünümünü oluşturur |
| `pencilModeButton` | 169-230 | Kalem modu tuşu görünümünü oluşturur |
| `eraseButton` | 233-280 | Silme tuşu görünümünü oluşturur |


### Önemli Özellikler

- Performans optimizasyonu: `drawingGroup()`, `equatable(by:)` ve `fixedSize` ile yüksek verimlilik
- Dokunsal geribildirim: Tuşlara basıldığında titretim geribildirimi
- Kalem modu: Not almak için kalem modu destekler
- Kalan rakam gösterimi: Her bir rakamın tablodaki kalan sayısını gösterir
- Duyarlı tasarım: GeometryReader kullanarak ekran boyutlarına uyum sağlar

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

## SudokuCellView.swift

SudokuCellView, Sudoku tahtasındaki her bir hücreyi temsil eden görünüm bileşenidir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|---------|
| `row` | 4 | `Int` | Hücrenin bulunduğu satır |
| `column` | 5 | `Int` | Hücrenin bulunduğu sütun |
| `value` | 6 | `Int?` | Hücredeki değer (boşsa null) |
| `isFixed` | 7 | `Bool` | Hücrenin sabit (silinemeyen) olup olmadığı |
| `isUserEntered` | 8 | `Bool` | Değerin kullanıcı tarafından girilip girilmediği |
| `isSelected` | 9 | `Bool` | Hücrenin seçili olup olmadığı |
| `isHighlighted` | 10 | `Bool` | Hücrenin vurgulanmış olup olmadığı (aynı satır/sütun) |
| `isMatchingValue` | 11 | `Bool` | Hücrenin seçili hücreyle aynı değere sahip olup olmadığı |
| `isInvalid` | 12 | `Bool` | Hücrenin geçersiz olup olmadığı (oyun kurallarına aykırı) |
| `pencilMarks` | 13 | `Set<Int>` | Hücredeki kalem işaretleri (notlar) |
| `isHintTarget` | 14 | `Bool` | Hücrenin ipucu hedefi olup olmadığı |
| `onCellTapped` | 15 | `() -> Void` | Hücreye tıklandığında çağrılacak fonksiyon |
| `colorScheme` | 17 | `ColorScheme` | Sistem renk şeması (açık/karanlık mod) |
| `powerManager` | 18 | `PowerSavingManager` | Güç tasarrufu yöneticisi |
| `animateSelection` | 19 | `Bool` | Seçim animasyonunun durumu |
| `animateValue` | 20 | `Bool` | Değer animasyonunun durumu |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 22-131 | Ana görünüm yapısını oluşturur |
| `cellBackground` | 134-143 | Hücre arka plan görünümünü oluşturur |
| `getCellBackgroundColor()` | 146-171 | Hücre arka plan rengini hesaplar |
| `getCellBorderColor()` | 174-200 | Hücre kenar rengini hesaplar |
| `getTextColor()` | 203-224 | Hücre içindeki metin rengini belirler |

### Önemli Özellikler

- Dokunsal geribildirim: Hücrelere tıklandığında titretim geribildirimi sağlar
- Dinamik animasyonlar: Seçim ve değer değişikliklerinde animasyonlar gösterir
- Güç tasarrufu uyumlu: Güç tasarrufu modunda gereksiz animasyonları kapatır
- Renk kodlaması: Hücre durumuna göre farklı renk kodları kullanır (seçili, vurgulanmış, eşleşen, ipucu)
- Kalem işaretleri: Not almak için hücre içinde küçük notlar gösterilmesini destekler

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

---

## TutorialView.swift

TutorialView, kullanıcılara Sudoku oyununun temel kurallarını ve stratejilerini öğreten eğitim görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `presentationMode` | 4 | `PresentationMode` | Görünüm sunum modunu yönetme |
| `colorScheme` | 5 | `ColorScheme` | Sistem renk şeması (açık/karanlık mod) |
| `currentStep` | 6 | `Int` | Mevcut rehber adımı |
| `animationProgress` | 9 | `Double` | Animasyon ilerleme durumu |
| `highlightScale` | 10 | `Bool` | Vurgulama ölçeklendirme durumu |
| `animateInputValue` | 11 | `Bool` | Giriş değeri animasyonu durumu |
| `inputAnimationValue` | 12 | `Int` | Animasyonda kullanılan giriş değeri |
| `animateNote` | 13 | `Bool` | Not animasyonu durumu |
| `lastAddedNote` | 14 | `Int` | Son eklenen not değeri |
| `notesSet` | 15 | `Set<Int>` | Notlar kümesi |
| `singlePossibilityValues` | 18-22 | `[[Int]]` | Tek olasılık stratejisi için örnek veriler |
| `singleLocationNotes` | 24-28 | `[[[Int]]]` | Tek konum stratejisi için örnek notlar |
| `tutorialSteps` | 31-70 | `[TutorialStep]` | Rehber adımlarının listesi |



### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 72-139 | Ana görünüm yapısını oluşturur |
| `tutorialStepView(step:stepNumber:)` | 142-161 | Belirli bir rehber adımının görünümünü oluşturur |
| `tutorialExampleView(forStep:)` | 256-268 | Adıma özel örnek görünümü oluşturur |
| `getIconForStep(step:)` | 258-275 | Rehber adımına uygun ikonu belirler |
| `singlePossibilityExample` | 277-336 | Tek olasılık stratejisi örneğini gösteren görünüm |
| `singleLocationExample` | 338-430 | Tek konum stratejisi örneğini gösteren görünüm |
| `sudokuInputAnimation` | 431-537 | Sayı girişi animasyonu |

### Önemli Özellikler

- Eğitici rehber: Sudoku'nun temel kuralları ve stratejileri hakkında kapsamlı bilgi
- Adım adım eğitim: Oyuncuları basit adımlarla yönlendiren sekiz eğitim adımı
- Etkileşimli örnekler: Stratejileri göstermek için canlı animasyonlu örnekler
- Sürüklenebilir arayüz: Kullanıcıların sayfa üzerinde serbestçe gezinmesini sağlayan TabView yapısı
- İlerleme göstergesi: Kullanıcının eğitimde nerede olduğunu gösteren ilerleme çubuğu
- Kapsamlı strateji anlatımı: Tek olasılık ve tek konum stratejilerinin görselleştirilmesi

---

## TutorialOverlayView.swift

TutorialOverlayView, oyun sırasında kullanıcıya arayüz hakkında adım adım rehberlik etmek için kullanılan transparan üst katman görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `tutorialManager` | 4 | `TutorialManager` | Öğretici rehber adımlarını yöneten nesne |
| `onComplete` | 5 | `() -> Void` | Öğretici tamamlandığında çağrılacak fonksiyon |
| `showHighlight` | 8 | `Bool` | Vurgulama gösterilip gösterilmeyeceği |
| `pulseOpacity` | 9 | `Double` | Nabzım etkisinin opaklığı |
| `cardScale` | 10 | `Double` | Kart ölçeği |
| `contentOpacity` | 11 | `Double` | İçerik opaklığı |
| `showSpotlight` | 12 | `Bool` | Spot ışığı gösterilip gösterilmeyeceği |
| `powerManager` | 13 | `PowerSavingManager` | Güç tasarrufu yöneticisi |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 15-122 | Ana görünüm yapısını oluşturur |
| `highlightView` | 125-144 | Vurgulama görünümünü oluşturur |
| `getTargetFrame(for:in:)` | 147-200 | Belirli bir hedef için ekranda vurgu çerçevesinin konumunu hesaplar |

### Önemli Özellikler

- Etkileşimli üst katman: Arayüz üzerinde transparan bir katman olarak çalışır
- Canlı vurgulama: Kullanıcının dikkatini belirli öğelere yönlendiren animasyonlu vurgulamalar
- Adım ilerlemesi: Adımlar arasında ileri-geri hareket etme imkanı
- Görsel rehberlik: Sudoku arayüzünün önemli bölümlerini göstermek için spot ışığı efekti
- Kademeli eğitim: Kullanıcıyı adım adım yönlendiren yapı
- İlerleme göstergesi: Kullanıcının eğitimdeki ilerlemesini gösteren ilerleme çubuğu

---

## PowerSavingManager.swift

PowerSavingManager, uygulamanın pil tasarrufu özelliklerini yöneten sınıftır. Pil seviyesini izleyerek otomatik güç tasarrufu modunu yönetir ve görsel efektleri optimize eder.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `shared` | 5 | `PowerSavingManager` | Sınıfın tek (singleton) örneği |
| `powerSavingMode` | 8-12 | `Bool` | Güç tasarrufu modunun açık olup olmadığı |
| `autoPowerSaving` | 14-18 | `Bool` | Otomatik güç tasarrufu modunun açık olup olmadığı |
| `batteryLevel` | 21 | `Float` | Mevcut pil seviyesi (0.0-1.0) |
| `isCharging` | 22 | `Bool` | Cihazın şarj durumu |
| `criticalBatteryThreshold` | 25 | `Float` | Kritik pil seviyesi eşiği (%15) |
| `lowBatteryThreshold` | 26 | `Float` | Düşük pil seviyesi eşiği (%25) |
| `mediumBatteryThreshold` | 27 | `Float` | Orta pil seviyesi eşiği (%40) |
| `isAutoPowerSavingActive` | 30 | `Bool` | Otomatik güç tasarrufunun şu anda aktif olup olmadığı |
| `cancellables` | 33 | `Set<AnyCancellable>` | Combine publisher aboneliklerini saklayan koleksiyon |
| `powerSavingLevel` | 63 | `PowerSavingLevel` | Güç tasarrufu seviyesi |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init()` | 36-55 | Başlatıcı metot, pil durumu izlemeyi başlatır |
| `updateBatteryStatus()` | 58-63 | Pil durumunu günceller |
| `checkAutoPowerSaving()` | 82-113 | Pil seviyesine göre otomatik güç tasarrufu uygular |
| `togglePowerSavingMode()` | 116-128 | Güç tasarrufu modunu açıp kapatmak için |
| `setPowerSavingLevel(_:)` | 131-139 | Güç tasarrufu seviyesini ayarlar |
| `animationSpeedFactor` | 151-163 | Güç tasarrufu seviyesine göre animasyon hız faktörünü hesaplar |
| `animationComplexityFactor` | 166-178 | Güç tasarrufu seviyesine göre animasyon karmaşıklık faktörünü hesaplar |
| `visualEffectQualityFactor` | 181-193 | Güç tasarrufu seviyesine göre görsel efekt kalitesi faktörünü hesaplar |

### Önemli Özellikler

- **Pil Durumu İzleme**: Cihazın pil seviyesini ve şarj durumunu sürekli izler
- **Kademeli Güç Tasarrufu**: Pil seviyesine göre farklı güç tasarrufu seviyeleri uygular (düşük, orta, yüksek)
- **Otomatik Mod**: Pil seviyesi belirli eşiklerin altına düştüğünde otomatik olarak aktifleşen güç tasarrufu
- **Animasyon Optimizasyonu**: Güç tasarrufu seviyesine göre animasyon hızı ve karmaşıklığını ayarlar
- **Görsel Kalite Kontrolü**: Güç tasarrufu seviyesine göre görsel efekt kalitesini ayarlar
- **Kullanıcı Kontrollerine Entegrasyon**: Kullanıcının manuel olarak güç tasarrufu ayarlarını değiştirmesine izin verir

---

## SudokuApp.swift

SudokuApp, uygulamanın temel yapısını ve yaşam döngüsünü yöneten ana sınıftır.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `darkMode` | 77 | `Bool` | Karanlık mod tercihini saklar |
| `useSystemAppearance` | 78 | `Bool` | Sistem görünümüne uyum sağlama tercihini saklar |
| `textSizeString` | 79 | `String` | Metin boyutu tercihini saklar |
| `lastBackgroundTime` | 82 | `Double` | Uygulamanın arka plana alınma zamanını kaydeder |
| `gameResetTimeInterval` | 84 | `TimeInterval` | Oyunun sıfırlanması için gereken süre (2 dakika = 120 saniye) |
| `initializationError` | 91 | `Error?` | Başlatılma hatasını saklar |
| `isInitialized` | 92 | `Bool` | Uygulamanın başlatılıp başlatılmadığını takip eder |
| `persistenceController` | 100 | `PersistenceController` | CoreData verilerini yöneten denetleyici |
| `viewContext` | 101 | `NSManagedObjectContext` | CoreData için görünüm bağlamı |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init()` | 103-119 | Uygulama başlatıcısı, CoreData bağlamını ve güç tasarrufu yöneticisini hazırlar |
| `body` | 121-186 | Ana uygulama sahnesini oluşturur |

### Önemli Özellikler

- **Arka Plan Yönetimi**: Uygulama arka plana alındığında aktif oyun otomatik olarak duraklatılır
- **Zaman Aşımı Kontrolü**: Uygulama 2 dakikadan uzun süre arka planda kalırsa, oyun otomatik olarak sıfırlanır ve kaydedilir
- **Tema Yönetimi**: Karanlık/açık temanın yönetimi ve sistem görünümüne uyum sağlama özelliği
- **Metin Boyutu Ayarları**: Küçük, orta ve büyük metin boyutu seçenekleri sunar
- **CoreData Entegrasyonu**: Uygulama verilerinin kalıcı depolanmasını sağlar
- **Bildirim Sistemi**: Farklı uygulama durumları için NotificationCenter aracılığıyla bildirimler gönderir (aktif olma, duraklama, sıfırlama)
- **Hata Yönetimi**: Başlatılma hataları için özel görünüm ve yeniden deneme mekanizması içerir

---

## SudokuViewModel.swift

SudokuViewModel, Sudoku oyununun tüm mantığını yöneten ana sınıftır. Oyun tahtalarını yönetir, oyuncu hareketlerini işler, oyun durumunu takip eder ve kullanıcı ipuçlarını yönetir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `board` | 13 | `SudokuBoard` | Geçerli Sudoku tahtası |
| `selectedCell` | 15 | `(row: Int, column: Int)?` | Kullanıcının seçtiği hücre |
| `invalidCells` | 17 | `Set<Position>` | Geçersiz hücrelerin listesi |
| `elapsedTime` | 19 | `TimeInterval` | Geçen oyun süresi |
| `gameState` | 21 | `GameState` | Oyunun durumu (ready, playing, paused, completed, failed) |
| `pencilMode` | 23 | `Bool` | Kalem modunun aktif olup olmadığı |
| `userEnteredValues` | 29 | `[[Bool]]` | Kullanıcının girdiği değerleri takip eden matris |
| `moveCount` | 32 | `Int` | Yapılan hamle sayısı |
| `errorCount` | 33 | `Int` | Yapılan hata sayısı |
| `hintCount` | 34 | `Int` | Alınan ipucu sayısı |
| `remainingHints` | 35 | `Int` | Kalan ipucu hakkı sayısı |
| `savedGames` | 92 | `[NSManagedObject]` | Kaydedilmiş oyunların listesi |
| `usedNumbers` | 95 | `[Int: Int]` | Tahtada kaç kez kullanıldığını takip eden sayılar sözlüğü |




### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `resetGameState()` | 41-65 | Oyun durumunu sıfırlar |
| `newGame(difficulty:)` | 101-115 | Belirli bir zorlukta yeni bir oyun başlatır |
| `selectCell(row:column:)` | 118-132 | Belirtilen hücreyi seçer |
| `setValueAtSelectedCell(_:)` | 135-165 | Seçili hücreye değer atar |
| `togglePencilMark(at:col:value:)` | ~200 | Belirli bir hücreye kalem işareti ekler/kaldırır |
| `validateBoard()` | ~250 | Tahtanın geçerliliğini kontrol eder |
| `requestHint()` | ~550 | Oyuncuya ipucu verir |
| `togglePause()` | ~700 | Oyunu duraklatır/devam ettirir |
| `saveGame(forceNewSave:)` | ~1150 | Geçerli oyunu kaydeder |
| `loadGame(from:)` | ~1250 | Kaydedilmiş bir oyunu yükler |
| `deleteSavedGame(_:)` | ~1590 | Kaydedilmiş bir oyunu siler |
| `resetGameAfterTimeout()` | ~1750 | Zaman aşımı sonrası oyunu sıfırlar |

### Önemli Özellikler

- **İpucu Sistemi**: Kullanıcılara Sudoku çözüm stratejileri hakkında açıklamalı ipucuları sunar
- **Kalem İşaretleri**: Kullanıcıların hücrelerde potansiyel değerleri not alabilmesini sağlar
- **Arka Plan Yönetimi**: Uygulama arka plana alındığında oyun otomatik olarak duraklatılır, 2+ dakika arka planda kalırsa oyun kaydedilir ve ana menüye dönülür
- **Oyun İstatistikleri**: Hamle, hata, ipucu sayısı ve geçen süre gibi oyun istatistiklerini tutar
- **CoreData Entegrasyonu**: Oyunların kaydedilmesi ve yüklenmesi için CoreData ile entegrasyon
- **Gelecek Hamleleri Tahmin Etme**: Hata doğrulamaları ve ipucu verirken gelecek hamleler için analiz yapar
- **Optimizasyon Mekanizmaları**: Hızlı erişim için kalem işaretlerini ve geçerli değerleri önbelleğe alan optimizasyonlar
- **Zaman Yönetimi**: Oyun süresini takip eden ve duruma göre sıfırlayan zamanlama fonksiyonları
- **Bildirim Sistemi**: Oyunun duraklatma, devam etme ve sıfırlama gibi durumlarını yönetmek için bildirim sistemi
- **Dokunsal Geri Bildirim**: Hareketlere ve hatalara doğrudan dokunsal geri bildirimler sağlayan mekanizmalar

---

## SudokuBoard.swift

SudokuBoard, Sudoku tahtasını ve oyun kurallarını temsil eden temel veri modelidir. Tahta oluşturma, hücre değerlerini yönetme ve oyun mantığını içerir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `board` | 49 | `[[Int?]]` | Geçerli oyun tahtasını tutan 9x9 matris |
| `originalBoard` | 50 | `[[Int?]]` | Oyunun başlangıcındaki orijinal tahtayı tutan matris |
| `solution` | 51 | `[[Int?]]` | Tahtanın doğru çözümünü tutan matris |
| `fixedCells` | 52 | `Set<String>` | Değiştirilemeyen (başlangıç) hücrelerin kümesi |
| `pencilMarks` | 53 | `[String: Set<Int>]` | Kullanıcının kalem işaretlerini tutan sözlük |
| `difficulty` | 60 | `Difficulty` | Oyunun zorluk seviyesi |
| `fixed` | 63 | `[[Bool]]` | Sabit (değiştirilemeyen) hücreleri belirten 9x9 matris |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `getValue(row:column:)` | 94-97 | Belirtilen konumdaki hücre değerini döndürür |
| `setValue(row:column:value:)` | 106-121 | Belirtilen konumdaki hücreye değer atar |
| `isOriginalValue(row:column:)` | 130-133 | Hücrenin orijinal (değiştirilemeyen) olup olmadığını kontrol eder |
| `getSolutionValue(row:column:)` | 143-146 | Belirtilen konumdaki çözüm değerini döndürür |
| `isCorrectValue(row:column:value:)` | 156-159 | Belirtilen değerin doğru olup olmadığını kontrol eder |
| `togglePencilMark(row:column:value:)` | 163-182 | Belirtilen konumda kalem işareti ekler/kaldırır |
| `getPencilMarks(row:column:)` | ~160 | Belirtilen konumdaki kalem işaretlerini döndürür |
| `isBoardComplete()` | ~200 | Tahtanın tamamlanmış olup olmadığını kontrol eder |
| `canPlaceValue(value:row:column:)` | ~250 | Değerin belirtilen konuma yerleştirilebilir olup olmadığını kontrol eder |
| `generateBoard()` | ~400 | Yeni bir Sudoku tahtası oluşturur |
| `generateSolution()` | ~450 | Geçerli bir Sudoku çözümü oluşturur |
| `createBalancedStartingBoard()` | ~650 | Zorluk seviyesine uygun başlangıç tahtası oluşturur |

### Önemli Özellikler

- **Zorluk Seviyeleri**: Dört farklı zorluk seviyesi sunar (Kolay, Orta, Zor, Uzman)
- **Tahta Üreteci**: Geçerli Sudoku tahtaları oluşturan algoritma içerir
- **Çözüm Doğrulaması**: Oyuncu hamlelerinin doğruluğunu kontrol eden fonksiyonlar
- **Kalem İşareti Yönetimi**: Kullanıcının potansiyel değerleri işaretleyebilmesi için kalem işareti sistemi
- **Performans Optimizasyonu**: Önbellek mekanizmaları ile çeşitli kontrollerin performansını artırır
- **Çözüm Algoritması**: Sudoku tahtalarını çözmek için ileri algoritmalar (kısıtlama yayılımı, gizli tekli, işaret çiftleri)
- **Denge Sistemi**: Zorluk seviyesine göre uygun sayıda ipucu gösterecek şekilde tasarlanmış denge sistemi
- **Kodlanabilirlik**: Kaydedilmiş oyunların depolanmasını kolaylaştırmak için Codable protokolünü destekler

---

## SavedGamesView.swift

SavedGamesView, kullanıcının kaydettiği oyunları listeleyen, filtreleme ve yönetim işlemlerini sağlayan görünümdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `viewContext` | 5 | `NSManagedObjectContext` | CoreData yönetilen nesne bağlamı |
| `savedGames` | 9 | `FetchedResults<SavedGame>` | CoreData'dan çekilen kayıtlı oyunlar |
| `viewModel` | 12 | `SudokuViewModel` | Oyun mantığını yöneten model |
| `gameToDelete` | 13 | `SavedGame?` | Silinecek oyunun referansı |
| `showingDeleteAlert` | 14 | `Bool` | Silme onayı alert'inin durumu |
| `selectedDifficulty` | 15 | `String` | Seçili zorluk seviyesi filtresi |
| `gameSelected` | 19 | `(NSManagedObject) -> Void` | Oyun seçildiğinde çağrılan closure |
| `cardOffset` | 22 | `[NSManagedObjectID: CGFloat]` | Kart kaydırma animasyonları için offset değerleri |
| `isAnimating` | 23 | `Bool` | Animasyon durumu |
| `difficultyLevels` | 27 | `[String]` | Filtreleme için zorluk seviyeleri listesi |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `filteredSavedGames` | 29-35 | Seçili zorluk seviyesine göre oyunları filtreler |
| `emptyStateView` | 38-63 | Kayıtlı oyun yoksa göstererek boş durum görünümü |
| `body` | 65-156 | Ana görünümü oluşturur |
| `savedGameCard(for:)` | 158-290 | Belirli bir kaydedilmiş oyun için kart görünümü oluşturur |

### Önemli Özellikler

- **Filtreleme Sistemi**: Zorluk seviyesine göre kayıtlı oyunları filtreleme imkanı
- **Sürüklenebilir Kartlar**: Kayıtlı oyunları silmek için sağa sürükleme işlevi
- **Boş Durum Yönetimi**: Kayıtlı oyun olmadığı durumlar için bilgilendirici görünüm
- **Zorluk Renk Kodlaması**: Zorluk seviyelerinin kolay tanınması için renk kodları
- **Oyun Yükleme**: Seçilen oyunu yüklemek için dokunma işlevi
- **CoreData Entegrasyonu**: Kayıtlı oyunları CoreData ile yönetme
- **Tarih Formatlama**: Kayıt tarihlerini okunaklı formatta gösterme
- **Dinamik Liste**: Kayıtlı oyunların dinamik olarak görüntülenmesi

---

## GameCompletionView.swift

GameCompletionView, oyun tamamlandığında kullanıcıya tebrik mesajı, oyun istatistiklerini ve skorları gösteren sonuç ekranı görünümüdür.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `difficulty` | 4 | `SudokuBoard.Difficulty` | Tamamlanan oyunun zorluk seviyesi |
| `timeElapsed` | 5 | `TimeInterval` | Oyunda geçen süre |
| `errorCount` | 6 | `Int` | Yapılan hata sayısı |
| `hintCount` | 7 | `Int` | Kullanılan ipucu sayısı |
| `score` | 8 | `Int` | Elde edilen toplam puan |
| `isNewHighScore` | 9 | `Bool` | Yeni bir rekor olup olmadığı |
| `onNewGame` | 10 | `() -> Void` | Yeni oyun başlatma closure'u |
| `onDismiss` | 11 | `() -> Void` | Görünümü kapatma closure'u |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 15-95 | Ana görünümü oluşturur |
| `formatTime(_:)` | 97-101 | Saniye cinsinden verilen süreyi dakika:saniye formatına çevirir |

### Önemli Özellikler

- **Oyun İstatistikleri**: Oyun süresi, hata sayısı, ipucu sayısı ve zorluk seviyesi gibi istatistikleri gösterir
- **Skor Gösterimi**: Elde edilen toplam puanı gösterir
- **Rekor Tespiti**: Yeni bir yüksek skor kırıldığında özel olarak vurgular
- **Yönlendirme Seçenekleri**: Yeni oyun başlatma veya görünümü kapatma seçenekleri sunar
- **Görsel Zenginlik**: İkonlar, renkler ve animasyonlar ile kullanıcı deneyimini zenginleştirir
- **İstatistik Satırları**: Amaç odaklı ve tutarlı bir düzenle istatistikleri görüntüler
- **Karanlık Mod Desteği**: Görünümde karanlık mod için uygun renk düzenlemeleri yapılır

---

## PencilMarksView.swift

PencilMarksView, Sudoku hücrelerinde kullanıcının not aldığı potansiyel değerleri (kalem işaretleri) gösteren görünümdür. Bu görünüm, 3x3 düzende 1-9 arası notları düzenli bir şekilde hücre içinde gösterir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `pencilMarks` | 4 | `Set<Int>` | Hücre için gösterilecek kalem işaretleri kümesi (1-9 arası sayılar) |
| `cellSize` | 5 | `CGFloat` | Dış hücrenin boyutu (piksel cinsinden) |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 7-59 | Kalem işaretlerini 3x3 grid içinde düzenli olarak gösteren görünümü oluşturur |

### Önemli Özellikler

- **Dinamik Boyutlandırma**: Hücre boyutuna göre otomatik olarak adapt olan boyutlar ve font ölçeklendirmesi
- **3x3 Grid Düzeni**: Sudoku oyun mantığına uygun 3x3 grid düzeni kullanarak kalem işaretlerinin kolay anlaşılmasını sağlar
- **Uzaysal Verimlilik**: Küçük alanda fazla bilgiyi düzgün şekilde göstermek için optimize edilmiş tasarım
- **Oransal Uygunluk**: Hücre boyutuna göre orantılı font ve ara boşluk ayarları
- **Seçici Görünürlük**: Yalnızca belirtilen sayıları gösterir, diğer hücreler boş kalır
- **Görsel Ayrım**: Kalem işaretleri ana sayılardan daha açık renkle gösterilerek ayırt edilir

---

## ScoreManager.swift

ScoreManager, Sudoku oyunundaki puan hesaplama, skorları kaydetme ve skor istatistiklerini yönetme işlemlerini gerçekleştiren singleton sınıftır.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `shared` | 5 | `ScoreManager` | ScoreManager sınıfının tek (singleton) örneği |
| `context` | 7 | `NSManagedObjectContext` | CoreData veri tabanı etkileşimleri için yönetilen nesne bağlamı |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `calculateScore(difficulty:timeElapsed:errorCount:hintCount:)` | 16-55 | Zorluk seviyesi, geçen süre, hata sayısı ve ipucu sayısına göre puan hesaplar |
| `saveScore(difficulty:timeElapsed:errorCount:hintCount:)` | 59-83 | Oyun skorunu CoreData'ya kaydeder |
| `getBestScore(for:)` | 87-104 | Belirli bir zorluk seviyesi için en yüksek puanlı skoru getirir |
| `getAverageScore(for:)` | 106-122 | Belirli bir zorluk seviyesi için ortalama skoru hesaplar |

### Önemli Özellikler

- **Zorluk Bazlı Puanlama**: Farklı zorluk seviyelerine göre değişen temel puan ve süre bonusları
- **Puan Kesintileri**: Hata ve ipucu kullanımına bağlı olarak puanlardan kesinti yapma mekanizması
- **Süre Bazlı Puan Bonusları**: Hızlı tamamlanan oyunlar için fazladan puan bonusları
- **CoreData Entegrasyonu**: Skorların kalıcı depolanması için CoreData kullanımı
- **İstatistik Hesaplama**: En iyi skorları ve ortalama performansı hesaplama yeteneği
- **Singleton Tasarım**: Uygulama genelinde tek bir skor yöneticisi örneği kullanımı
- **Hata Yönetimi**: Veri kaydetme ve alma işlemleri sırasında oluşabilecek hatalara karşı koruma

---

## TutorialManager.swift

TutorialManager, kullanıcıların oyun özelliklerini ve Sudoku stratejilerini öğrenmeleri için adaylı bir öğretici yöneten singleton sınıftır.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `shared` | 161 | `TutorialManager` | TutorialManager sınıfının tek (singleton) örneği |
| `isActive` | 164 | `Bool` | Öğreticinin şu anda aktif olup olmadığını belirtir |
| `currentStep` | 165 | `GameTutorialStep` | Mevcut öğretici adımı |
| `hasCompletedTutorial` | 166 | `Bool` | Kullanıcının öğreticiyi tamamlayıp tamamlamadığı |
| `completedInteractions` | 169 | `Set<GameTutorialStep>` | Kullanıcının tamamladığı etkileşimli adımların kümesi |
| `currentInteractionRequired` | 170 | `Bool` | Mevcut adımın kullanıcı etkileşimi gerektirip gerektirmediği |
| `showCompletionAnimation` | 173 | `Bool` | Adım tamamlama animasyonu gösterip göstermeme durumu |
| `hasSeenTutorial` | 176 | `Bool` | Kullanıcının daha önce öğreticiyi görüp görmediği |
| `showTutorialTips` | 177 | `Bool` | Öğretici ipucu göstermelerini etkinleştirme tercihi |
| `shouldBlockInteraction` | 180 | `Bool` | Öğretici sırasında kullanıcı etkileşimini engelleme durumu |
| `lastTutorialStep` | 183 | `Int` | Son kaydedilen öğretici adımı numarası |
| `cancellables` | 186 | `Set<AnyCancellable>` | Combine aboneliklerini takip etmek için kullanılan küme |
| `onUserInteractionNeeded` | 189 | `((GameTutorialStep) -> Void)?` | Kullanıcı etkileşimi gerektiğinde çağrılacak closure |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init()` | 191-210 | Sınıfı başlatır ve kayıtlı öğretici durumunu yükler |
| `startTutorial()` | 282-293 | Öğreticiyi başlatır veya devam ettirir |
| `showNextStep()` | 295-311 | Bir sonraki öğretici adımına geçer |
| `completeInteraction(for:)` | 312-325 | Belirli bir etkileşimli adımı tamamladı olarak işaretler |
| `resetTutorial()` | 327-340 | Öğreticiyi sıfırlar ve başlangıç durumuna getirir |
| `endTutorial()` | 342-348 | Öğreticiyi tamamlar ve kullanıcı tercihini kaydeder |

### Önemli Özellikler

- **Adım Bazlı Öğretici**: Oyun özelliklerini adım adım açıklayan yapılandırılmış öğretici sistemi
- **Etkileşimli Adımlar**: Kullanıcının denemesi gereken pratik adımlar içeren öğrenme deneyimi
- **İlerleme Kaydetme**: Kullanıcının kaldığı yerden devam edebilmesi için öğretici ilerlemesini otomatik kaydetme
- **Görsel Yönlendirmeler**: Animasyonlar ve vurgulamalar ile kullanıcının dikkatini önemli öğelere çekme
- **Özelleştirilebilir Deneyim**: Öğretici ipucu gösterimini kullanıcı tercihine göre ayarlama
- **Detaylı Açıklamalar**: Her adımda kapsamlı açıklamalar ve stratejiler sunma
- **Combine Entegrasyonu**: Reactive veri akışı ve durum yönetimi için Combine framework kullanımı

---

## LoginView.swift

LoginView, kullanıcıların hesaplarına giriş yapabilmesini sağlayan kimlik doğrulama ekranıdır. Kullanıcı adı ve şifre alan form içerir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `presentationMode` | 5 | `Environment<PresentationMode>` | Görünümün sunulma durumunu yönetir |
| `colorScheme` | 6 | `Environment<ColorScheme>` | Sistem renk şeması (açık/karanlık mod) |
| `isPresented` | 8 | `Binding<Bool>` | Görünümün gösterilme durumu |
| `currentUser` | 9 | `Binding<NSManagedObject?>` | Giriş yapan kullanıcının referansı |
| `username` | 11 | `String` | Kullanıcı adı giriş alanı |
| `password` | 12 | `String` | Şifre giriş alanı |
| `errorMessage` | 13 | `String` | Hata mesajı metni |
| `showError` | 14 | `Bool` | Hata alert'inin gösterilme durumu |
| `isLoading` | 15 | `Bool` | Yükleme/işlem durumu |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 17-125 | Ana görünümü oluşturur |
| `loginUser()` | 127-156 | Kullanıcı giriş işlemini gerçekleştirir ve doğrular |

### Önemli Özellikler

- **Gradient Arkaplan**: Kullanıcı deneyimini iyileştirmek için güzel gradient arkaplan tasarımı
- **Form Doğrulama**: Boş alan kontrolü ve hata mesajları ile giriş formunun doğrulanması
- **Asenkron Giriş**: Yükleme göstergesi ile geri planda giriş işleminin gerçekleştirilmesi
- **Güvenli Şifre Alanı**: Şifrenin güvenli bir şekilde girilmesi için SecureField kullanımı
- **Duyarlı Butonlar**: Formun durumuna göre butonların etkinliğini ve saydamlığını ayarlama
- **CoreData Entegrasyonu**: Kullanıcı doğrulama için CoreData'nın kullanılması
- **Hata Yönetimi**: Giriş hataları için bilgilendirici alert mesajları

---

## RegisterView.swift

RegisterView, kullanıcıların yeni hesap oluşturabilmesini sağlayan kayıt ekranıdır. Kişisel bilgiler, kullanıcı adı ve şifre gibi alanları içeren kapsamlı bir kayıt formu içerir.

### Değişkenler

| Değişken | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `presentationMode` | 5 | `Environment<PresentationMode>` | Görünümün sunulma durumunu yönetir |
| `colorScheme` | 6 | `Environment<ColorScheme>` | Sistem renk şeması (açık/karanlık mod) |
| `isPresented` | 8 | `Binding<Bool>` | Görünümün gösterilme durumu |
| `currentUser` | 9 | `Binding<NSManagedObject?>` | Kayıt olan kullanıcının referansı |
| `username` | 11 | `String` | Kullanıcı adı giriş alanı |
| `password` | 12 | `String` | Şifre giriş alanı |
| `confirmPassword` | 13 | `String` | Şifre onay alanı |
| `email` | 14 | `String` | E-posta giriş alanı |
| `name` | 15 | `String` | Ad soyad giriş alanı |
| `errorMessage` | 16 | `String` | Hata mesajı metni |
| `showError` | 17 | `Bool` | Hata alert'inin gösterilme durumu |
| `isLoading` | 18 | `Bool` | Yükleme/işlem durumu |

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `body` | 20-166 | Ana görünümü oluşturur |
| `isFormInvalid` | 168-170 | Form alanlarının geçerli olup olmadığını kontrol eder |
| `registerUser()` | 172-205 | Kullanıcı kayıt işlemini gerçekleştirir ve doğrular |

### Önemli Özellikler

- **Kapsamlı Form**: Ad soyad, e-posta, kullanıcı adı, şifre ve şifre onayı alanlarını içerir
- **Form Doğrulama**: Boş alan kontrolü, şifre eşleşme kontrolü gibi detaylı doğrulama işlemleri
- **Kullanıcı Geri Bildirimi**: Hata durumlarında açıklayıcı mesajlar gösterme
- **Güvenlik Önlemleri**: Şifre girişi için güvenli alan kullanımı
- **Gürsel Tasarım**: Gradient arkaplan ve özel stil butonlar ile kullanıcı dostu arayüz
- **Input Optimization**: E-posta alanı için özel klavye tipi ve otomatik büyük harf kapatma özelliği
- **Asenkron İşlem Yönetimi**: Arka planda kayıt işlemi sırasında yükleme göstergesi

---

## ColorExtension.swift

ColorExtension, SwiftUI'nin `Color` sınıfına ek özellikler ve kolay erişim sağlayan uzantı sınıfıdır. Hex kodu dönüştürme ve uygulama genelinde tutarlı renk kullanımı için özel tanımlanmış renkler içerir.

### Fonksiyonlar ve Özellikler

| Özellik/Fonksiyon | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `init(hex:)` | 5-27 | `Initializer` | Hex renk kodu (3, 6 veya 8 karakterli) ile renk oluşturma |
| `sudokuBackground` | 30 | `Color` | Sudoku arkaplanı için tanımlı renk |
| `sudokuCell` | 31 | `Color` | Sudoku hücreleri için tanımlı renk |
| `sudokuText` | 32 | `Color` | Sudoku metinleri için tanımlı renk |
| `sudokuAccent` | 33 | `Color` | Sudoku vurgu rengi |
| `sudokuSecondary` | 34 | `Color` | Sudoku ikincil renk |
| `modernBlue`, `modernLightBlue`, vb. | 37-45 | `Color` | Modern Sudoku renk paleti |
| `darkBg1`, `darkBg2`, `darkBg3` | 48-50 | `Color` | Koyu tema arka plan renkleri |
| `lightBg1`, `lightBg2`, `lightBg3` | 53-55 | `Color` | Açık tema arka plan renkleri |
| `darkModeBackground(for:)` | 58-68 | `Fonksiyon` | Karanlık mod için gradient arka plan rengi |
| `cardBackground(for:)` | 71-73 | `Fonksiyon` | Kart arka plan rengi |
| `buttonBackground(for:isSelected:)` | 76-82 | `Fonksiyon` | Buton arka plan rengi |
| `textColor(for:isHighlighted:)` | 85-91 | `Fonksiyon` | Metin rengi |

### Önemli Özellikler

- **Hex Kod Desteği**: 3, 6 ve 8 karakterli hex renk kodlarını (RGB ve ARGB) destekler
- **Dinamik Renk Yönetimi**: Renk şemasına (açık/karanlık mod) göre otomatik olarak değişen renkler
- **Tutarlı Renk Paleti**: Uygulama genelinde tutarlı renk kullanımı için önceden tanımlanmış renkler
- **Durum Bazlı Renkler**: Seçili, vurgulanmış gibi durumlara göre renk değişimleri
- **Gradient Desteği**: Arka planlar için gradient renk kombinasyonları
- **Uygulama Teması**: Modern ve temiz bir görünüm için özel renk teması

---

## ViewTransitionExtension.swift

ViewTransitionExtension, SwiftUI'nin animasyon ve geçiş efektlerini kolaylaştırmak için `AnyTransition` ve `View` sınıflarına ek özellikler sunan uzantı sınıfıdır. Uygulama genelinde tutarlı ve çekici animasyonlar kullanmayı sağlar.

### AnyTransition Uzantıları

| Uzantı | Satır | Açıklama |
|-----------|-------|----------|
| `slideFromRight` | 5-10 | Sağdan sola kaydırma geçiş efekti |
| `slideFromLeft` | 12-17 | Soldan sağa kaydırma geçiş efekti |
| `slideFromBottom` | 19-24 | Aşağıdan yukarıya kaydırma geçiş efekti |
| `slideFromTop` | 26-31 | Yukarıdan aşağıya kaydırma geçiş efekti |
| `scale` | 33-38 | Ölçeklendirme geçiş efekti |
| `flip` | 40-51 | 3D çevirme geçiş efekti |

### View Uzantıları

| Uzantı | Satır | Açıklama |
|-----------|-------|----------|
| `fadeInOut()` | 66-69 | Görünümü belirtilen süre boyunca solarak göster/gizle |
| `slideInFromTop()` | 72-76 | Görünümü yukarıdan kaydırarak göster/gizle |
| `slideInFromBottom()` | 79-83 | Görünümü aşağıdan kaydırarak göster/gizle |
| `slideInFromLeft()` | 86-90 | Görünümü soldan kaydırarak göster/gizle |
| `slideInFromRight()` | 93-97 | Görünümü sağdan kaydırarak göster/gizle |
| `scaleInOut()` | 100-104 | Görünümü ölçeklendirerek göster/gizle |
| `rotateInOut()` | 107-111 | Görünümü döndürerek göster/gizle |

### Özel Yapılar

| Yapı | Satır | Açıklama |
|-----------|-------|----------|
| `FlipModifier` | 55-61 | 3D döndürme efekti için özel modifier |

### Önemli Özellikler

- **Zengin Animasyon Kitaplığı**: Çeşitli görünüm geçişleri için hazır animasyon efektleri
- **Kodlama Kolaylığı**: Karmaşık geçiş efektlerini basit bir API ile kullanma imkanı
- **Özelleştirilebilir Parametreler**: Animasyon süresi, geçiş mesafesi gibi değerleri özelleştirme
- **Duruma Dayalı Görünüm Değişimleri**: Boolean değerlere bağlı olarak kolay animasyon kontrolü
- **3D Animasyon Desteği**: 3D döndürme ve çevirme efektleri için özel modifier
- **Estetik Kullanıcı Deneyimi**: Akıcı ve göz alıcı geçişlerle kullanıcı deneyimini zenginleştirme

---

## SudokuApp.swift

SudokuApp, uygulamayı başlatan ve genel yapılandırmayı yöneten ana uygulama dosyasıdır. Uygulama yaşam döngüsünü, CoreData entegrasyonunu, görünüm tercihlerini ve güç tasarrufu işlemlerini yönetir.

### Yardımcı Yapılar ve Uzantılar

| Yapı/Uzantı | Satır | Açıklama |
|-----------|-------|----------|
| `TextScaleKey` | 12-14 | Metin ölçeği için Environment anahtarı |
| `EnvironmentValues Extension` | 17-22 | Environment değerlerine `textScale` ekleme |
| `TextSizePreference enum` | 25-41 | Metin boyutu tercihi için özel tür (Küçük, Orta, Büyük) |
| `ColorManager struct` | 44-72 | Ana renkleri yöneten yapı |
| `InitializationErrorView` | 183-223 | Başlatma hatası durumunda gösterilecek görünüm |

### Değişkenler ve Özellikler

| Değişken/Özellik | Satır | Tür | Açıklama |
|----------|-------|-----|----------|
| `darkMode` | 75 | `Bool` (AppStorage) | Karanlık mod tercihi |
| `useSystemAppearance` | 76 | `Bool` (AppStorage) | Sistem görünümünü kullan tercihi |
| `textSizeString` | 77 | `String` (AppStorage) | Metin boyutu tercihi (default: "Orta") |
| `lastBackgroundTime` | 80 | `Double` (AppStorage) | Uygulamanın arka plana alınma zamanı |
| `gameResetTimeInterval` | 82 | `TimeInterval` | Oyunun sıfırlanması için gereken süre (120 sn) |
| `initializationError` | 88 | `Error?` (State) | Başlatma hatasını takip etme |
| `isInitialized` | 89 | `Bool` (State) | Başlatma durumunu takip etme |
| `textSizePreference` | 91-93 | `Computed property` | Seçili metin boyutunu veren hesaplanmış özellik |
| `persistenceController` | 96 | `PersistenceController` | CoreData yönetim sınıfı |
| `viewContext` | 97 | `NSManagedObjectContext` | CoreData bağlamı |

### Fonksiyonlar ve Yöntemler

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `init()` | 99-113 | Uygulama başlangıç ayarlarını yapılandırır |
| `body` | 115-181 | Ana uygulama yapısını ve yaşam döngüsü yönetimini sağlar |

### Yaşam Döngüsü Yönetimi

| Sahne Fazı | Satır | Açıklama |
|-----------|-------|----------|
| `.background` | 140-156 | Arka plana geçme durumunda aktif oyunu duraklatır ve zamanı kaydeder |
| `.active` | 157-177 | Aktif duruma geçtiğinde, arka planda geçen süreyi kontrol eder |

### Önemli Özellikler

- **Otomatik Duraklatma**: Uygulama arka plana alındığında aktif oyunu otomatik duraklatır
- **Zaman Aşımı Yönetimi**: 2 dakikadan fazla arka planda kalındığında oyunu sıfırlar
- **Özelleştirilebilir Görünüm**: Karanlık mod ve metin boyutu için kullanıcı tercihleri
- **Güç Tasarrufu**: Güç tasarrufu modunu destekler
- **CoreData Entegrasyonu**: Kalıcı veri saklamak için CoreData yapısı
- **Bildirim Sistemi**: Notifikasyon merkezini kullanarak uygulama durumlarını ileten sistem
- **Hata Yönetimi**: Başlatma hatalarını yönetmek için özel görünüm mekanizması
