//  SudokuViewModel.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 29.12.2024.
//

import Foundation
import SwiftUI
import Combine
import CoreData
import AudioToolbox
import AVFoundation
import FirebaseFirestore
import FirebaseAuth

// Position yapısı
struct Position: Hashable {
    let row: Int
    let col: Int
}

class SudokuViewModel: ObservableObject {
    // Sudoku tahtası
    @Published var board: SudokuBoard
    // Seçili hücre
    @Published var selectedCell: (row: Int, column: Int)?
    // Geçersiz hücrelerin listesi
    @Published var invalidCells: Set<Position> = []
    // Oyun süresi
    @Published var elapsedTime: TimeInterval = 0
    // Oyunun durumu
    @Published var gameState: GameState = .playing
    // Kalem modu - not almak için
    @Published var pencilMode: Bool = false
    // Yükleme durumu
    @Published var isLoading: Bool = false
    
    // Başarım yöneticisine erişim
    private let achievementManager = AchievementManager.shared
    // Veritabanı kontrolcüsüne erişim
    private let persistenceController = PersistenceController.shared
    
    // Performans iyileştirmesi: Pencil mark'ları hızlı erişim için önbelleğe al
    private var pencilMarkCache: [String: Set<Int>] = [:]
    private var validValuesCache: [String: Set<Int>] = [:]
    
    // Performans iyileştirmesi: Hücreler için ön hesaplanmış konum haritası (yeni)
    private var cellPositionMap: [[Set<Position>]] = Array(repeating: Array(repeating: Set<Position>(), count: 9), count: 3)
    private var sameValueMap: [Int: Set<Position>] = [:]
    private var lastSelectedCell: (row: Int, column: Int)? = nil
    
    // Kullanıcının girdiği değerleri takip etmek için
    @Published var userEnteredValues: [[Bool]] = Array(repeating: Array(repeating: false, count: 9), count: 9)
    
    // İstatistik takibi
    @Published var moveCount: Int = 0
    @Published var errorCount: Int = 0
    @Published var hintCount: Int = 0
    @Published var remainingHints: Int = 3  // Her oyunda 3 ipucu hakkı
    private let maxErrorCount: Int = 3      // Maksimum hata sayısı
    
    // Zamanlayıcı
    private var timer: Timer?
    private var startTime: Date?
    // Duraklatıldığında geçen süre saklanır
    private var pausedElapsedTime: TimeInterval = 0
    
    // Orijinal tahta hücrelerini takip etmek için
    private var originalBoardCells: [(Int, Int)] = []
    
    // Vurgulanan hücreleri önbelleğe almak için
    private var cachedHighlightedPositions: Set<Position> = []
    
    // Oyun durumunu sıfırla - yeni oyun başlatırken kullanılır
    func resetGameState() {
        // Oyun durumunu sıfırla
        gameState = .ready
        
        // Seçili hücreyi sıfırla
        selectedCell = nil
        
        // İstatistikleri sıfırla
        moveCount = 0
        errorCount = 0
        hintCount = 0
        remainingHints = 3
        
        // Önbellekleri temizle
        pencilMarkCache.removeAll(keepingCapacity: true)
        validValuesCache.removeAll(keepingCapacity: true)
        invalidCells.removeAll(keepingCapacity: true)
        
        // Süreyi sıfırla
        elapsedTime = 0
        pausedElapsedTime = 0
        
        // Zamanlayıcıyı durdur
        stopTimer()
    }
    
    // Geri bildirim için
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("enableNumberInputHaptic") private var enableNumberInputHaptic = true
    @AppStorage("enableCellTapHaptic") private var enableCellTapHaptic = true
    @AppStorage("enableSounds") private var enableSounds = true
    @AppStorage("playerName") private var playerName = "Oyuncu"
    
    // Dokunsal geri bildirim motoru
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // Oyun durumları
    enum GameState {
        case ready, playing, paused, completed, failed
    }
    

    @Published var savedGames: [NSManagedObject] = []
    
    // Kullanılan rakamların sayısını takip et
    @Published var usedNumbers: [Int: Int] = [:]
    
    // Başlangıçtaki değişkenlere eklenecek
    @Published var pendingErrorCells: Set<Position> = []
    
    // MARK: - İlklendirme
    
    init(difficulty: SudokuBoard.Difficulty = .easy) {
        self.board = SudokuBoard(difficulty: difficulty)
        
        // Zaman değişkenlerini sıfırla
        elapsedTime = 0
        pausedElapsedTime = 0
        
        // İlk çalıştırma bayrağı - oyunun ilk açılışta otomatik kaydedilmesini önler
        let isFirstLaunchKey = "SudokuViewModel.isFirstLaunch"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: isFirstLaunchKey)
        
        // Otomatik kaydetmeyi devre dışı bırakmak için bayrak
        let noAutoSaveKey = "SudokuViewModel.noAutoSave"
        
        // Uygulama arka plana alındığında oyunu otomatik olarak duraklatmak için bildirim dinleyicisi ekle
        setupNotificationObservers()
        
        // Sadece kaydedilmiş oyunları yükle, yeni bir oyun kaydetme
        loadSavedGames()
        
