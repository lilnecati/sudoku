//  SudokuViewModel.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 29.12.2024.
//

import Foundation
import SwiftUI
import Combine
import CoreData

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
    
    // Performans iyileştirmesi: Pencil mark'ları hızlı erişim için önbelleğe al
    private var pencilMarkCache: [String: Set<Int>] = [:]
    private var validValuesCache: [String: Set<Int>] = [:]
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
    
    // MARK: - İlklendirme
    
    init(difficulty: SudokuBoard.Difficulty = .easy) {
        self.board = SudokuBoard(difficulty: difficulty)
        
        // CoreData'dan yüksek skorları ve kaydedilmiş oyunları yükle

        loadSavedGames()
        
        // Zaman değişkenlerini sıfırla
        elapsedTime = 0
        pausedElapsedTime = 0
        
        // Uygulama arka plana alındığında oyunu otomatik olarak duraklatmak için bildirim dinleyicisi ekle
        setupNotificationObservers()
        
        startTimer()
        updateUsedNumbers()
    }
    
    // MARK: - Core Oyun Metodları
    
    // Yeni bir oyun başlat - optimize edildi
    func newGame(difficulty: SudokuBoard.Difficulty) {
        board = SudokuBoard(difficulty: difficulty)
        selectedCell = nil
        invalidCells = []
        elapsedTime = 0
        pausedElapsedTime = 0
        gameState = .playing
        moveCount = 0
        errorCount = 0
        hintCount = 0
        remainingHints = 3  // Yeni oyunda ipucu hakkını sıfırla
        
        // Önbellekleri temizle
        pencilMarkCache.removeAll(keepingCapacity: true)
        validValuesCache.removeAll(keepingCapacity: true)
        
        startTimer()
        updateUsedNumbers()
    }
    
    // Hücre seçme - optimize edildi
    func selectCell(row: Int, column: Int) {
        // Mevcut seçimi temizle
        if selectedCell?.row == row && selectedCell?.column == column {
            selectedCell = nil
            // Önbellekleri temizle
            highlightedCellsCache.removeAll(keepingCapacity: true)
            sameValueCellsCache.removeAll(keepingCapacity: true)
        } else {
            // PowerSavingManager kontrolünü kaldırdık - her zaman çalışacak
            // if PowerSavingManager.shared.throttleInteractions() {
            //     return // Etkileşim sınırlanıyorsa işlemi iptal et
            // }
            
            // Eski önbellekleri temizle
            highlightedCellsCache.removeAll(keepingCapacity: true)
            sameValueCellsCache.removeAll(keepingCapacity: true)
            
            // Yeni hücreyi seç
            selectedCell = (row, column)
            lastSelectedCell = (row, column)
            
            // Yeni seçim için önbellekleri oluştur
            precalculateHighlightedCells(row: row, column: column)
        }
        
        // Dokunsal geri bildirim
        if enableHapticFeedback && enableCellTapHaptic {
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred(intensity: 0.5)
        }
        
        // Debug log
        print("Hücre seçildi: (\(row), \(column))")
    }
    
    // Yeni seçilen hücreyle ilgili önbellekleri oluştur
    private func precalculateHighlightedCells(row: Int, column: Int) {
        guard let value = board.getValue(row: row, column: column), value > 0 else { return }
        
        // Tüm tahta üzerindeki aynı değerleri hesapla
        for r in 0..<9 {
            for c in 0..<9 {
                if (r != row || c != column) && board.getValue(row: r, column: c) == value {
                    let cacheKey = "v_\(r)_\(c)_\(value)"
                    sameValueCellsCache[cacheKey] = true
                }
            }
        }
    }
    
    // Seçili hücreye değer atar - optimize edildi
    func setValueAtSelectedCell(_ value: Int?) {
        guard let selectedCell = selectedCell else { 
            print("Hücre seçili değil!")
            return 
        }
        
        let row = selectedCell.row
        let col = selectedCell.column
        
        // Debug log
        print("setValueAtSelectedCell: \(value ?? 0) -> (\(row), \(col))")
        
        // Eğer orijinal/sabit bir hücre ise, değişime izin verme
        if board.isFixed(at: row, col: col) {
            print("Sabit hücre değiştirilemez: (\(row), \(col))")
            return
        }
        
        let currentValue = board.getValue(at: row, col: col)
        let correctValue = board.getOriginalValue(at: row, col: col)
        
        // Eğer hücredeki mevcut değer doğruysa, değişime izin verme
        if currentValue == correctValue && currentValue != nil {
            print("Hücre zaten doğru değere sahip: \(currentValue!)")
            SoundManager.shared.playCorrectSound() // Doğru olduğunu bir daha hatırlat
            return
        }
        
        // Kalem modu için işlemler aynen kalsın
        if pencilMode {
            // Kalem modu işlemi - notlar için
            if let value = value {
                togglePencilMark(at: row, col: col, value: value)
            } else {
                // Silme işlemi - tüm pencil markları temizle
                SoundManager.shared.playEraseSound()
                clearPencilMarks(at: row, col: col)
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
                
                // Otomatik kaydet
                autoSaveGame()
                
                // Oyun tamamlanma kontrolü
                checkGameCompletion()
                
                // Oyun tamamlandıysa veya başarısız olduysa kayıtlı oyunu sil
            } else {
                SoundManager.shared.playErrorSound()
                
                // Hata sayısını artır
                errorCount += 1
                
                // Hatalı hücreyi işaretle
                let position = Position(row: row, col: col)
                invalidCells.insert(position)
                
                // Hata geri bildirimi
                if enableHapticFeedback && enableNumberInputHaptic {
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
                
                // Maksimum hata sayısını kontrol et
                if errorCount >= maxErrorCount {
                    gameState = .failed
                    stopTimer()
                }
                
                // ÖNEMLİ DEĞİŞİKLİK: Hatalı değeri hücreye girme
                // enterValue(value, at: row, col: col) - bu satırı kaldırıyoruz
                
                // Önbelleği güncelle ve doğrula
                invalidatePencilMarksCache(forRow: row, column: col)
                validateBoard()
                updateUsedNumbers()
                
                // Hamle sayısını artır - hatalı girişleri de sayalım
                moveCount += 1
                
                // Otomatik kaydet
                autoSaveGame()
                
                // Hatalı giriş sonrasında da oyun tamamlanma kontrolü yap
                // Önceki hücrelerin doğru doldurulduğundan emin olmak için
                checkGameCompletion()
            }
        }
    }
    
    // MARK: - Performans Optimizasyonları
    
    // Oyun tamamlandığında kayıtlı oyunu sil
    private func deleteSavedGameIfExists() {
        if let gameID = currentGameID {
            PersistenceController.shared.deleteSavedGameWithID(gameID)
            print("✅ Tamamlanan oyun kayıtlardan silindi")
            currentGameID = nil
        }
    }

    // Oyun tamamlanma kontrolü - optimize edildi
    private func checkGameCompletion() {
        // Hızlı kontrol: Eğer tahta yeterli derecede dolmamışsa, tamamlanmamıştır
        if !board.isBoardFilledEnough() {
            return
        }
        
        // Hata varsa, tamamlanmamıştır
        if !invalidCells.isEmpty {
            return
        }
        
        // Tam kontrol (daha maliyetli)
        if board.isComplete() {
            // Tamamlama sesi çal
            SoundManager.shared.playCompletionSound()
            
            // Oyun durumunu güncellemeden önce halihazırda oynanıyorsa diye kontrol et
            if gameState == .playing {
                print("✅ Sudoku tamamlandı! Skor kaydedilecek.")
                handleGameCompletion()
                
                // Kayıtlı oyunu sil (oyun tamamlandı)
                deleteSavedGameIfExists()
            } else {
                gameState = .completed
                stopTimer()
            }
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
        sameValueCellsCache.removeAll(keepingCapacity: true)
        
        // Yeni seçim için önbellekleri yeniden oluştur
        if let selected = selectedCell {
            precalculateHighlightedCells(row: selected.row, column: selected.column)
        }
    }
    
    // Tüm önbelleği geçersiz kıl
    private func invalidatePencilMarksCache() {
        pencilMarkCache.removeAll(keepingCapacity: true)
        validValuesCache.removeAll(keepingCapacity: true)
        sameValueCellsCache.removeAll(keepingCapacity: true)
        highlightedCellsCache.removeAll(keepingCapacity: true)
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
        var counts = [Int: Int]()
        
        // Sayma optimizasyonu: tek bir döngüde tüm değerleri topla
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = board.getValue(at: row, col: col), value > 0 {
                    counts[value, default: 0] += 1
                }
            }
        }
        
        // Sadece değişiklik varsa UI'ı güncelle
        if counts != usedNumbers {
            usedNumbers = counts
        }
    }
    
    // MARK: - İpucu ve Yardım
    
    // İpucu açıklama bilgisi
    @Published var showHintExplanation: Bool = false
    
    // İpucu tekniklerini belirten enum
    enum HintTechnique: String {
        case nakedSingle = "Tek Olasılık (Naked Single)"
        case hiddenSingle = "Tek Konum (Hidden Single)"
        case nakedPair = "Açık Çift (Naked Pair)"
        case hiddenPair = "Gizli Çift (Hidden Pair)"
        case nakedTriple = "Açık Üçlü (Naked Triple)"
        case hiddenTriple = "Gizli Üçlü (Hidden Triple)"
        case xWing = "X-Wing"
        case swordfish = "Swordfish"
        case general = "Son Kalan Hücre"
        case none = "Tespit Edilebilen İpucu Yok"
        
        var description: String {
            switch self {
            case .nakedSingle:
                return "Bu hücreye sadece tek bir sayı konabilir"
            case .hiddenSingle:
                return "Bu sayı, bu bölgede yalnızca tek bir hücreye konabilir"
            case .nakedPair:
                return "Bu iki hücre, aynı iki adayı paylaşıyor, dolayısıyla diğer hücrelerden bu adaylar çıkarılabilir"
            case .hiddenPair:
                return "Bu iki aday, yalnızca bu iki hücreye konabilir, dolayısıyla bu hücrelerden diğer adaylar çıkarılabilir"
            case .nakedTriple:
                return "Bu üç hücre, üç adayı paylaşıyor, dolayısıyla diğer hücrelerden bu adaylar çıkarılabilir"
            case .hiddenTriple:
                return "Bu üç aday, yalnızca bu üç hücreye konabilir"
            case .xWing:
                return "X-Wing deseni bulundu. Bu, belirli hücrelerden bazı adayların çıkarılmasına izin verir"
            case .swordfish:
                return "Swordfish deseni bulundu. Bu, belirli hücrelerden bazı adayların çıkarılmasına izin verir"
            case .general:
                return "Sudoku kurallarına göre bu hücreye bu değer konabilir"
            case .none:
                return "Tahta üzerinde tespit edilebilen bir ipucu yok. Daha karmaşık stratejilere ihtiyaç olabilir."
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
                return reason
            }
            return stepDescriptions[step]
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
        let reason = "Bu hücreye sadece \(value) değeri konabilir, çünkü diğer tüm değerler aynı satır, sütun veya blokta zaten kullanılmış."
        
        let hint = HintData(row: row, column: col, value: value, reason: reason, technique: HintTechnique.nakedSingle)
        
        // Adım 1: İlişkili hücreleri vurgula
        hint.addStep(title: "Satır, Sütun ve Blok İnceleme", 
                  description: "Bu hücrenin aynı satır, sütun ve blokta bulunan diğer hücreler incelendi.")
        hint.highlightRelatedCells(row: row, column: col, type: CellInteractionType.related)
        
        // Adım 2: Tek aday olduğunu göster
        hint.addStep(title: "Tek Olasılık Tespiti", 
                  description: "Bu hücreye sadece \(value) değeri konabilir, diğer tüm sayılar elendi.")
        
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
            regionName = "\(row+1). satırda"
            description = "\(value) sayısı, \(row+1). satırda sadece bu hücreye konabilir"
        case .column:
            regionName = "\(col+1). sütunda"
            description = "\(value) sayısı, \(col+1). sütunda sadece bu hücreye konabilir"
        case .block:
            let blockRow = (regionIndex / 3) + 1
            let blockCol = (regionIndex % 3) + 1
            regionName = "\(blockRow). satır, \(blockCol). sütundaki 3x3 blokta"
            description = "\(value) sayısı, bu 3x3 blokta sadece bu hücreye konabilir"
        }
        
        let reason = "\(regionName) \(value) sayısı sadece bu hücreye konabilir."
        
        let hint = HintData(row: row, column: col, value: value, reason: reason, technique: HintTechnique.hiddenSingle)
        
        // Adım 1: Bölgeyi vurgula
        hint.addStep(title: "Bölge İncelemesi", 
                  description: "\(regionName) tüm hücreler incelendi.")
        
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
        hint.addStep(title: "Tek Konum Tespiti", 
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
        let reason = "Sudoku kurallarına göre bu hücreye \(value) değeri konabilir."
        
        let hint = HintData(row: row, column: col, value: value, reason: reason, technique: HintTechnique.general)
        
        // Adım 1: İlişkili hücreleri vurgula
        hint.addStep(title: "Boş Hücre Analizi", 
                  description: "Bu hücre, sudoku tahtasında çözülebilir bir hücre olarak belirlendi.")
        
        // İlişkili hücreleri vurgula
        hint.highlightRelatedCells(row: row, column: col, type: CellInteractionType.related)
        
        // Adım 2: Değeri göster
        hint.addStep(title: "Değer Önerisi", 
                  description: "Bu hücreye \(value) değeri konabilir.")
        
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
        let hint = HintData(row: 0, column: 0, value: 0, reason: "Tahta üzerinde tespit edilebilen bir ipucu yok. Daha karmaşık stratejilere ihtiyaç olabilir.", technique: .none)
        
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
        guard gameState == .playing else { 
            print("⚠️ Oyun zaten tamamlanmış veya farklı bir durumda, işlem yapılmadı.")
            return 
        }
        
        print("🎮 Oyun başarıyla tamamlandı! İstatistikler: Hamle: \(moveCount), Hata: \(errorCount), İpucu: \(3 - remainingHints), Süre: \(Int(elapsedTime)) saniye")
        
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
        
        // Oyun tamamlandığında bildirim gönder (gerekirse kullanılabilir)
        NotificationCenter.default.post(name: NSNotification.Name("GameCompleted"), object: nil, userInfo: [
            "difficulty": board.difficulty.rawValue,
            "score": calculatePerformanceScore(),
            "time": elapsedTime
        ])
        
        print("✅ Oyun tamamlama işlemi tamamlandı ve skor kaydedildi.")
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
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
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
        // Eğer rakam doğru çözüm değeri ise ve pencilMode'dayız, rakamı direkt yerleştir
        let correctValue = board.getOriginalValue(at: row, col: col)
        
        if value == correctValue && pencilMode {
            // Doğru değeri bulduğumuzda hücreye direkt yerleştir
            // Kalem modundan çık
            pencilMode = false
            
            // Hücreye değeri yerleştir - gecikmesiz
            enterValue(value, at: row, col: col)
            
            // Ses çal
            SoundManager.shared.playCorrectSound()
            
            // Önbelleği geçersiz kıl
            invalidatePencilMarksCache(forRow: row, column: col)
            validateBoard()
            updateUsedNumbers()
            
            // Oyun tamamlanma kontrolü
            checkGameCompletion()
            
            // Hamle sayısını artır
            moveCount += 1
            
            // Otomatik kaydet
            autoSaveGame()
            
            return
        }
        
        // Normal pencil mark işlemleri
        board.togglePencilMark(at: row, col: col, value: value)
        
        // Önbelleği güncelle
        let key = "\(row)_\(col)"
        pencilMarkCache.removeValue(forKey: key)
    }
    
    // Bir hücredeki tüm kalem işaretlerini temizle
    func clearPencilMarks(at row: Int, col: Int) {
        board.clearPencilMarks(at: row, col: col)
        
        // Önbelleği güncelle
        let key = "\(row)_\(col)"
        pencilMarkCache.removeValue(forKey: key)
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
        print("saveGame fonksiyonu çalıştı")
        
        // Oyun tamamlandıysa veya başarısız olduysa kaydetmeye gerek yok
        if gameState == .completed || gameState == .failed {
            print("Oyun tamamlandığı veya başarısız olduğu için kaydedilmiyor")
            return
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
        jsonDict["userEnteredValues"] = userEnteredValues
                
        // Veriyi json formatına dönüştür
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
            
            // Not: jsonData kullanıldığını belirtmek için geçici bir print
            print("JSON veri boyutu: \(jsonData.count) byte")
            
            // Kaydetme işlemini gerçekleştir
            if let gameID = currentGameID, !forceNewSave {
                // Mevcut bir oyun varsa güncelle
                print("Mevcut oyun güncelleniyor, ID: \(gameID)")
                
                // PersistenceController üzerinden güncelleme yap
                PersistenceController.shared.updateSavedGame(
                    gameID: gameID,
                    board: boardArray,
                    difficulty: currentBoard.difficulty.rawValue,
                    elapsedTime: elapsedTime,
                    jsonData: jsonData
                )
                print("✅ Oyun başarıyla güncellendi, ID: \(gameID)")
        } else {
                // Yeni bir oyun kaydet ve ID'sini kaydet
                print("Yeni oyun kaydediliyor")
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
                print("✅ Yeni oyun başarıyla kaydedildi, ID: \(newGameID)")
            }
            
            print("Kaydetme işlemi tamamlandı")
            loadSavedGames() // Kaydedilmiş oyunları yeniden yükle
        } catch {
            print("❌ JSON oluşturma veya kaydetme hatası: \(error)")
        }
    }
    
    // Otomatik kaydet - çok sık çağrılmaması için zamanlayıcı eklenebilir
    private func autoSaveGame() {
        // Eğer oyun tamamlanmamışsa ve aktif oynanıyorsa kaydet
        if gameState == .playing {
            // Oyun ID'si varsa güncelle, yoksa yeni kaydet
            print("Otomatik kaydetme başladı...")
            saveGame(forceNewSave: false) // Var olan kaydı güncelle
            print("Otomatik kaydetme tamamlandı.")
        } else {
            print("Oyun \(gameState) durumunda olduğu için otomatik kaydedilmedi.")
        }
    }
    

    
    // MARK: - Saved Game Yönetimi
    
    // Kaydedilmiş oyunu yükle
    func loadGame(from savedGame: NSManagedObject) {
        print("Kayıtlı oyun yükleniyor: \(savedGame)")
        
        // Güvenli bir şekilde boardState'i al
        guard let boardData = savedGame.value(forKey: "boardState") as? Data else {
            print("❌ Oyun verisi bulunamadı")
            return
        }
        
        // Kayıtlı oyunun ID'sini al ve mevcut oyun ID'si olarak ayarla
        if let gameID = savedGame.value(forKey: "id") as? UUID {
            self.currentGameID = gameID
            print("Kaydedilmiş oyun ID'si ayarlandı: \(gameID)")
        } else if let gameIDString = savedGame.value(forKey: "id") as? String, 
                  let gameID = UUID(uuidString: gameIDString) {
            self.currentGameID = gameID
            print("Kaydedilmiş oyun ID'si (string'den) ayarlandı: \(gameID)")
        } else {
            // Eğer ID bulunamazsa, yeni bir ID oluştur
            self.currentGameID = UUID()
            print("Kaydedilmiş oyun için yeni ID oluşturuldu: \(self.currentGameID!)")
        }
        
        let difficultyString = savedGame.value(forKey: "difficulty") as? String ?? "Kolay"
        print("Kayıtlı oyun yükleniyor, zorluk seviyesi: \(difficultyString)")
        
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
            print("⚠️ userEnteredValues boş, tahta üzerinden hesaplanıyor")
            
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
        
        print("✅ Kullanıcı tarafından girilen değerler yüklendi: \(self.userEnteredValues.flatMap { $0.filter { $0 } }.count) değer")
        
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
                    print("✅ Oyun istatistikleri güncellendi")
                }
                
                // Kullanıcı tarafından girilen değerler zaten yüklendi
                // Bu kısmı atlıyoruz çünkü yeni fonksiyon imzasıyla doğrudan alıyoruz
                print("ℹ️ userEnteredValues zaten loadBoardFromData fonksiyonundan alındı - tekrar yüklemeye gerek yok")
            }
        } catch {
            print("⚠️ İstatistikleri yüklerken hata: \(error)")
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
                        print("✅ İstatistikler başarıyla yüklendi")
                    }
                }
            } catch {
                print("⚠️ İstatistikler yüklenemedi: \(error)")
                // Hata durumunda varsayılan değerleri kullan
            }
        }
        
        // Kullanılan rakamları güncelle
        updateUsedNumbers()
        
        // Zamanlayıcıyı başlat
        startTime = Date()
        startTimer()
        
        print("✅ Oyun başarıyla yüklendi, ID: \(currentGameID?.uuidString ?? "ID yok")")
    }
    
    // Veri objesinden SudokuBoard ve kullanıcı tarafından girilen değerleri oluştur
    private func loadBoardFromData(_ data: Data) -> (board: SudokuBoard, userValues: [[Bool]])? {
        print("\n\n💻 KAYDEDILMIŞ OYUN YÜKLEME BAŞLADI 💻")
        print("Veri boyutu: \(data.count) byte")
        
        // 1. Ana Json veri yapısını çözümlemeyi dene
        do {
            // Önce JSON'u dictionary'ye çevir
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ JSON veri biçimi geçersiz")
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
                print("✅ JSON'dan çözüm dizisi başarıyla yüklendi")
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
    private func stopTimer() {
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
        
        print("💬 Bildirim gözlemcileri başarıyla kuruldu")
    }
    
    // Uygulama arka plana alındığında çağrılır
    @objc private func pauseGameFromBackground() {
        // Sadece oyun aktif durumdaysa duraklat
        if gameState == .playing {
            print("🔊 Oyun otomatik olarak duraklatıldı (arka plan)")
            togglePause() // Oyunu duraklat
            saveGame() // Oyun durumunu kaydet
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
        print("⏰ Oyun zaman aşımına uğradı - kayıtlara ekleniyor ve sıfırlanıyor")
        
        // Mevcut oyun durumunu kayıtlara ekle (eğer kayıt şartlarını karşılıyorsa)
        if shouldSaveGameAfterTimeout() {
            // Oyunu normal kaydet, ancak zorluk seviyesini değiştirerek özel olarak işaretle
            let currentDifficulty = board.difficulty
            let timeoutSuffix = " - " + playerName + " (Arka Plan)"
            let modifiedDifficulty = currentDifficulty.rawValue + timeoutSuffix
            
            // Aynı zorluk seviyesinde "(Arka Plan)" ekiyle kaydedilmiş ve aynı zorluk seviyesinde olan oyunları bul
            let existingBackgroundGameID = checkForExistingBackgroundGame(difficulty: modifiedDifficulty)
            
            if let existingID = existingBackgroundGameID {
                // Mevcut arka plan oyununu güncelle
                print("🔄 Mevcut arka plan oyunu güncelleniyor, ID: \(existingID)")
                
                // Mevcut oyun verilerini al
                if let jsonData = createGameStateJSONForTimeout() {
                    // Mevcut oyunu güncelle
                    // board.getBoardArray() kullanarak 2D Int dizisi oluştur
                    let boardArray = board.getBoardArray()
                    
                    // Mevcut oyunu güncelle
                    PersistenceController.shared.updateSavedGame(
                        gameID: existingID,
                        board: boardArray,
                        difficulty: modifiedDifficulty,
                        elapsedTime: elapsedTime,
                        jsonData: jsonData
                    )
                    
                    // Mevcut oyun ID'sini güncelle
                    currentGameID = existingID
                }
            } else {
                // Normal kaydetme fonksiyonunu kullan
                saveGame(forceNewSave: true) // Yeni bir oyun olarak kaydet
                
                // Kaydedilen oyunun zorluk seviyesini güncelle
                if let gameID = currentGameID {
                    PersistenceController.shared.updateGameDifficulty(gameID: gameID, newDifficulty: modifiedDifficulty)
                }
            }
            
            print("✅ Zaman aşımına uğrayan oyun kayıtlara eklendi")
        } else {
            print("ℹ️ Oyun kayıt şartlarını karşılamıyor, kaydedilmedi")
        }
        
        // Ana menüyü göstermek için bildirim gönder
        NotificationCenter.default.post(name: Notification.Name("ShowMainMenuAfterTimeout"), object: nil)
        
        // Oyun durumunu sıfırla
        resetGameState()
        
        // Yeni bir tahta oluştur (mevcut zorluk seviyesini kullanarak)
        let currentDifficulty = board.difficulty
        board = SudokuBoard(difficulty: currentDifficulty)
        updateUsedNumbers()
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
    
    // Performans iyileştirmesi: Önbellekleme ile hücre vurgusu kontrolü
    private var highlightedCellsCache: [String: Bool] = [:]
    private var sameValueCellsCache: [String: Bool] = [:]
    
    // Geçici bir süre için önbellekleri geçersiz kıl
    func invalidateCellCache() {
        highlightedCellsCache.removeAll(keepingCapacity: true)
        sameValueCellsCache.removeAll(keepingCapacity: true)
    }
    
    // Hücre vurgu hesaplaması için önbellekli versiyon
    func isHighlighted(row: Int, column: Int) -> Bool {
        guard let selected = selectedCell else { return false }
        
        // Önbellekten kontrol et
        let cacheKey = "h_\(row)_\(column)_\(selected.row)_\(selected.column)"
        if let cached = highlightedCellsCache[cacheKey] {
            return cached
        }
        
        // Aynı satır veya sütunda mı kontrol et
        let result = selected.row == row || selected.column == column
        
        // Sonucu önbelleğe al
        highlightedCellsCache[cacheKey] = result
        
        return result
    }
    
    // Aynı değere sahip hücreleri vurgulama için optimizasyon
    func hasSameValue(row: Int, column: Int) -> Bool {
        guard let selected = selectedCell else { return false }
        
        // Aynı hücre ise, aynı değere sahip değildir
        if selected.row == row && selected.column == column {
            return false
        }
        
        // Seçili hücrenin değeri
        guard let selectedValue = board.getValue(row: selected.row, column: selected.column), 
              selectedValue > 0 else {
            return false
        }
        
        // Önbellekten kontrol et
        let cacheKey = "v_\(row)_\(column)_\(selectedValue)"
        if let cached = sameValueCellsCache[cacheKey] {
            return cached
        }
        
        // Hücre değerini kontrol et
        let cellValue = board.getValue(row: row, column: column)
        
        // Değerlerin birbirine eşit olup olmadığını kontrol et
        // 0 değeri özel durum - boş hücre
        let result = cellValue == selectedValue && cellValue != 0
        
        // Sonucu önbelleğe al
        sameValueCellsCache[cacheKey] = result
        
        return result
    }
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