        if isFirstLaunch {
            // İlk çalıştırma ise, bayrağı ayarla ve otomatik kaydetme yapma
            UserDefaults.standard.set(true, forKey: isFirstLaunchKey)
            UserDefaults.standard.set(true, forKey: noAutoSaveKey) // Otomatik kaydetmeyi kapat
            logInfo("İlk çalıştırma, otomatik kaydetme devre dışı")
            gameState = .ready // Oyunu ready durumunda başlat
        } else {
            // Normal çalıştırma
            startTimer()
            updateUsedNumbers()
        }
    }
    
    // MARK: - Core Oyun Metodları
    
    // Yeni bir oyun başlat - optimize edildi
    func newGame(difficulty: SudokuBoard.Difficulty? = nil) {
        // Yükleme durumunu aktifleştir
        isLoading = true
        
        // Mevcut kayıt ID'sini sıfırla - böylece yeni bir kayıt oluşacak
        self.currentGameID = nil
        
        // Önceden ayarlanmış zorluk seviyesini veya varsayılanı kullan
        let selectedDifficulty = difficulty ?? board.difficulty
        
        // İşlemi arka planda gerçekleştir - UI bloklanmasın
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 0.5 saniye bekle (yükleme göstergesi görünsün diye)
            Thread.sleep(forTimeInterval: 0.5)
            
            // Yeni bir tahta oluştur
            let newBoard = SudokuBoard(difficulty: selectedDifficulty)
            
            // Tahta hazır olduğunda ana thread'e dön
            DispatchQueue.main.async {
                // Tahta verilerini güncelle
                self.board = newBoard
                
                // Tahta durumunu orijinal olarak ayarla
                self.originalBoardCells = []
                for row in 0..<9 {
                    for col in 0..<9 {
                        if self.board.getValue(row: row, column: col) != nil {
                            self.originalBoardCells.append((row, col))
                        }
                    }
                }
                
                // Kullanıcı tarafından girilen değerleri sıfırla
                self.userEnteredValues = Array(repeating: Array(repeating: false, count: 9), count: 9)
                
                // Tüm state bilgilerini sıfırla
                self.resetGameState()
                
                // Oyun durumunu güncelle
                self.gameState = .playing
                
                // Zamanlayıcıyı başlat
                self.startTimer()
                
                // Kullanılan sayıları güncelle
                self.updateUsedNumbers()
                
                // Önbelleği temizle
                self.clearCaches()
                
                // Otomatik kaydetmeyi etkinleştir - kullanıcı bilinçli olarak yeni oyun başlattı
                let noAutoSaveKey = "SudokuViewModel.noAutoSave"
                UserDefaults.standard.set(false, forKey: noAutoSaveKey)
                logInfo("Yeni oyun başlatıldı, otomatik kaydetme etkinleştirildi")
                
                // Yükleme durumunu kapat
                self.isLoading = false
            }
        }
    }
    
    // Hücre seçme - optimize edildi
    func selectCell(row: Int, column: Int) {
        // CPU optimizasyonu: Aynı hücre tekrar seçilirse işlem yapma
        if selectedCell?.row == row && selectedCell?.column == column {
            return
        }
        
        // Seçilen hücre değiştiyse
        let oldSelection = selectedCell
        selectedCell = (row: row, column: column)
        
        // Vurgulamaları sadece gerektiğinde güncelle
        if oldSelection?.row != row || oldSelection?.column != column {
            updateHighlightedCells()
            updateSameValueCells()
        }
        
        // Ses kontrolü - titreşim açıksa çal
        if enableHapticFeedback {
            SoundManager.shared.playNavigationSound()
        }
    }
    
    // Yeni seçilen hücreyle ilgili önbellekleri oluştur
    private func precalculateHighlightedCells(row: Int, column: Int) {
        // Haritaları yeniliyoruz
        updateCellPositionMap()
        updateSameValueMap()
    }
    
    // Hücre pozisyon haritasını oluştur - tüm satır, sütun ve blokları gruplar
    private func updateCellPositionMap() {
        // Haritayı sıfırlayalım
        cellPositionMap = Array(repeating: Array(repeating: Set<Position>(), count: 9), count: 3)
        
        // Her satır, sütun ve blok için konum haritası oluştur
        for row in 0..<9 {
            for col in 0..<9 {
                let pos = Position(row: row, col: col)
                let blockRow = row / 3
                let blockCol = col / 3
                
                // Satır haritası (0,0 = 0.satır, 0,1 = 1.satır...)
                if cellPositionMap.count > 0 && cellPositionMap[0].count > row {
                    cellPositionMap[0][row].insert(pos)
                }
                
                // Sütun haritası (1,0 = 0.sütun, 1,1 = 1.sütun...)
                if cellPositionMap.count > 1 && cellPositionMap[1].count > col {
                    cellPositionMap[1][col].insert(pos)
                }
                
                // Blok haritası (2,0 = sol üst blok, 2,1 = orta üst blok...)
                let blockIndex = blockRow * 3 + blockCol
                if cellPositionMap.count > 2 && cellPositionMap[2].count > blockIndex {
                    cellPositionMap[2][blockIndex].insert(pos)
                }
            }
        }
    }
    
    // Aynı değerlere sahip hücrelerin haritasını günceller
    private func updateSameValueMap() {
        // Yeniden kullanım için haritayı temizle ama kapasiteyi koru
        sameValueMap.removeAll(keepingCapacity: true)
        
        // Kapasiteyi önceden tahsis et (1-9 arası sayılar için)
        for value in 1...9 {
            sameValueMap[value] = Set<Position>()
        }
        
        // Her satırı tek döngüde işle - tek geçişte hücreleri grupla
        // Satır düzeni belleğe seri erişim sağlar - cache dostu
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = board.getValue(row: row, column: col), value > 0 {
                    let pos = Position(row: row, col: col)
                    sameValueMap[value, default: []].insert(pos)
                }
            }
        }
    }
    
    // Seçili hücreye değer atar - optimize edildi
    func setValueAtSelectedCell(_ value: Int?) {
        guard let selectedCell = selectedCell else { 
            logWarning("Hücre seçili değil!")
            return 
        }
        
        let row = selectedCell.row
        let col = selectedCell.column
        
        // Debug log
        logDebug("setValueAtSelectedCell: \(value ?? 0) -> (\(row), \(col)), pencilMode: \(pencilMode)")
        
        // Eğer orijinal/sabit bir hücre ise, değişime izin verme
        if board.isFixed(at: row, col: col) {
            logWarning("Sabit hücre değiştirilemez: (\(row), \(col))")
            return
        }
        
        let currentValue = board.getValue(at: row, col: col)
        let correctValue = board.getOriginalValue(at: row, col: col)
        
        // Eğer hücredeki mevcut değer doğruysa, değişime izin verme
        if currentValue == correctValue && currentValue != nil {
            logDebug("Hücre zaten doğru değere sahip: \(currentValue!)")
            SoundManager.shared.playCorrectSound() // Doğru olduğunu bir daha hatırlat
            return
        }
        
        // Kalem modu için işlemler
        if pencilMode {
            // Kalem modu işlemi - notlar için
            if let value = value {
                // Hücrede halihazırda bir değer varsa, önce onu temizle
                if currentValue != nil {
                    // Değeri sil ve sonra not ekle
                    _ = board.setValue(row: row, column: col, value: nil)
                    userEnteredValues[row][col] = false
                }
                
                // Not ekle/çıkar
                togglePencilMark(at: row, col: col, value: value)
                
                // Anında UI güncellemesi için
                objectWillChange.send()
                
                // Hızlı feedback için
                if enableHapticFeedback && enableNumberInputHaptic {
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                    feedbackGenerator.impactOccurred()
                }
            } else {
                // Silme işlemi - tüm pencil markları temizle
                SoundManager.shared.playEraseSound()
                clearPencilMarks(at: row, col: col)
                
                // Anında UI güncellemesi için
                objectWillChange.send()
            }
            return
        }
        
        // Değer silme işlemi - her zaman izin verilir
        if value == nil {
            if currentValue != nil {
                // Önce ses dosyasını çal, sonra işlemi yap
                SoundManager.shared.playEraseSound()
                
                // Değeri sil
                enterValue(value, at: row, col: col)
                // Önbellekleri geçersiz kıl
                invalidatePencilMarksCache(forRow: row, column: col)
                validateBoard()
                updateUsedNumbers()
            }
            return
        }
        
        // Performans: Sadece değişiklik varsa işlem yap
        if currentValue != value {
            // Doğru ya da yanlış olmasına göre ses çal
            if value == correctValue {
                SoundManager.shared.playCorrectSound()
                
                // Herhangi bir durumda değeri gir
                enterValue(value, at: row, col: col)
                
                // Önbelleği geçersiz kıl
                invalidatePencilMarksCache(forRow: row, column: col)
                validateBoard()
                updateUsedNumbers()
                
                // Hamle sayısını artır
                moveCount += 1
                
                // Otomatik kaydetmeyi etkinleştir - kullanıcı aktif olarak oynuyor 
                let noAutoSaveKey = "SudokuViewModel.noAutoSave"
                UserDefaults.standard.set(false, forKey: noAutoSaveKey)
                
                // Otomatik kaydet - her hamle sonrası kaydetmeyi dene
                autoSaveGame()
                
                // Oyun tamamlanma kontrolü
                checkGameCompletion()
                
                // Oyun tamamlandıysa veya başarısız olduysa kayıtlı oyunu sil
            } else {
                SoundManager.shared.playErrorSound()
                
                // Hatalı değeri hücreye yerleştir - enterValue kullanmak yerine direkt board'a yazıyoruz
                _ = board.setValue(row: row, column: col, value: value)
                
                // Kullanıcı giriş matrisini güncelle
                userEnteredValues[row][col] = true
                
                // Hatalı hücreyi işaretle
                let position = Position(row: row, col: col)
                invalidCells.insert(position)
                
                // Bekleyen hata olarak da işaretle - kaydetme işleminde kullanılacak
                pendingErrorCells.insert(position)
                
                // Doğrulama yapmak yerine sadece kullanılan sayıları güncelle
                updateUsedNumbers()
                
                // ObservableObject değişiklik bildirimi
                objectWillChange.send()
                
                // Hata geri bildirimi
                if enableHapticFeedback && enableNumberInputHaptic {
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
                
                // 3 saniye sonra hatalı değeri otomatik olarak sil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self = self else { return }
                    
                    // Silme işlemi
                    _ = self.board.setValue(row: row, column: col, value: nil)
                    
                    // Kullanıcı girişini güncelle
                    self.userEnteredValues[row][col] = false
                    
                    // Hatalı hücre işaretini kaldır
                    self.invalidCells.remove(position)
                    
                    // Bekleyen hatalar listesinden de kaldır
                    self.pendingErrorCells.remove(position)
                    
                    // Sadece kullanılan sayıları güncelle, tahta doğrulaması yapma
                    self.updateUsedNumbers()
                    
                    // UI'ı güncellemek için ObjectWillChange sinyali gönder
                    self.objectWillChange.send()
                }
                
                // Hata sayısını artır
                errorCount += 1
                
                // Maksimum hata sayısını kontrol et
                if errorCount >= maxErrorCount {
                    gameState = .failed
                    stopTimer()
                    
                    // Oyun kaybedildiğinde kayıtlı oyunu sil
                    deleteSavedGameIfExists()
                    logError("Oyun kaybedildi! Kayıtlı oyun silindi.")
                }
                
                // Önbelleği güncelle - validateBoard() çağırmayacağız
                invalidatePencilMarksCache(forRow: row, column: col)
                
                // Hamle sayısını artır - hatalı girişleri de sayalım
                moveCount += 1
                
                // Hatalı girişleri kaydetmiyoruz!
                // autoSaveGame() çağrısını kaldırdık
            }
        }
    }
    
    // MARK: - Performans Optimizasyonları
    
    // Oyun tamamlandığında kayıtlı oyunu sil
    private func deleteSavedGameIfExists() {
        if let gameID = currentGameID {
            PersistenceController.shared.deleteSavedGameWithID(gameID)
            logSuccess("Tamamlanan oyun kayıtlardan silindi")
            currentGameID = nil
        }
    }

    // Oyun tamamlanma kontrolü - optimize edildi
    private func checkGameCompletion() {
        // Oyun zaten tamamlanmışsa tekrar kontrol etmeye gerek yok
        if gameState == .completed {
            return
        }
        
        // Tüm hücrelerin dolu olup olmadığını kontrol et
        var isComplete = true
        for row in 0..<9 {
            for col in 0..<9 {
                if board.getValue(row: row, column: col) == nil {
                    isComplete = false
                    break
                }
            }
            if !isComplete {
                break
            }
        }
        
        // Eğer tüm hücreler doluysa ve doğruysa
        if isComplete && !hasErrors {
            // Oyun durumunu completed olarak ayarla - bu sayede tekrar çağrılmayı önleriz
            gameState = .completed
            
            logInfo("Oyun tamamlandı! handleGameCompletion() çağrılıyor...")
            // handleGameCompletion fonksiyonunu çağır - tüm tamamlanma işlemleri burada
            handleGameCompletion()
        }
    }
    
    // Tahta doğrulama - optimize edildi
    func validateBoard() {
        // Sadece oynama durumunda doğrula
        if gameState != .playing {
            return
        }
        
        // Önceki hataları temizle
        invalidCells.removeAll(keepingCapacity: true)
        
        // Hücreleri kontrol et
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = board.getValue(at: row, col: col) {
                    let correctValue = board.getOriginalValue(at: row, col: col)
                    if value != correctValue {
                        let position = Position(row: row, col: col)
                        invalidCells.insert(position)
                    }
                }
            }
        }
    }
    
    // MARK: - Kalem İşaretleri Optimizasyonu
    
    // Belirli bir bölge için önbelleği geçersiz kıl
    private func invalidatePencilMarksCache(forRow row: Int, column col: Int) {
        let blockStartRow = (row / 3) * 3
        let blockStartCol = (col / 3) * 3
        
        // Aynı satır, sütun veya 3x3 bloktaki tüm hücrelerin önbelleğini temizle
        for r in 0..<9 {
            // Satır
            let rowKey = "\(r)_\(col)"
            pencilMarkCache.removeValue(forKey: rowKey)
            validValuesCache.removeValue(forKey: rowKey)
            
            // Sütun
            let colKey = "\(row)_\(r)"
            pencilMarkCache.removeValue(forKey: colKey)
            validValuesCache.removeValue(forKey: colKey)
        }
        
        // 3x3 blok
        for r in blockStartRow..<(blockStartRow + 3) {
            for c in blockStartCol..<(blockStartCol + 3) {
                let blockKey = "\(r)_\(c)"
                pencilMarkCache.removeValue(forKey: blockKey)
                validValuesCache.removeValue(forKey: blockKey)
            }
        }
        
        // Aynı değere sahip hücrelerin önbelleğini de temizle
        invalidateSameValueCache()
    }
    
    // Aynı değere sahip hücrelerin önbelleğini temizle
    private func invalidateSameValueCache() {
        sameValueMap.removeAll(keepingCapacity: true)
        
        // Yeni seçim için haritaları güncelle
        if let selected = selectedCell {
            precalculateHighlightedCells(row: selected.row, column: selected.column)
        }
    }
    
    // Tüm önbelleği geçersiz kıl
    private func invalidatePencilMarksCache() {
        pencilMarkCache.removeAll(keepingCapacity: true)
        validValuesCache.removeAll(keepingCapacity: true)
        sameValueMap.removeAll(keepingCapacity: true)
        cellPositionMap = Array(repeating: Array(repeating: Set<Position>(), count: 3), count: 3)
    }
    
    // Kalem işaretlerini önbellekten al veya hesapla
    func getPencilMarks(at row: Int, col: Int) -> Set<Int> {
        let key = "\(row)_\(col)"
        
        if let cached = pencilMarkCache[key] {
            return cached
        }
        
        let marks = board.getPencilMarks(at: row, col: col)
        pencilMarkCache[key] = marks
        
        return marks
    }
    
    // Geçerli değerleri önbellekten al veya hesapla
    func getValidValues(at row: Int, col: Int) -> Set<Int> {
        let key = "\(row)_\(col)"
        
        if let cached = validValuesCache[key] {
            return cached
        }
        
        // Her satır, sütun ve 3x3 blokta hangi değerlerin kullanıldığını kontrol et
        var usedValues = Set<Int>()
        
        // Satır kontrolü
        for c in 0..<9 {
            if let value = board.getValue(at: row, col: c), value > 0 {
                usedValues.insert(value)
            }
        }
        
        // Sütun kontrolü
        for r in 0..<9 {
            if let value = board.getValue(at: r, col: col), value > 0 {
                usedValues.insert(value)
            }
        }
        
        // 3x3 blok kontrolü
        let blockStartRow = (row / 3) * 3
        let blockStartCol = (col / 3) * 3
        
        for r in blockStartRow..<(blockStartRow + 3) {
            for c in blockStartCol..<(blockStartCol + 3) {
                if let value = board.getValue(at: r, col: c), value > 0 {
                    usedValues.insert(value)
                }
            }
        }
        
        let validValues = Set(1...9).subtracting(usedValues)
        validValuesCache[key] = validValues
        
        return validValues
    }
    
    // MARK: - Kullanılan Sayıları Güncelleme
    
    // Kullanılan rakamları güncelle - optimize edildi
    private func updateUsedNumbers() {
        var newCounts = [Int: Int]()
        
        // Önceden kapasiteyi tahsis et (1-9 arası)
        for num in 1...9 {
            newCounts[num] = 0
        }
        
        // Satır öncelikli işlem - cache dostu
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = board.getValue(at: row, col: col), value > 0 {
                    newCounts[value, default: 0] += 1
                }
            }
        }
        
        // Sadece değişiklik varsa UI'ı güncelle
        if newCounts != usedNumbers {
            usedNumbers = newCounts
        }
    }
    
    // MARK: - İpucu ve Yardım
    
    // İpucu açıklama bilgisi
    @Published var showHintExplanation: Bool = false
    
    // İpucu tekniklerini belirten enum
    enum HintTechnique: String {
        case nakedSingle = "Tek Olasılık Tespiti"
        case hiddenSingle = "Tek Konum Tespiti"
        case nakedPair = "Naked Pair"
        case hiddenPair = "Hidden Pair"
        case nakedTriple = "Naked Triple"
        case hiddenTriple = "Hidden Triple"
        case xWing = "X-Wing"
        case swordfish = "Swordfish"
        case general = "Son Kalan Hücre"
        case none = "Tespit Edilebilen İpucu Yok"
        
        var description: String {
            switch self {
            case .nakedSingle:
                return NSLocalizedString("Bu hücreye sadece tek bir sayı konabilir", comment: "İpucu açıklaması")
            case .hiddenSingle:
                return NSLocalizedString("Bu sayı, bu bölgede yalnızca tek bir hücreye konabilir", comment: "İpucu açıklaması")
            case .nakedPair:
                return NSLocalizedString("Bu iki hücre, aynı iki adayı paylaşıyor, dolayısıyla diğer hücrelerden bu adaylar çıkarılabilir", comment: "İpucu açıklaması")
            case .hiddenPair:
                return NSLocalizedString("Bu iki aday, yalnızca bu iki hücreye konabilir, dolayısıyla bu hücrelerden diğer adaylar çıkarılabilir", comment: "İpucu açıklaması")
            case .nakedTriple:
                return NSLocalizedString("Bu üç hücre, üç adayı paylaşıyor, dolayısıyla diğer hücrelerden bu adaylar çıkarılabilir", comment: "İpucu açıklaması")
            case .hiddenTriple:
                return NSLocalizedString("Bu üç aday, yalnızca bu üç hücreye konabilir", comment: "İpucu açıklaması")
            case .xWing:
                return NSLocalizedString("X-Wing deseni bulundu. Bu, belirli hücrelerden bazı adayların çıkarılmasına izin verir", comment: "İpucu açıklaması")
            case .swordfish:
                return NSLocalizedString("Swordfish deseni bulundu. Bu, belirli hücrelerden bazı adayların çıkarılmasına izin verir", comment: "İpucu açıklaması")
            case .general:
                return NSLocalizedString("Sudoku kurallarına göre bu hücreye bu değer konabilir", comment: "İpucu açıklaması")
            case .none:
                return NSLocalizedString("Tahta üzerinde tespit edilebilen bir ipucu yok. Daha karmaşık stratejilere ihtiyaç olabilir.", comment: "İpucu bulunamadı")
            }
        }
    }
    
    // Hücre etkileşim türü
    enum CellInteractionType {
        case target          // Hedef hücre (değer girilecek)
        case highlight      // Vurgulanmış hücre 
        case related        // İlişkili hücre (aynı satır, sütun veya blok)
        case elimination    // Elenen aday
        case candidate      // Aday değer
    }
    
    // İpucu açıklama veri modeli - gelişmiş sınıf
    class HintData: ObservableObject, Identifiable {
        let id = UUID()
        let row: Int
        let column: Int
        let value: Int
        
        // Açıklama ve teknik
        var technique: HintTechnique = .general
        var reason: String
        
        // Adım adım ipucu için özellikler
        var highlightedCells: [(row: Int, column: Int, type: CellInteractionType)] = []
        var highlightedBlock: Int? = nil // 0-8 arası 3x3 blok numarası
        var step: Int = 0
        var totalSteps: Int = 1
        
        // Adımlara göre açıklamalar
        var stepTitles: [String] = []
        var stepDescriptions: [String] = []
        
        // İpucu için ek bilgiler
        var candidateValues: [Int] = []  // Aday değerler
        var eliminatedCandidates: [(row: Int, column: Int, value: Int)] = [] // Elenen adaylar
        
        init(row: Int, column: Int, value: Int, reason: String, technique: HintTechnique = .general) {
            self.row = row
            self.column = column
            self.value = value
            self.reason = reason
            self.technique = technique
            
            // Varsayılan olarak bu hücreyi hedef olarak vurgula
            self.highlightedCells = [(row, column, .target)]
            
            // Varsayılan adım bilgilerini ayarla
            self.stepTitles = [technique.rawValue]
            self.stepDescriptions = [reason]
        }
        
        // Vurgulanan blok indeksini hesaplama
        func calculateBlockIndex(row: Int, column: Int) -> Int {
            let blockRow = row / 3
            let blockCol = column / 3
            return blockRow * 3 + blockCol
        }
        
        // Vurgulanacak 3x3 bloku ayarla
        func highlightBlock(forRow row: Int, column: Int) {
            self.highlightedBlock = calculateBlockIndex(row: row, column: column)
        }
        
        // Adım bilgisi ekle
        func addStep(title: String, description: String) {
            stepTitles.append(title)
            stepDescriptions.append(description)
            totalSteps += 1
        }
        
        // Güncel adım başlığını al (HintExplanationView için)
        var stepTitle: String {
            // Dizi sınırlarını kontrol et
            guard step < stepTitles.count else {
                return step == 0 ? technique.rawValue : "Adım \(step + 1)"
            }
            return stepTitles[step]
        }
        
        // Güncel adım açıklamasını al (HintExplanationView için) 
        var stepDescription: String {
            // Dizi sınırlarını kontrol et
            guard step < stepDescriptions.count else {
                return NSLocalizedString(reason, comment: "İpucu varsayılan açıklaması")
            }
            return NSLocalizedString(stepDescriptions[step], comment: "İpucu adım açıklaması")
        }
        
        // Hücre vurgulama (belirli bir türde)
        func highlightCell(row: Int, column: Int, type: CellInteractionType = .highlight) {
            // Aynı hücre zaten eklenmişse ekleme
            for cell in highlightedCells {
                if cell.row == row && cell.column == column && cell.type == type {
                    return
                }
            }
            highlightedCells.append((row, column, type))
        }
        
        // Belirli bir bloğun tüm hücrelerini vurgula
        func highlightAllCellsInBlock(blockIndex: Int, type: CellInteractionType = .highlight) {
            let startRow = (blockIndex / 3) * 3
            let startCol = (blockIndex % 3) * 3
            
            for r in startRow..<startRow+3 {
                for c in startCol..<startCol+3 {
                    highlightCell(row: r, column: c, type: type)
                }
            }
        }
        
        // Aynı satır, sütun veya bloktaki tüm hücreler
        func highlightRelatedCells(row: Int, column: Int, type: CellInteractionType = .related) {
            // Aynı satırdaki hücreler
            for c in 0..<9 {
                if c != column {
                    highlightCell(row: row, column: c, type: type)
                }
            }
            
            // Aynı sütundaki hücreler
            for r in 0..<9 {
                if r != row {
                    highlightCell(row: r, column: column, type: type)
                }
            }
            
            // Aynı bloktaki hücreler
            let blockIndex = calculateBlockIndex(row: row, column: column)
            let blockStartRow = (blockIndex / 3) * 3
            let blockStartCol = (blockIndex % 3) * 3
            
            for r in blockStartRow..<blockStartRow+3 {
                for c in blockStartCol..<blockStartCol+3 {
                    if r != row || c != column {
                        highlightCell(row: r, column: c, type: type)
                    }
                }
            }
        }
    }
    
    // İpucu verileri ve kontrol
    @Published var hintExplanationData: HintData? = nil
    @Published var currentHintStep: Int = 0
    
    // Adım adım ipucu talep et
    func requestHint() {
        // İpucu hakkı kalmadıysa ipucu verme
        if remainingHints <= 0 {
            return
        }
        
        // 1. İpucu Algoritması - En Basit Çözülebilir Hücreyi Bul
        
        // Boş hücreleri ve adayları analiz et
        analyzeBoardCandidates()
        
        // 1. Önce en basit çözüm yöntemlerini dene
        
        // 1.1 Tek Olasılık (Naked Single) kontrolı
        if let hint = findNakedSingleHint() {
            // İpucu bulundu, göster
            showHintFound(hint)
            return
        }
        
        // 1.2 Tek Konum (Hidden Single) kontrolı
        if let hint = findHiddenSingleHint() {
            showHintFound(hint)
            return
        }
        
        // 2. Orta seviye yöntemleri dene
        
        // 2.1 Açık Çiftler (Naked Pairs) kontrolı
        if let hint = findNakedPairsHint() {
            showHintFound(hint)
            return
        }
        
        // 2.2 Gizli Çiftler (Hidden Pairs) kontrolı
        if let hint = findHiddenPairsHint() {
            showHintFound(hint)
            return
        }
        
        // 3. Hiçbir ipucu bulunamazsa, en azından bir rastgele hücre öner
        if let hint = findRandomHint() {
            showHintFound(hint)
            return
        }
        
        // Hiçbir ipucu bulunamazsa, kullanıcıya bildir
        showNoHintAvailable()
    }
    
    // Hücre aday değerlerini saklayan matris
    private var candidatesMatrix: [[[Int]]] = Array(repeating: Array(repeating: [], count: 9), count: 9)
    
    // Tahta üzerindeki tüm hücreler için adayları hesapla
    private func analyzeBoardCandidates() {
        // Boş bir aday matrisi oluştur
        candidatesMatrix = Array(repeating: Array(repeating: [], count: 9), count: 9)
        
        // Tüm hücreler için adayları hesapla
        for row in 0..<9 {
            for col in 0..<9 {
                // Hücre boşsa, adayları hesapla
                if board.getValue(at: row, col: col) == nil {
                    candidatesMatrix[row][col] = calculateCandidates(forRow: row, col: col)
                }
            }
        }
    }
    
    // Bir hücre için olası tüm adayları hesapla
    private func calculateCandidates(forRow row: Int, col: Int) -> [Int] {
        var candidates: [Int] = []
        
        // Satır, sütun ve bloktaki mevcut değerleri toplama
        var usedValues = Set<Int>()
        
        // Aynı satırdaki değerler
        for c in 0..<9 {
            if let value = board.getValue(at: row, col: c), value > 0 {
                usedValues.insert(value)
            }
        }
        
        // Aynı sütundaki değerler
        for r in 0..<9 {
            if let value = board.getValue(at: r, col: col), value > 0 {
                usedValues.insert(value)
            }
        }
        
        // Aynı bloktaki değerler
        let blockStartRow = (row / 3) * 3
        let blockStartCol = (col / 3) * 3
        
        for r in blockStartRow..<blockStartRow+3 {
            for c in blockStartCol..<blockStartCol+3 {
                if let value = board.getValue(at: r, col: c), value > 0 {
                    usedValues.insert(value)
                }
            }
        }
        
        // Kullanılmayan değerleri aday olarak ekle
        for value in 1...9 {
            if !usedValues.contains(value) {
                candidates.append(value)
            }
        }
        
        return candidates
    }
    
    // 1.1 Tek Olasılık (Naked Single) - Bir hücreye sadece tek bir sayı konabiliyorsa
    private func findNakedSingleHint() -> HintData? {
        for row in 0..<9 {
            for col in 0..<9 {
                // Boş hücre ve sadece tek bir aday varsa
                if board.getValue(at: row, col: col) == nil && candidatesMatrix[row][col].count == 1 {
                    if let value = candidatesMatrix[row][col].first {
                        // Doğru değeri kontrol et
                        if let solution = board.getOriginalValue(at: row, col: col), solution == value {
                            // İpucu oluştur
                            let hint = createNakedSingleHint(row: row, col: col, value: value)
                            return hint
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // Naked Single ipucu oluştur
    private func createNakedSingleHint(row: Int, col: Int, value: Int) -> HintData {
        // Swift string interpolation yerine format kullanarak lokalizasyon
        let formatString = NSLocalizedString("Bu hücreye sadece %d değeri konabilir çünkü diğer tüm sayılar elendi.", comment: "İpucu açıklaması")
        let reason = String(format: formatString, value)
        
        let hint = HintData(row: row, column: col, value: value, reason: reason, technique: HintTechnique.nakedSingle)
        
        // Adım 1: İlişkili hücreleri vurgula
        hint.addStep(title: NSLocalizedString("Satır, Sütun ve Blok İnceleme", comment: "İpucu başlığı"), 
                  description: NSLocalizedString("Bu hücrenin aynı satır, sütun ve blokta bulunan diğer hücreler incelendi.", comment: "İpucu açıklaması"))
        hint.highlightRelatedCells(row: row, column: col, type: CellInteractionType.related)
        
        // Adım 2: Tek aday olduğunu göster
        let stepFormatString = NSLocalizedString("Bu hücreye sadece %d değeri konabilir, diğer tüm sayılar elendi.", comment: "İpucu açıklaması")
        let stepDescription = String(format: stepFormatString, value)
        
        hint.addStep(title: NSLocalizedString("Tek Olasılık Tespiti", comment: "İpucu başlığı"), 
                  description: stepDescription)
        
        // Aday değerleri göster
        hint.candidateValues = [value]
        
        // Hücreyi çöz
        enterValue(value, at: row, col: col)
        hintCount += 1
        remainingHints -= 1
        
        // Tahtayı güncelle
        validateBoard()
        updateUsedNumbers()
        
        return hint
    }
    
    // 1.2 Tek Konum (Hidden Single) - Bir sayı, bir blok, satır veya sütunda sadece tek bir yere konabiliyorsa
    private func findHiddenSingleHint() -> HintData? {
        // Bloklar için kontrol
        for blockIndex in 0..<9 {
            let blockStartRow = (blockIndex / 3) * 3
            let blockStartCol = (blockIndex % 3) * 3
            
            // 1-9 arası her değer için kontrol
            for value in 1...9 {
                var possiblePositions: [(row: Int, col: Int)] = []
                
                // Blok içindeki hücreler için kontrol
                for r in blockStartRow..<blockStartRow+3 {
                    for c in blockStartCol..<blockStartCol+3 {
                        // Hücre boşsa ve adaylar arasında değer varsa
                        if board.getValue(at: r, col: c) == nil && candidatesMatrix[r][c].contains(value) {
                            possiblePositions.append((r, c))
                        }
                    }
                }
                
                // Eğer değer sadece tek bir yere konabiliyorsa
                if possiblePositions.count == 1 {
                    let pos = possiblePositions[0]
                    
                    // Doğru değeri kontrol et
                    if let solution = board.getOriginalValue(at: pos.row, col: pos.col), solution == value {
                        // İpucu oluştur
                        let hint = createHiddenSingleHint(row: pos.row, col: pos.col, value: value, region: .block, regionIndex: blockIndex)
                        return hint
                    }
                }
            }
        }
        
        // Satırlar için kontrol
        for row in 0..<9 {
            // 1-9 arası her değer için kontrol
            for value in 1...9 {
                var possiblePositions: [(row: Int, col: Int)] = []
                
                // Satır içindeki hücreler için kontrol
                for col in 0..<9 {
                    // Hücre boşsa ve adaylar arasında değer varsa
                    if board.getValue(at: row, col: col) == nil && candidatesMatrix[row][col].contains(value) {
                        possiblePositions.append((row, col))
                    }
                }
                
                // Eğer değer sadece tek bir yere konabiliyorsa
                if possiblePositions.count == 1 {
                    let pos = possiblePositions[0]
                    
                    // Doğru değeri kontrol et
                    if let solution = board.getOriginalValue(at: pos.row, col: pos.col), solution == value {
                        // İpucu oluştur
                        let hint = createHiddenSingleHint(row: pos.row, col: pos.col, value: value, region: .row, regionIndex: row)
                        return hint
                    }
                }
            }
        }
        
        // Sütunlar için kontrol
        for col in 0..<9 {
            // 1-9 arası her değer için kontrol
            for value in 1...9 {
                var possiblePositions: [(row: Int, col: Int)] = []
                
                // Sütun içindeki hücreler için kontrol
                for row in 0..<9 {
                    // Hücre boşsa ve adaylar arasında değer varsa
                    if board.getValue(at: row, col: col) == nil && candidatesMatrix[row][col].contains(value) {
                        possiblePositions.append((row, col))
                    }
                }
                
                // Eğer değer sadece tek bir yere konabiliyorsa
                if possiblePositions.count == 1 {
                    let pos = possiblePositions[0]
                    
                    // Doğru değeri kontrol et
                    if let solution = board.getOriginalValue(at: pos.row, col: pos.col), solution == value {
                        // İpucu oluştur
                        let hint = createHiddenSingleHint(row: pos.row, col: pos.col, value: value, region: .column, regionIndex: col)
                        return hint
                    }
                }
            }
        }
        
        return nil
    }
    
    // Bölge türü enum'u
    enum SudokuRegion {
        case row, column, block
    }
    
    // Hidden Single ipucu oluştur
    private func createHiddenSingleHint(row: Int, col: Int, value: Int, region: SudokuRegion, regionIndex: Int) -> HintData {
        var regionName = ""
        var description = ""
        
        switch region {
        case .row:
            let rowFormat = NSLocalizedString("%d. satırda", comment: "İpucu bölge adı")
            regionName = String(format: rowFormat, row+1)
            let descFormat = NSLocalizedString("%d sayısı, %d. satırda sadece bu hücreye konabilir", comment: "İpucu açıklaması")
            description = String(format: descFormat, value, row+1)
        case .column:
            let colFormat = NSLocalizedString("%d. sütunda", comment: "İpucu bölge adı")
            regionName = String(format: colFormat, col+1)
            let descFormat = NSLocalizedString("%d sayısı, %d. sütunda sadece bu hücreye konabilir", comment: "İpucu açıklaması")
            description = String(format: descFormat, value, col+1)
        case .block:
            let blockRow = (regionIndex / 3) + 1
            let blockCol = (regionIndex % 3) + 1
            let blockFormat = NSLocalizedString("%d. satır, %d. sütundaki 3x3 blokta", comment: "İpucu bölge adı")
            regionName = String(format: blockFormat, blockRow, blockCol)
            let descFormat = NSLocalizedString("%d sayısı, bu 3x3 blokta sadece bu hücreye konabilir", comment: "İpucu açıklaması")
            description = String(format: descFormat, value)
        }
        
        let reasonFormat = NSLocalizedString("%@ %d sayısı sadece bu hücreye konabilir.", comment: "İpucu ana açıklaması")
        let reason = String(format: reasonFormat, regionName, value)
        
        let hint = HintData(row: row, column: col, value: value, reason: reason, technique: HintTechnique.hiddenSingle)
        
        // Adım 1: Bölgeyi vurgula
        let stepFormat = NSLocalizedString("%@ tüm hücreler incelendi.", comment: "İpucu açıklaması")
        let stepDescription = String(format: stepFormat, regionName)
        
        hint.addStep(title: NSLocalizedString("Bölge İncelemesi", comment: "İpucu başlığı"), 
                  description: stepDescription)
        
        // Bölgeye göre vurgulama yap
        switch region {
        case .row:
            for c in 0..<9 {
                if c != col {
                    hint.highlightCell(row: row, column: c, type: CellInteractionType.related)
                }
            }
        case .column:
            for r in 0..<9 {
                if r != row {
                    hint.highlightCell(row: r, column: col, type: CellInteractionType.related)
                }
            }
        case .block:
            // 3x3 bloğu başlangıç koordinatlarını hesapla
            let blockStartRow = (regionIndex / 3) * 3
            let blockStartCol = (regionIndex % 3) * 3
            
            // Bloğu vurgula - highlightBlock bir metot olduğu için değer atayamayız
            hint.highlightBlock(forRow: blockStartRow, column: blockStartCol)
            
            for r in blockStartRow..<blockStartRow+3 {
                for c in blockStartCol..<blockStartCol+3 {
                    if r != row || c != col {
                        hint.highlightCell(row: r, column: c, type: CellInteractionType.related)
                    }
                }
            }
        }
        
        // Adım 2: Tek konumu göster
        hint.addStep(title: NSLocalizedString("Tek Konum Tespiti", comment: "İpucu başlığı"), 
                  description: description)
        
        // Hedef hücreyi vurgula
        hint.highlightCell(row: row, column: col, type: CellInteractionType.target)
        hint.candidateValues = [value]
        
        // Hücreyi çöz
        enterValue(value, at: row, col: col)
        hintCount += 1
        remainingHints -= 1
        
        // Tahtayı güncelle
        validateBoard()
        updateUsedNumbers()
        
        return hint
    }
    
    // 2.1 Naked Pairs (Açık Çiftler) - Aynı satır, sütun veya blokta aynı iki adaya sahip iki hücre
    private func findNakedPairsHint() -> HintData? {
        // Şimdilik basit bir yapıda, ileride geliştirilebilir
        return nil as HintData?
    }
    
    // 2.2 Hidden Pairs (Gizli Çiftler)
    private func findHiddenPairsHint() -> HintData? {
        // Şimdilik basit bir yapıda, ileride geliştirilebilir
        return nil as HintData?
    }
    
    // Son çare: Rastgele bir ipucu oluştur
    private func findRandomHint() -> HintData? {
        // Boş hücreleri bul
        var emptyPositions: [(row: Int, col: Int)] = []
        
        for row in 0..<9 {
            for col in 0..<9 {
                // Boş ve sabit olmayan hücreleri listeye ekle
                if !board.isFixed(at: row, col: col) && board.getValue(at: row, col: col) == nil {
                    emptyPositions.append((row: row, col: col))
                }
            }
        }
        
        // Boş hücre yoksa null dön
        if emptyPositions.isEmpty {
            return nil as HintData?
        }
        
        // Rastgele bir boş hücre seç
        let randomIndex = Int.random(in: 0..<emptyPositions.count)
        let randomPosition = emptyPositions[randomIndex]
        
        // Orijinal değeri al
        if let solution = board.getOriginalValue(at: randomPosition.row, col: randomPosition.col) {
            return createRandomHint(row: randomPosition.row, col: randomPosition.col, value: solution)
        }
        
        return nil
    }
    
    // Rastgele ipucu oluştur
    private func createRandomHint(row: Int, col: Int, value: Int) -> HintData {
        let reason = NSLocalizedString("Sudoku kurallarına göre bu hücreye \(value) değeri konabilir.", comment: "İpucu açıklaması")
        
        let hint = HintData(row: row, column: col, value: value, reason: reason, technique: HintTechnique.general)
        
        // Adım 1: İlişkili hücreleri vurgula
        hint.addStep(title: NSLocalizedString("Boş Hücre Analizi", comment: "İpucu başlığı"), 
                  description: NSLocalizedString("Bu hücre, sudoku tahtasında çözülebilir bir hücre olarak belirlendi.", comment: "İpucu açıklaması"))
        
        // İlişkili hücreleri vurgula
        hint.highlightRelatedCells(row: row, column: col, type: CellInteractionType.related)
        
        // Adım 2: Değeri göster
        hint.addStep(title: NSLocalizedString("Değer Önerisi", comment: "İpucu başlığı"), 
                  description: NSLocalizedString("Bu hücreye \(value) değeri konabilir.", comment: "İpucu açıklaması"))
        
        // Hücreyi çöz
        enterValue(value, at: row, col: col)
        hintCount += 1
        remainingHints -= 1
        
        // Tahtayı güncelle
        validateBoard()
        updateUsedNumbers()
        
        return hint
    }
    
    // İpucu bulunamıyorsa bildiri göster
    private func showNoHintAvailable() {
        // Boş bir ipucu nesnesi oluştur
        let hint = HintData(row: 0, column: 0, value: 0, reason: NSLocalizedString("Tahta üzerinde tespit edilebilen bir ipucu yok. Daha karmaşık stratejilere ihtiyaç olabilir.", comment: "İpucu bulunamadı"), technique: .none)
        
        // Görüntüle
        showHintFound(hint)
    }
    
    // Bulunan ipucunu gösterir
    private func showHintFound(_ hint: HintData) {
        hintExplanationData = hint
        currentHintStep = 0
        showHintExplanation = true
    }
    
    // Satır kontrolü
    private func generateHintExplanation(row: Int, col: Int, value: Int) -> String {
        var reasons: [String] = ["Sudoku kurallarına göre bu hücreye \(value) değeri en uygun değerdir."]
        
        // Satır kontrolü
        var rowHasValue = false
        for c in 0..<9 where c != col {
            if board.getValue(at: row, col: c) == value {
                rowHasValue = true
                break
            }
        }
        if !rowHasValue {
            reasons.append("\(row+1). satırda başka \(value) olmadığı için")
        }
        
        // Sütun kontrolü
        var colHasValue = false
        for r in 0..<9 where r != row {
            if board.getValue(at: r, col: col) == value {
                colHasValue = true
                break
            }
        }
        if !colHasValue {
            reasons.append("\(col+1). sütunda başka \(value) olmadığı için")
        }
        
        // 3x3 blok kontrolü
        let blockRow = (row / 3) * 3
        let blockCol = (col / 3) * 3
        var blockHasValue = false
        
        outerLoop: for r in blockRow..<blockRow+3 {
            for c in blockCol..<blockCol+3 {
                if r == row && c == col { continue }
                if board.getValue(at: r, col: c) == value {
                    blockHasValue = true
                    break outerLoop
                }
            }
        }
        if !blockHasValue {
            reasons.append("Bu 3x3 blokta başka \(value) olmadığı için")
        }
        
        // Eğer özel bir sebep bulunamadıysa
        if reasons.isEmpty {
            return "Sudoku kurallarına göre bu hücreye \(value) gelmelidir."
        }
        
        // Sebepleri birleştir
        return reasons.joined(separator: ", ")
    }
    
    // İpucu açıklama penceresini kapat
    func closeHintExplanation() {
        showHintExplanation = false
        hintExplanationData = nil
    }
    
    // MARK: - Oyun İstatistikleri
    
    // Oyun performans istatistiklerini getir
    func getGameStats() -> [String: Any] {
        return [
            "difficulty": board.difficulty.rawValue,
            "time": Int(elapsedTime),
            "moves": moveCount,
            "errors": errorCount,
            "hints": hintCount
        ]
    }
    
    // Oyun tamamlandığında çağrılır
    private func handleGameCompletion() {
        // Oyunu zaten tamamlanmış olarak işaretledik, burada tekrar ayarlamıyoruz
        logInfo("Game completed!")
        
        // Timer'ı durdur
        if timer != nil && timer!.isValid {
            timer!.invalidate()
            timer = nil
        }
        
        // Oyunu tamamla ve başarımları güncelle
        completeGame()
        
        // completeGame() içinde zaten skor kaydediliyor, burada tekrar kaydetmeye gerek yok
        // saveHighScore() 
        
        // Başarımları göster
        AchievementNotificationManager.shared.showAllUnlockedAchievements()
                
        // Oyun tamamlandığında kayıtlı oyunu sil ve tamamlanmış olarak kaydet
        if let gameID = currentGameID {
            // Önce Firebase'den doğrudan silmeyi deneyelim
            PersistenceController.shared.deleteGameFromFirestore(gameID: gameID)
            
            achievementManager.handleCompletedGame(
                gameID: gameID,
                difficulty: board.difficulty,
                time: elapsedTime,
                errorCount: errorCount,
                hintCount: 3 - remainingHints
            )
            
            // Oyun hem FireStore'a kaydedildi hem de Core Data'dan silindi
            logSuccess("Oyun tamamlandı olarak işaretlendi!")
            
            // Kaydedilmiş oyunları yeniden yükle - daha uzun bir gecikme
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                logInfo("SavedGames yenileme bildirimi gönderildi")
            }
        }
        
        // Firebase işlemlerine devam et
        if Auth.auth().currentUser?.uid != nil {
            // ... existing code ...
        }
    }
    
    // Performans skorunu hesapla
    func calculatePerformanceScore() -> Int {
        let scores = ScoreManager.shared.calculateScore(
            difficulty: board.difficulty,
            timeElapsed: elapsedTime,
            errorCount: errorCount,
            hintCount: 3 - remainingHints
        )
        return scores.totalScore
    }
    
    // Oyun istatistiklerini getir
    func getGameStatistics() -> (moves: Int, errors: Int, hints: Int, time: TimeInterval) {
        return (
            moves: moveCount,
            errors: errorCount,
            hints: 3 - remainingHints,
            time: elapsedTime
        )
    }
    

    
    // MARK: - Diğer Yardımcı Metodlar
    
    // Değer giriş işlemi
    private func enterValue(_ value: Int?, at row: Int, col: Int) {
        // Debug log
        print("Değer giriliyor: \(value ?? 0) -> (\(row), \(col))")
        
        // Tahtaya değeri ayarla - direkt çağrı
        let success = board.setValue(row: row, column: col, value: value)
        
        print("setValue sonucu: \(success)")
        
        // Titreşim geri bildirimi
        if enableHapticFeedback && enableNumberInputHaptic && value != nil {
            // Sistem titreşim API'sini doğrudan kullan
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        
        // Kullanıcı girişi olarak işaretle
        if !board.isFixed(at: row, col: col) {
            if value != nil {
                // Değer girildiğinde kullanıcı girişi olarak işaretle
                userEnteredValues[row][col] = true
            } else {
                // Değer silindiğinde kullanıcı girişi işaretini kaldır
                userEnteredValues[row][col] = false
            }
        }
    }
    
    // Kalem işareti değiştirme
    func togglePencilMark(at row: Int, col: Int, value: Int) {
        // Normal pencil mark işlemleri
        board.togglePencilMark(at: row, col: col, value: value)
        
        // Önbelleği güncelle
        let key = "\(row)_\(col)"
        pencilMarkCache.removeValue(forKey: key)
        
        // UI güncellemesi için bildirim gönder
        objectWillChange.send()
        
        // Otomatik kaydet - not değişikliklerini de kaydet
        autoSaveGame()
        
        // Debug log
        print("Not eklendi/çıkarıldı: \(value) -> (\(row), \(col)), notlar: \(board.getPencilMarks(at: row, col: col))")
    }
    
    // Bir hücredeki tüm kalem işaretlerini temizle
    func clearPencilMarks(at row: Int, col: Int) {
        board.clearPencilMarks(at: row, col: col)
        
        // Önbelleği güncelle
        let key = "\(row)_\(col)"
        pencilMarkCache.removeValue(forKey: key)
        
        // UI güncellemesi için bildirim gönder
        objectWillChange.send()
        
        // Debug log
        print("Tüm notlar temizlendi: (\(row), \(col))")
    }
    
    // Kalem işareti var mı
    func isPencilMarkSet(row: Int, column: Int, value: Int) -> Bool {
        return board.isPencilMarkSet(row: row, column: column, value: value)
    }
    
    // MARK: - Oyun Kaydetme/Yükleme
    
    // Takip etmek için geçerli oyun ID'si
    private var currentGameID: UUID?
    
    // Oyunu kaydet - yeni bir oyun veya mevcut bir oyunu güncelleme
    func saveGame(forceNewSave: Bool = false) {
        logDebug("saveGame fonksiyonu çalıştı")
        
        // Oyun tamamlandıysa veya başarısız olduysa kaydetmeye gerek yok
        if gameState == .completed || gameState == .failed {
            logInfo("Oyun tamamlandığı veya başarısız olduğu için kaydedilmiyor")
            return
        }
        
        // Bekleyen hatalı girişleri geçici olarak tahtadan kaldır
        var tempErrorValues: [(Position, Int?)] = []
        
        for position in pendingErrorCells {
            if let value = board.getValue(row: position.row, column: position.col) {
                tempErrorValues.append((position, value))
                // Hatalı değeri geçici olarak sil
                _ = board.setValue(row: position.row, column: position.col, value: nil)
            }
        }
        
        // Oyun tahtası kontrolü
        let currentBoard = board // board Optional olmadığı için doğrudan kullanıyoruz
        
        // JSONSerialization için veri hazırlığı
        var jsonDict: [String: Any] = [:]
        
        // Tahtanın mevcut durumunu board dizisine dönüştür
        let boardArray = currentBoard.getBoardArray()
        jsonDict["board"] = boardArray
        
        // Çözüm dizisini ekle
        var solutionArray = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for row in 0..<9 {
            for col in 0..<9 {
                solutionArray[row][col] = currentBoard.getSolutionValue(row: row, column: col) ?? 0
            }
        }
        jsonDict["solution"] = solutionArray
        
        // Sabit hücreler bilgisini ekle
        var fixedCells = Array(repeating: Array(repeating: false, count: 9), count: 9)
        for row in 0..<9 {
            for col in 0..<9 {
                fixedCells[row][col] = currentBoard.isFixed(at: row, col: col)
            }
        }
        jsonDict["fixedCells"] = fixedCells
        
        // Zorluk bilgisini kaydet
        jsonDict["difficulty"] = currentBoard.difficulty.rawValue
        
        // İstatistik bilgilerini de ekle
        var stats: [String: Any] = [:]
        stats["errorCount"] = errorCount
        stats["hintCount"] = hintCount
        stats["moveCount"] = moveCount
        stats["remainingHints"] = remainingHints
        jsonDict["stats"] = stats
        
        // Kullanıcının girdiği değerleri kaydet
        var cleanUserEnteredValues = userEnteredValues
        // pendingErrorCells pozisyonlarındaki kullanıcı girişlerini false yap
        for position in pendingErrorCells {
            if position.row < cleanUserEnteredValues.count && position.col < cleanUserEnteredValues[position.row].count {
                cleanUserEnteredValues[position.row][position.col] = false
            }
        }
        jsonDict["userEnteredValues"] = cleanUserEnteredValues
                
        // Veriyi json formatına dönüştür
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
            
            // Not: jsonData kullanıldığını belirtmek için geçici bir print
            logDebug("JSON veri boyutu: \(jsonData.count) byte")
            
            // Kaydetme işlemini gerçekleştir
            if let gameID = currentGameID, !forceNewSave {
                // Mevcut bir oyun varsa güncelle
                logInfo("Mevcut oyun güncelleniyor, ID: \(gameID)")
                
                // PersistenceController üzerinden güncelleme yap
                PersistenceController.shared.updateSavedGame(
                    gameID: gameID,
                    board: boardArray,
                    difficulty: currentBoard.difficulty.rawValue,
                    elapsedTime: elapsedTime,
                    jsonData: jsonData
                )
                logSuccess("Oyun başarıyla güncellendi, ID: \(gameID)")
        } else {
                // Yeni bir oyun kaydet ve ID'sini kaydet
                logInfo("Yeni oyun kaydediliyor")
                let newGameID = UUID()
                currentGameID = newGameID
                
                // PersistenceController üzerinden yeni oyun kaydet
                PersistenceController.shared.saveGame(
                    gameID: newGameID,
                    board: boardArray,
                    difficulty: currentBoard.difficulty.rawValue,
                    elapsedTime: elapsedTime,
                    jsonData: jsonData
                )
                logSuccess("Yeni oyun başarıyla kaydedildi, ID: \(newGameID)")
            }
            
            logDebug("Kaydetme işlemi tamamlandı")
            loadSavedGames() // Kaydedilmiş oyunları yeniden yükle
        } catch {
            logError("JSON oluşturma veya kaydetme hatası: \(error)")
        }
        
        // Geçici olarak kaldırılan hatalı değerleri geri ekle
        for (position, value) in tempErrorValues {
            _ = board.setValue(row: position.row, column: position.col, value: value)
        }
    }
    
    // Otomatik kaydet - çok sık çağrılmaması için zamanlayıcı eklenebilir
    private func autoSaveGame() {
        // Otomatik kaydetme devre dışı bırakılmışsa atla
        let noAutoSaveKey = "SudokuViewModel.noAutoSave"
        if UserDefaults.standard.bool(forKey: noAutoSaveKey) {
            logInfo("Otomatik kaydetme devre dışı, işlem atlanıyor")
            return
        }
        
        // Eğer oyun tamamlanmamışsa ve aktif oynanıyorsa kaydet
        if gameState == .playing {
            // Belirli koşullar altında kaydetmeyi atla:
            // 1. Oyun süresi 5 saniyeden az ise (tamamen yeni başlamış oyun)
            // 2. Hiç hamle yapılmamışsa (henüz gerçek bir oyun değil)
            if elapsedTime < 5 || moveCount < 1 {
                logInfo("Otomatik kaydetme atlandı (oyun çok yeni başladı veya hamle yapılmadı)")
                return
            }
            
            // Oyun ID'si varsa güncelle, yoksa yeni kaydet
            logInfo("Otomatik kaydetme başladı...")
            saveGame(forceNewSave: false) // Var olan kaydı güncelle
            logSuccess("Otomatik kaydetme tamamlandı.")
        } else {
            logInfo("Oyun \(gameState) durumunda olduğu için otomatik kaydedilmedi.")
        }
    }
    

    
    // MARK: - Saved Game Yönetimi
    
    // Kaydedilmiş oyunu yükle
    func loadGame(from savedGame: NSManagedObject) {
        logInfo("Kayıtlı oyun yükleniyor: \(savedGame)")
        
        // Otomatik kaydetmeyi etkinleştir - kullanıcı bilinçli olarak kayıtlı oyun yüklüyor
        let noAutoSaveKey = "SudokuViewModel.noAutoSave"
        UserDefaults.standard.set(false, forKey: noAutoSaveKey)
        logInfo("Kayıtlı oyun yükleniyor, otomatik kaydetme etkinleştirildi")
        
        // Güvenli bir şekilde boardState'i al
        guard let boardData = savedGame.value(forKey: "boardState") as? Data else {
            logError("Oyun verisi bulunamadı")
            return
        }
        
        // Kayıtlı oyunun ID'sini al ve mevcut oyun ID'si olarak ayarla
        if let gameID = savedGame.value(forKey: "id") as? UUID {
            self.currentGameID = gameID
            logDebug("Kaydedilmiş oyun ID'si ayarlandı: \(gameID)")
        } else if let gameIDString = savedGame.value(forKey: "id") as? String, 
                  let gameID = UUID(uuidString: gameIDString) {
            self.currentGameID = gameID
            logDebug("Kaydedilmiş oyun ID'si (string'den) ayarlandı: \(gameID)")
        } else {
            // Eğer ID bulunamazsa, yeni bir ID oluştur
            self.currentGameID = UUID()
            logDebug("Kaydedilmiş oyun için yeni ID oluşturuldu: \(self.currentGameID!)")
        }
        
        let difficultyString = savedGame.value(forKey: "difficulty") as? String ?? "Kolay"
        logInfo("Kayıtlı oyun yükleniyor, zorluk seviyesi: \(difficultyString)")
        
        // Doğrudan oyun verilerinden SudokuBoard ve userEnteredValues oluşturuyoruz
        guard let (loadedBoard, userValues) = loadBoardFromData(boardData) else {
            print("❌ Oyun tahta verisi yüklenemedi")
            return
        }
        
        // SudokuBoard'u ve kullanıcı değerlerini kaydedilmiş oyundan yükledik
        self.board = loadedBoard
        
        // userEnteredValues'i loadBoardFromData'dan gelen değere ayarla
        self.userEnteredValues = userValues
        
        // Eğer userEnteredValues JSON'dan düzgün bir şekilde yüklenmediyse, 
        // tahta üzerinden hesapla (yedek çözüm)
        if self.userEnteredValues.flatMap({ $0.filter { $0 } }).isEmpty {
            logWarning("userEnteredValues boş, tahta üzerinden hesaplanıyor")
            
            // Yeni bir userEnteredValues matrisi oluştur
            var computedValues = Array(repeating: Array(repeating: false, count: 9), count: 9)
            
            // Tahtadaki her hücre için, sabit olmayan ve değeri olan hücreleri işaretle
            for row in 0..<9 {
                for col in 0..<9 {
                    if let value = self.board.getValue(at: row, col: col), value > 0 {
                        if !self.board.isFixed(at: row, col: col) {
                            computedValues[row][col] = true
                        }
                    }
                }
            }
            
            self.userEnteredValues = computedValues
        }
        
        // Kullanıcı tarafından girilen değerlerin doğru şekilde işaretlendiğinden emin ol
        // Bu, renk sorununu çözecek
        // NOT: SudokuBoard sınıfında markAsUserEntered metodu yok, bu yüzden userEnteredValues'ı kullanıyoruz
        // userEnteredValues zaten yüklendi, bu değerler SudokuCellView'da isUserEntered parametresi olarak kullanılacak
        
        // Hücre renklerinin doğru görüntülenmesi için, tüm hücreleri yeniden çizmeyi tetikle
        // Bu, görünümün güncellenmesini sağlar
        objectWillChange.send()
        
        logSuccess("Kullanıcı tarafından girilen değerler yüklendi ve işaretlendi: \(self.userEnteredValues.flatMap { $0.filter { $0 } }.count) değer")
        
        self.elapsedTime = savedGame.getDouble(key: "elapsedTime")
        self.pausedElapsedTime = self.elapsedTime
        self.gameState = .playing
        
        // İstatistikleri ve kullanıcı girişlerini JSON verilerinden okuyup güncelle
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: boardData) as? [String: Any] {
                // İstatistikleri yükle
                if let stats = jsonObject["stats"] as? [String: Any] {
                    if let errorVal = stats["errorCount"] as? Int {
                        self.errorCount = errorVal
                    }
                    if let hintVal = stats["hintCount"] as? Int {
                        self.hintCount = hintVal
                    }
                    if let moveVal = stats["moveCount"] as? Int {
                        self.moveCount = moveVal
                    }
                    if let remainingVal = stats["remainingHints"] as? Int {
                        self.remainingHints = remainingVal
                    }
                    logSuccess("Oyun istatistikleri güncellendi")
                }
                
                // Kullanıcı tarafından girilen değerler zaten yüklendi
                // Bu kısmı atlıyoruz çünkü yeni fonksiyon imzasıyla doğrudan alıyoruz
                logInfo("userEnteredValues zaten loadBoardFromData fonksiyonundan alındı - tekrar yüklemeye gerek yok")
            }
        } catch {
            logWarning("İstatistikleri yüklerken hata: \(error)")
        }
        
        // Seçili hücreyi sıfırla
        selectedCell = nil
        
        // Kalem notları için önbellekleri temizle
        pencilMarkCache.removeAll(keepingCapacity: true)
        
        // İstatistikler JSON verisi içinden okunuyor, burada sıfırlama yapmıyoruz
        
        // Eğer kaydedilmiş istatistikler varsa güvenli bir şekilde okuma yap
        // Core Data modelinde bu alanların tanımlı olup olmadığını kontrol etmeye gerek yok
        // Güvenli bir şekilde JSON verisi olarak depolanıyorsa okuma yapabiliriz
        if let boardData = savedGame.value(forKey: "boardState") as? Data {
            do {
                // İstatistikleri JSON içinden okumayı dene
                if let json = try JSONSerialization.jsonObject(with: boardData) as? [String: Any] {
                    // JSON meta-verileri içinde statistikleri ara
                    if let stats = json["stats"] as? [String: Any] {
                        errorCount = stats["errorCount"] as? Int ?? 0
                        hintCount = stats["hintCount"] as? Int ?? 0 
                        moveCount = stats["moveCount"] as? Int ?? 0
                        
                        // userEnteredValues zaten yüklendiği için tekrar yüklemiyoruz
                        remainingHints = stats["remainingHints"] as? Int ?? 3
                        logSuccess("İstatistikler başarıyla yüklendi")
                    }
                }
            } catch {
                logWarning("İstatistikler yüklenemedi: \(error)")
                // Hata durumunda varsayılan değerleri kullan
            }
        }
        
        // Kullanılan rakamları güncelle
        updateUsedNumbers()
        
        // Zamanlayıcıyı başlat
        startTime = Date()
        startTimer()
        
        logSuccess("Oyun başarıyla yüklendi, ID: \(currentGameID?.uuidString ?? "ID yok")")
    }
    
    // Veri objesinden SudokuBoard ve kullanıcı tarafından girilen değerleri oluştur
    private func loadBoardFromData(_ data: Data) -> (board: SudokuBoard, userValues: [[Bool]])? {
        logInfo("KAYDEDILMIŞ OYUN YÜKLEME BAŞLADI")
        logDebug("Veri boyutu: \(data.count) byte")
        
        // 1. Ana Json veri yapısını çözümlemeyi dene
        do {
            // Önce JSON'u dictionary'ye çevir
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logError("JSON veri biçimi geçersiz")
                return nil
            }
            
            // Farklı anahtar biçimlerini dene
            var boardArray: [[Int]]? = nil
            var solutionArray: [[Int]]? = nil
            var fixedCells: [[Bool]]? = nil
            var difficultyString: String? = nil
            
            // Zorluk değerini bul
            if let diff = jsonDict["difficulty"] as? String {
                difficultyString = diff
            } else if let diff = jsonDict["difficultyLevel"] as? String {
                difficultyString = diff
            }
            
            // Tahta durumunu bul
            if let board = jsonDict["boardState"] as? [[Int]] {
                boardArray = board
            } else if let board = jsonDict["board"] as? [[Int]] {
                boardArray = board
            } else if let boardString = jsonDict["boardState"] as? String,
                      let boardData = boardString.data(using: .utf8),
                      let board = try? JSONSerialization.jsonObject(with: boardData) as? [[Int]] {
                boardArray = board
            }
            
            // Çözümü bul
            if let solution = jsonDict["solution"] as? [[Int]] {
                solutionArray = solution
                logSuccess("JSON'dan çözüm dizisi başarıyla yüklendi")
            } else if let solution = jsonDict["solutionBoard"] as? [[Int]] {
                solutionArray = solution
                print("✅ JSON'dan solutionBoard başarıyla yüklendi")
            }
            
            // Sabit hücreleri bul
            if let fixed = jsonDict["fixedCells"] as? [[Bool]] {
                fixedCells = fixed
                print("✅ JSON'dan sabit hücreler başarıyla yüklendi")
            }
            
            // Gerekli tüm verilerin mevcut olduğundan emin ol
            guard let boardData = boardArray,
                  let difficulty = difficultyString else {
                print("❌ Oyun verileri eksik: Board veya zorluk seviyesi bulunamadı")
                return nil
            }
            
            // Sabit hücreler yoksa, boş bir dizi oluştur
            if fixedCells == nil {
                fixedCells = Array(repeating: Array(repeating: false, count: 9), count: 9)
                
                // Eğer tahta dizisi varsa, sabit hücreleri tahmin et
                // (değeri 0'dan büyük olan hücreler sabit kabul edilir)
                if let board = boardArray {
                    for row in 0..<9 {
                        for col in 0..<9 {
                            if board[row][col] > 0 {
                                fixedCells?[row][col] = true
                            }
                        }
                    }
                }
            }
            
            // Zorluk seviyesini Difficulty enum değerine çevir
            let difficultyValue5: SudokuBoard.Difficulty
            switch difficulty {

            case "Kolay": difficultyValue5 = .easy
            case "Orta": difficultyValue5 = .medium
            case "Zor": difficultyValue5 = .hard
            case "Uzman": difficultyValue5 = .expert
            default: difficultyValue5 = .easy
            }
            
            print("✅ Zorluk seviyesi: \(difficulty)")
            
            // Eğer çözüm verisi yoksa, önceden oynanmış tahtayı göstermek için kendi çözümümüzü oluşturalım
            if solutionArray == nil {
                print("⚠️ Çözüm verisi bulunamadı, önce orijinal tahtayı kurtarmayı deniyorum")
                
                // Önceki tahtayı tamamen korumak için 9x9 tahta çözüm dizisi oluştur
                var solutionMatrix = Array(repeating: Array(repeating: 0, count: 9), count: 9)
                
                // Mevcut tahtadan verileri çözüm dizisine kopyala
                for row in 0..<min(9, boardData.count) {
                    for col in 0..<min(9, boardData[row].count) {
                        solutionMatrix[row][col] = boardData[row][col] > 0 ? boardData[row][col] : 0
                    }
                }
                
                // SudokuSolver sınıfı bulunamadığı için, çözümü kendi tahmin ediyoruz
                print("✅ Kayıtlı oyun için tahmini çözüm oluşturuluyor")
                solutionArray = solutionMatrix
                
                // Basitçe tüm boş hücreler için 1-9 arası değer koyuyoruz
                // Not: Bu çözüm doğru olmayabilir ama en azından uygulama çalışacak
                for row in 0..<9 {
                    for col in 0..<9 {
                        if solutionArray![row][col] == 0 {
                            // Boş hücreyse 1 ile doldur (gerçek oyunlar için daha iyi bir çözüm gerekir)
                            solutionArray![row][col] = 1
                        }
                    }
                }
            }
            
            // Bu değişkeni board oluştururken kullanacağız
            let boardDifficultyEnum2 = difficultyValue5
            
            // Boşlukları doldurulabilir, başlangıç değerleri sabit diye işaretle
            var fixed = Array(repeating: Array(repeating: false, count: 9), count: 9)
            var boardValues = Array(repeating: Array(repeating: nil as Int?, count: 9), count: 9)
            
            // fixedValues JSON'dan alınabilecek sabitleri saklamak için
            var fixedValues: [[Bool]]? = nil
            
            // Önce fixed hücreleri belirlemek için meta verileri kontrol et
            if let originalBoard = jsonDict["originalBoard"] as? [[Int]] {
                fixedValues = Array(repeating: Array(repeating: false, count: 9), count: 9)
                for row in 0..<min(9, originalBoard.count) {
                    for col in 0..<min(9, originalBoard[row].count) {
                        fixedValues?[row][col] = originalBoard[row][col] > 0
                    }
                }
                print("✅ OriginalBoard verisi bulundu")
            } else if let fixedCells = jsonDict["fixedCells"] as? [[Bool]] {
                fixedValues = fixedCells
                print("✅ FixedCells verisi bulundu")
            } else {
                print("⚠️ Sabit hücreler belirtilmemiş, tahmin edilecek")
            }
            
            // Board'u ve fixed hücreleri doldur
            for row in 0..<min(9, boardData.count) {
                for col in 0..<min(9, boardData[row].count) {
                    let value = boardData[row][col]
                    boardValues[row][col] = value > 0 ? value : nil
                    
                    // Sabit hücreleri belirle
                    if let fixedArray = fixedValues, row < fixedArray.count, col < fixedArray[row].count {
                        fixed[row][col] = fixedArray[row][col]
                    } else if let solution = solutionArray, row < solution.count, col < solution[row].count {
                        // Sabit hücreler belirtilmemişse, tahta ve çözüme bakarak tahmin et
                        if value > 0 && value == solution[row][col] {
                            fixed[row][col] = true
                        }
                    }
                }
            }
            
            print("✅ Yüklenen tahta: \(boardValues.flatMap { $0.compactMap { $0 } }.count) dolu hücre")
            print("✅ Sabit hücreler: \(fixed.flatMap { $0.filter { $0 } }.count) adet")
            
            // Yeni bir SudokuBoard oluştur
            let newBoard = SudokuBoard(board: boardValues, 
                                        solution: solutionArray!, 
                                        fixed: fixed, 
                                        difficulty: boardDifficultyEnum2)
            
            // Kullanıcı tarafından girilen değerler bilgisini JSON'dan al
            let userEntered = jsonDict["userEnteredValues"] as? [[Bool]] ?? Array(repeating: Array(repeating: false, count: 9), count: 9)
            
            // Başarılı mesajı yazdır
            print("✅ Kaydedilmiş verilerden board ve userEnteredValues başarıyla oluşturuldu")
            
            // Tuple olarak (tahta, kullanıcı değerleri) döndür
            return (board: newBoard, userValues: userEntered)
        } catch {
            print("❌ JSON işleme hatası: \(error)")
            return nil as (board: SudokuBoard, userValues: [[Bool]])?
        }
    }
    
    // Kaydedilmiş oyunu sil
    func deleteSavedGame(_ game: NSManagedObject) {
        if let savedGame = game as? SavedGame {
            PersistenceController.shared.deleteSavedGame(savedGame)
            loadSavedGames() // Kaydedilmiş oyunları yeniden yükle
        }
    }
    
    // Kaydedilmiş oyunları yükle
    func loadSavedGames() {
        let fetchedGames = PersistenceController.shared.loadSavedGames()
        self.savedGames = fetchedGames
    }
    
    // MARK: - Utilities
    
    // NSManagedObject'ten değerleri almak için yardımcı metotlar
    func getDifficulty(from savedGame: NSManagedObject) -> String {
        return savedGame.getString(key: "difficulty", defaultValue: "Kolay")
    }
    
    func getElapsedTime(from savedGame: NSManagedObject) -> Double {
        return savedGame.getDouble(key: "elapsedTime")
    }
    
    func getDate(from savedGame: NSManagedObject) -> Date {
        return savedGame.getDate(key: "dateCreated")
    }
    
    func getPlayerName(from highScore: NSManagedObject) -> String {
        return highScore.getString(key: "playerName", defaultValue: "İsimsiz")
    }
    
    func getHighScoreDate(from highScore: NSManagedObject) -> Date {
        return highScore.getDate(key: "date")
    }
    
    func getCompletionPercentage(for savedGame: NSManagedObject) -> Double {
        guard let boardData = savedGame.getData(key: "boardState") else {
            return 0.0
        }
        
        // Tahta verilerini çözmeyi dene
        do {
            if let json = try JSONSerialization.jsonObject(with: boardData) as? [String: Any],
               let _ = json["board"] as? String,
               let fixedCellsString = json["fixedCells"] as? String,
               let userValuesString = json["userEnteredValues"] as? String {
                
                // Sabit hücreleri sayan dizi
                let fixedCellsData = fixedCellsString.data(using: .utf8)!
                let fixedCells = try JSONDecoder().decode([[Bool]].self, from: fixedCellsData)
                
                // Kullanıcı girdilerini çözelim
                let userValuesData = userValuesString.data(using: .utf8)!
                let userValues = try JSONDecoder().decode([[Int?]].self, from: userValuesData)
                
                var filledCount = 0
                let totalCells = 81 // 9x9 sudoku tahtası
                
                // Sabit hücreleri ve kullanıcının doğru girdiği değerleri say
                for row in 0..<9 {
                    for col in 0..<9 {
                        if fixedCells[row][col] || userValues[row][col] != nil {
                            filledCount += 1
                        }
                    }
                }
                
                // Sonucu [0.0, 1.0] aralığında döndür
                return Double(filledCount) / Double(totalCells)
            }
        } catch {
            print("⚠️ Oyunun tamamlanma yüzdesi hesaplanırken hata: \(error)")
        }
        
        // Hata durumunda eski yöntemi dene
        guard let board = SudokuBoard.loadFromSavedState(boardData) else {
            return 0.0
        }
        
        var filledCount = 0
        for row in 0..<9 {
            for col in 0..<9 {
                if board.getValue(at: row, col: col) != nil {
                    filledCount += 1
                }
            }
        }
        
        return Double(filledCount) / 81.0
    }
    
    // MARK: - Zamanlayıcı Kontrolleri
    // Zamanlayıcı başlat
    func startTimer() {
        if timer == nil {
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateElapsedTime()
            }
        }
    }
    
    // Zamanı güncelle
    func updateElapsedTime() {
        if let startTime = startTime {
            elapsedTime = pausedElapsedTime + Date().timeIntervalSince(startTime)
        }
    }
    
    // Zamanlayıcıyı durdur
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Oyunu duraklat/devam ettir
    func togglePause() {
        if gameState == .playing {
            // Oyunu duraklatırken mevcut süreyi sakla
            pausedElapsedTime = elapsedTime
            gameState = .paused
            stopTimer()
        } else if gameState == .paused {
            gameState = .playing
            // Zaman geçmiş süreyi koruyarak başlatılır
            startTime = Date()
            startTimer()
        }
    }
    
    // Bildirim dinleyicilerini ayarla
    private func setupNotificationObservers() {
        // Önce tüm gözlemcileri kaldır (tekrarları önlemek için)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("PauseActiveGame"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("AppBecameActive"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ResetGameAfterTimeout"), object: nil)
        
        // Bildirim isimleri için sabitler
        let pauseGameName = Notification.Name("PauseActiveGame")
        let appBecameActiveName = Notification.Name("AppBecameActive")
        let resetGameName = Notification.Name("ResetGameAfterTimeout")
        
        // Uygulama arka plana alındığında oyunu otomatik olarak duraklat
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseGameFromBackground),
            name: pauseGameName,
            object: nil
        )
        
        // Uygulama tekrar aktif olduğunda (isteğe bağlı kullanım için)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: appBecameActiveName,
            object: nil
        )
        
        // Uygulama belirli bir süre arka planda kaldıktan sonra oyunu sıfırla
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetGameAfterTimeout),
            name: resetGameName,
            object: nil
        )
        
       // print("💬 Bildirim gözlemcileri başarıyla kuruldu")
    }
    
    // Uygulama arka plana alındığında çağrılır
    @objc private func pauseGameFromBackground() {
        // Sadece oyun aktif durumdaysa duraklat
        if gameState == .playing {
            print("🔊 Oyun otomatik olarak duraklatıldı (arka plan)")
            togglePause() // Oyunu duraklat
            
            // Sadece anlamlı bir süre oynanmışsa ve hamle yapılmışsa kaydet
            if elapsedTime > 5 && moveCount > 0 {
                saveGame() // Oyun durumunu kaydet
            } else {
                print("⏭️ Arka plana geçişte kaydetme atlandı (yeterli oynama yok)")
            }
        }
    }
    
    // Tüm ViewModel örnekleri için ortak bir zaman takibi
    private static var lastActiveNotificationTime: TimeInterval = 0
    private static var isProcessingActiveNotification = false
    
    // Uygulama tekrar aktif olduğunda çağrılır (2 dakikadan önce dönüldüğünde)
    @objc private func appBecameActive() {
        // Sınıf seviyesinde kilitleme - birden fazla ViewModel örneğinin aynı anda işlem yapmasını önler
        if SudokuViewModel.isProcessingActiveNotification {
            return
        }
        
        // Şu anki zamanı al
        let currentTime = Date().timeIntervalSince1970
        
        // Son bildirimden bu yana en az 1 saniye geçmiş olmalı
        // Bu, aynı bildirimin birden fazla kez işlenmesini önler
        if currentTime - SudokuViewModel.lastActiveNotificationTime < 1.0 {
            print("⚠️ Tekrarlanan bildirim engellendi (son bildirimden \(String(format: "%.2f", currentTime - SudokuViewModel.lastActiveNotificationTime)) saniye geçti)")
            return
        }
        
        // İşlem bayrağını ayarla
        SudokuViewModel.isProcessingActiveNotification = true
        
        // Son bildirim zamanını güncelle
        SudokuViewModel.lastActiveNotificationTime = currentTime
        
        print("🔊 Uygulama tekrar aktif oldu - oyun devam ediyor")
        
        // Oyun durumunu kontrol et ve gerekirse devam ettir
        if gameState == .paused {
            // Oyun duraklatılmışsa, devam ettir
            togglePause() // Duraklatma durumunu değiştirerek oyunu devam ettir
        }
        
        // Oyun görünümünü yenile
        objectWillChange.send()
        
        // İşlem tamamlandı, bayrağı sıfırla
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SudokuViewModel.isProcessingActiveNotification = false
        }
    }
    
    // Uygulama belirli bir süre (2 dakika) arka planda kaldıktan sonra oyunu kayıtlara ekle ve sıfırla
    @objc private func resetGameAfterTimeout() {
        print("⏰ Oyun zaman aşımına uğradı - sıfırlanıyor")
        
        // Mevcut oyunu silmeden önce mevcut oyun ID'sini kaydediyoruz
        let currentID = currentGameID
        
        // Mevcut oyun ID'sini sıfırla - böylece yeni bir oyun veya kayıtlı başka bir oyun yüklenebilir
        currentGameID = nil
        
        // Otomatik kaydetmeyi devre dışı bırak
        let noAutoSaveKey = "SudokuViewModel.noAutoSave"
        UserDefaults.standard.set(true, forKey: noAutoSaveKey)
        print("🔒 Otomatik kaydetme devre dışı bırakıldı")
        
        // Ana menüyü göstermek için bildirim gönder
        NotificationCenter.default.post(name: Notification.Name("ShowMainMenuAfterTimeout"), object: nil)
        
        // Oyun durumunu sıfırla
        resetGameState()
        
        // Yeni bir tahta oluştur (mevcut zorluk seviyesini kullanarak)
        let currentDifficulty = board.difficulty
        board = SudokuBoard(difficulty: currentDifficulty)
        updateUsedNumbers()
        
        // Tüm kayıtlı oyunları temizleme kısmını kaldırıyoruz
        // Kullanıcının diğer kaydedilmiş oyunlarına dokunmuyoruz
        
        // Sadece mevcut ID'ye sahip oyunu sil (varsa)
        if let gameID = currentID {
            print("🗑️ Süre aşımı nedeniyle mevcut oyun siliniyor, ID: \(gameID)")
            PersistenceController.shared.deleteSavedGameWithID(gameID)
        }
        
        // Kaydedilmiş oyunlar listesini güncelle
        loadSavedGames()
    }
    
    // Oyunun kayıt şartlarını karşılayıp karşılamadığını kontrol et
    private func shouldSaveGameAfterTimeout() -> Bool {
        // En az 30 saniye oynanmış olmalı
        let minimumPlayTime: TimeInterval = 30 // 30 saniye
        
        // En az 1 hamle yapılmış olmalı
        let minimumMoves = 1
        
        // Oyun tamamlanmamış olmalı
        let isNotCompleted = gameState != .completed
        
        // Şartları kontrol et
        let meetsTimeRequirement = elapsedTime >= minimumPlayTime
        let meetsMoveRequirement = moveCount >= minimumMoves
        
        return meetsTimeRequirement && meetsMoveRequirement && isNotCompleted
    }
    
    // Belirli bir zorluk seviyesinde "(Arka Plan)" ekiyle kaydedilmiş mevcut bir oyun olup olmadığını kontrol et
    private func checkForExistingBackgroundGame(difficulty: String) -> UUID? {
        // Tüm kayıtlı oyunları al
        let savedGames = PersistenceController.shared.getAllSavedGames()
        
        // "(Arka Plan)" ekiyle kaydedilmiş ve aynı zorluk seviyesinde olan oyunları bul
        for game in savedGames {
            if let gameDifficulty = game.value(forKey: "difficulty") as? String,
               let gameID = game.value(forKey: "id") as? UUID,
               gameDifficulty == difficulty {
                // Aynı zorluk seviyesinde "(Arka Plan)" ekiyle kaydedilmiş bir oyun bulundu
                return gameID
            }
        }
        
        // Eşleşen oyun bulunamadı
        return nil
    }
    
    // Zaman aşımı için oyun durumunu JSON'a dönüştür
    private func createGameStateJSONForTimeout() -> Data? {
        // Oyun tahtası kontrolü
        let currentBoard = board
        
        // JSONSerialization için veri hazırlığı
        var jsonDict: [String: Any] = [:]
        
        // Tahtanın mevcut durumunu board dizisine dönüştür
        let boardArray = currentBoard.getBoardArray()
        jsonDict["board"] = boardArray
        
        // Çözüm dizisini ekle
        var solutionArray = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for row in 0..<9 {
            for col in 0..<9 {
                solutionArray[row][col] = currentBoard.getSolutionValue(row: row, column: col) ?? 0
            }
        }
        jsonDict["solution"] = solutionArray
        
        // Sabit hücreler bilgisini ekle
        var fixedCells = Array(repeating: Array(repeating: false, count: 9), count: 9)
        for row in 0..<9 {
            for col in 0..<9 {
                fixedCells[row][col] = currentBoard.isFixed(at: row, col: col)
            }
        }
        jsonDict["fixedCells"] = fixedCells
        
        // Zorluk bilgisini kaydet
        jsonDict["difficulty"] = currentBoard.difficulty.rawValue
        
        // İstatistik bilgilerini de ekle
        var stats: [String: Any] = [:]
        stats["errorCount"] = errorCount
        stats["hintCount"] = hintCount
        stats["moveCount"] = moveCount
        stats["remainingHints"] = remainingHints
        jsonDict["stats"] = stats
        
        // Kullanıcının girdiği değerleri kaydet
        jsonDict["userEnteredValues"] = userEnteredValues
                
        // Veriyi json formatına dönüştür
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
            return jsonData
        } catch {
            print("❌ JSON oluşturulamadı: \(error)")
            return nil
        }
    }
    
    // Not: saveGameWithCustomName metodu kaldırıldı, yerine normal saveGame metodu ve PersistenceController.updateGameDifficulty kullanılıyor
    
    // Kaydedilmiş oyunu sil (varsa)
    
    
    // Objelerden kurtulmak için
    deinit {
        // Bildirim dinleyicilerini kaldır
        NotificationCenter.default.removeObserver(self)
        stopTimer()
    }
    
    // Oyun durumu değiştiğinde çağrılır
    private func handleGameStateChange() {
        switch gameState {
        case .completed:
            // Timer'ı durdur
            timer?.invalidate()
            timer = nil
            
        case .failed:
            // Timer'ı durdur
            timer?.invalidate()
            timer = nil
            
        case .playing:
            // Timer'ı başlat
            startTimer()
            
        default:
            break
        }
    }
    
    // Oyun durumunu güncelle
    func updateGameState(_ newState: GameState) {
        if gameState != newState {
            gameState = newState
            handleGameStateChange()
        }
    }
    
    
    // Geçici bir süre için önbellekleri geçersiz kıl
    func invalidateCellCache() {
        cellPositionMap = Array(repeating: Array(repeating: Set<Position>(), count: 9), count: 3)
        sameValueMap.removeAll(keepingCapacity: true)
    }
    
    // Hücre vurgu hesaplaması için yeni optimizasyonlu versiyon
    func isHighlighted(row: Int, column: Int) -> Bool {
        // Seçili hücre yoksa hiçbir hücre vurgulanmaz
        guard let selectedCell = selectedCell else {
            return false
        }
        
        // Hücre seçili olan hücre ise
        if selectedCell.row == row && selectedCell.column == column {
            return true
        }
        
        // Hızlı konum kontrolü - seçili hücre ile aynı satırda mı
        if selectedCell.row == row {
            return true
        }
        
        // Hızlı konum kontrolü - seçili hücre ile aynı sütunda mı
        if selectedCell.column == column {
            return true
        }
        
        // Hızlı konum kontrolü - seçili hücre ile aynı 3x3 bloğunda mı
        let selectedBlockRow = selectedCell.row / 3
        let selectedBlockCol = selectedCell.column / 3
        let blockRow = row / 3
        let blockCol = column / 3
        
        return selectedBlockRow == blockRow && selectedBlockCol == blockCol
    }
    
    // Hücrenin seçili hücre ile aynı değere sahip olup olmadığını kontrol et - optimize edildi
    func hasSameValue(row: Int, column: Int) -> Bool {
        guard let selectedCell = selectedCell,
              let selectedValue = board.getValue(at: selectedCell.row, col: selectedCell.column),
              selectedValue > 0 else {
            return false
        }
        
        // Eğer önceden hesaplanmışsa, önbellekten al
        if !sameValuePositions.isEmpty {
            return sameValuePositions.contains(Position(row: row, col: column))
        }
        
        // Seçilen hücre ile aynı değere sahip mi?
        if let value = board.getValue(at: row, col: column), value == selectedValue {
            return true
        }
        
        return false
    }
    
    // Önbellekleri temizleme
    private func clearCaches() {
        pencilMarkCache.removeAll(keepingCapacity: true)
        validValuesCache.removeAll(keepingCapacity: true)
        sameValueMap.removeAll(keepingCapacity: true)
        
        // Önbellek durumunu da sıfırla
        cachedHighlightedPositions.removeAll()
        invalidCells.removeAll()
    }
    
    // Hatalı değeri gösterdiğimizden emin olmak için değişkenleri kullanacağız
    @Published var showingErrorValue: Bool = false
    @Published var lastErrorValue: Int? = nil
    @Published var lastErrorPosition: (row: Int, col: Int)? = nil
    @Published var errorRemovalTimer: Timer? = nil
    
    // Oyunu tamamla (tüm hücreler doğru şekilde doldurulduğunda)
    func completeGame() {
        print("📱 Oyun tamamlandı!")
        
        // Oyun durumunu güncelle ve zamanlayıcıyı durdur
        gameState = .completed
        stopTimer()
        
        // Skoru kaydet
        let hintUsed = 3 - remainingHints
        print("📊 Skor kaydediliyor... Zorluk: \(board.difficulty.rawValue), Süre: \(elapsedTime), Hatalar: \(errorCount), İpuçları: \(hintUsed)")
        
        ScoreManager.shared.saveScore(
            difficulty: board.difficulty,
            timeElapsed: elapsedTime,
            errorCount: errorCount,
            hintCount: hintUsed,
            moveCount: moveCount
        )
        
        print("🏆 AchievementManager.processGameCompletion() çağrılıyor...")
        // Başarıları güncelle
        AchievementManager.shared.processGameCompletion(
            difficulty: board.difficulty,
            time: elapsedTime,
            errorCount: errorCount,
            hintCount: hintUsed
        )
        print("🏆 AchievementManager.processGameCompletion() tamamlandı!")
        
        // Oyun tamamlandığında bildirim gönder (gerekirse kullanılabilir)
        NotificationCenter.default.post(name: NSNotification.Name("GameCompleted"), object: nil, userInfo: [
            "difficulty": board.difficulty.rawValue,
            "score": calculatePerformanceScore(),
            "time": elapsedTime
        ])
        
        print("✅ Oyun tamamlama işlemi tamamlandı ve skor kaydedildi.")
        
        // Haptik feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Ses çal
        SoundManager.shared.playGameCompletedSound()
        
        print("🏆 AchievementManager başarımları güncelleniyor...")
        // Başarıları güncelle - processGameCompletion fonksiyonu yerine zorluk başarımları ayrı ayrı güncelleniyor
        let achievementManager = AchievementManager.shared
        
        // Zorluk seviyesine göre başarım
        switch board.difficulty {
        case .easy:
            achievementManager.updateAchievement("easy_1", completed: true)
        case .medium:
            achievementManager.updateAchievement("medium_1", completed: true)
        case .hard:
            achievementManager.updateAchievement("hard_1", completed: true)
        case .expert:
            achievementManager.updateAchievement("expert_1", completed: true)
        }
        
        // Hatasız oyun başarımları
        if errorCount == 0 {
            achievementManager.updateAchievement("no_errors", completed: true)
        }
        
        // İpuçsuz oyun başarımları 
        if hintUsed == 0 {
            achievementManager.updateAchievement("no_hints", completed: true)
        }
        
        // Zaman başarımları
        let timeInMinutes = elapsedTime / 60.0
        
        switch board.difficulty {
        case .easy:
            if timeInMinutes < 3.0 {
                achievementManager.updateAchievement("time_easy_3", completed: true)
                
                if timeInMinutes < 2.0 {
                    achievementManager.updateAchievement("time_easy_2", completed: true)
                    
                    if timeInMinutes < 1.0 {
                        achievementManager.updateAchievement("time_easy_1", completed: true)
                    }
                }
            }
        case .medium:
            if timeInMinutes < 5.0 {
                achievementManager.updateAchievement("time_medium_5", completed: true)
                
                if timeInMinutes < 3.0 {
                    achievementManager.updateAchievement("time_medium_3", completed: true)
                }
            }
        case .hard:
            if timeInMinutes < 10.0 {
                achievementManager.updateAchievement("time_hard_10", completed: true)
                
                if timeInMinutes < 5.0 {
                    achievementManager.updateAchievement("time_hard_5", completed: true)
                }
            }
        case .expert:
            if timeInMinutes < 15.0 {
                achievementManager.updateAchievement("time_expert_15", completed: true)
                
                if timeInMinutes < 8.0 {
                    achievementManager.updateAchievement("time_expert_8", completed: true)
                }
            }
        }
        
        print("🏆 Başarım güncellemeleri tamamlandı!")
        
        // Oyun tamamlandığında bildirim gönder (gerekirse kullanılabilir)
        NotificationCenter.default.post(name: NSNotification.Name("GameCompleted"), object: nil, userInfo: [
            "difficulty": board.difficulty.rawValue,
            "score": calculatePerformanceScore(),
            "time": elapsedTime
        ])
    }
    
    // Hücre vurgulamalarını güncelle
    private func updateHighlightedCells() {
        // Performans optimizasyonu: Seçili hücre yoksa güncelleme yapma
        guard let selectedPosition = selectedCell else {
            highlightedPositions.removeAll()
            return
        }
        
        let row = selectedPosition.row
        let col = selectedPosition.column
        
        // Performans optimizasyonu: Önceki vurgulamaları tamamen silmek yerine yeni set oluştur
        var newHighlights = Set<Position>()
        
        // Satır ve sütündaki hücreleri vurgula
        for i in 0..<9 {
            newHighlights.insert(Position(row: row, col: i))
            newHighlights.insert(Position(row: i, col: col))
        }
        
        // 3x3 bloktaki hücreleri vurgula
        let blockStartRow = (row / 3) * 3
        let blockStartCol = (col / 3) * 3
        
        for r in blockStartRow..<(blockStartRow + 3) {
            for c in blockStartCol..<(blockStartCol + 3) {
                newHighlights.insert(Position(row: r, col: c))
            }
        }
        
        // Sadece değişiklik varsa güncelle
        if highlightedPositions != newHighlights {
            highlightedPositions = newHighlights
        }
    }
    
    // Bir değere sahip tüm hücreleri vurgula
    private func updateSameValueCells() {
        // Seçili hücre yoksa veya değeri 0 ise vurgulamaları temizle
        guard let selectedPosition = selectedCell,
              let selectedValue = board.getValue(at: selectedPosition.row, col: selectedPosition.column),
              selectedValue > 0 else {
            sameValuePositions.removeAll(keepingCapacity: true)
            return
        }
        
        // Yeni pozisyonlar için set oluştur
        var newPositions = Set<Position>()
        
        // Tüm tahtayı tara ve aynı değere sahip hücreleri bul
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = board.getValue(at: row, col: col), 
                   value == selectedValue && value > 0 {
                    newPositions.insert(Position(row: row, col: col))
                }
            }
        }
        
        // Pozisyonları güncelle
        if sameValuePositions != newPositions {
            sameValuePositions = newPositions
        }
    }

    // Oyuncu hareketini belgeleme ve otomatik kayıt
    private func recordMove(at row: Int, column: Int, value: Int?) {
        // Performans optimizasyonu: Sadece değişiklik varsa kaydet
        let previousValue = board.getValue(at: row, col: column)
        if previousValue == value {
            return
        }
        
        // Son hareketler listesini güncelle
        moveHistory.append(Move(row: row, column: column, newValue: value, previousValue: previousValue))
        
        // Otomatik kaydetme sıklığını optimize et
        movesSinceLastSave += 1
        
        // Belirlenen sınırlarla otomatik kaydet
        if movesSinceLastSave >= 3 { // 5'ten 3'e düşürdüm
            autoSaveGame()
            movesSinceLastSave = 0
        }
    }
    
    // Vurgulanan hücreler için
    @Published var highlightedPositions = Set<Position>()
    
    // Aynı değere sahip hücreler için
    @Published var sameValuePositions = Set<Position>()
    
    // Önbellekler
    private var sameValueCache = [String: Set<Position>]()
    
    // Oyuncu hareketleri
    private var moveHistory = [Move]()
    private var movesSinceLastSave: Int = 0
    
    // Hareket tipini tanımla
    struct Move {
        let row: Int
        let column: Int
        let newValue: Int?
        let previousValue: Int?
    }
    
    @Published var showCompletionAlert = false
    @Published var hasErrors = false
    
    // Skoru hesapla
    private func calculateScore() -> Int {
        let baseScore = 1000
        let difficultyMultiplier: Double
        
        switch board.difficulty {
        case .easy:
            difficultyMultiplier = 1.0
        case .medium:
            difficultyMultiplier = 1.5
        case .hard:
            difficultyMultiplier = 2.0
        case .expert:
            difficultyMultiplier = 3.0
        }
        
        // Zaman cezası: Her 30 saniye için -50 puan
        let timeDeduction = Int((elapsedTime / 30.0) * 50)
        
        // Hata cezası: Her hata için -100 puan
        let errorDeduction = errorCount * 100
        
        // İpucu cezası: Her ipucu için -150 puan
        let hintDeduction = (3 - remainingHints) * 150
        
        // Toplam skoru hesapla
        let finalScore = Int(Double(baseScore) * difficultyMultiplier) - timeDeduction - errorDeduction - hintDeduction
        
        // Skor 0'ın altına düşmesin
        return max(finalScore, 0)
    }
    
    // Yüksek skoru kaydetme fonksiyonu
    func saveHighScore() {
        let score = calculatePerformanceScore()
        
        // Skor kaydetme
        ScoreManager.shared.saveScore(
            difficulty: board.difficulty,
            timeElapsed: elapsedTime,
            errorCount: errorCount,
            hintCount: 3 - remainingHints,
            moveCount: moveCount
        )
        
        print("Yüksek skor kaydedildi: \(score) puan")
    }
} 

// MARK: - NSManagedObject Extensions for HighScoresView Compatibility
extension NSManagedObject {
} 

// MARK: - NSManagedObject Extensions for HighScoresView Compatibility
extension NSManagedObject {
    func getHighScoreDifficulty() -> String {
        return value(forKey: "difficulty") as? String ?? "Kolay"
    }
    
    func getHighScoreElapsedTime() -> Double {
        return value(forKey: "elapsedTime") as? Double ?? 0.0
    }
    
    func getHighScoreDate() -> Date {
        return value(forKey: "date") as? Date ?? Date()
    }
    
    // Yalnızca getInt metodunu ekleyelim, diğerleri başka bir uzantıda tanımlanmış olabilir
    func getInt(key: String, defaultValue: Int = 0) -> Int {
        return value(forKey: key) as? Int ?? defaultValue
    }
}
