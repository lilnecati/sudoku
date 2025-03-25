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
        // Daha önceki bir seçim varsa ve aynı hücre seçilirse, seçimi kaldır
        if selectedCell?.row == row && selectedCell?.column == column {
            selectedCell = nil
        } else {
            selectedCell = (row, column)
            lastSelectedCell = (row, column)
        }
        
        // Dokunsal geri bildirim - sadece gerekirse
        if enableHapticFeedback {
            feedbackGenerator.prepare() // Geri bildirimi hazırla (daha hızlı yanıt)
            feedbackGenerator.impactOccurred(intensity: 0.5) // Daha hafif titreşim (pil tasarrufu)
        }
    }
    
    // Seçili hücreye değer atar - optimize edildi
    func setValueAtSelectedCell(_ value: Int?) {
        guard let selectedCell = selectedCell else { return }
        let row = selectedCell.row
        let col = selectedCell.column
        
        // Eğer orijinal/sabit bir hücre ise, değişime izin verme
        if board.isFixed(at: row, col: col) {
            return
        }
        
        let currentValue = board.getValue(at: row, col: col)
        
        if pencilMode {
            // Kalem modu işlemi - notlar için
            if let value = value {
                togglePencilMark(at: row, col: col, value: value)
            }
            return
        }
        
        // Doğru değer kontrolü - Sadece doğru çözüm değeri veya silme işlemi
        let correctValue = board.getOriginalValue(at: row, col: col)
        
        // Değer silme işlemi - her zaman izin verilir
        if value == nil {
            if currentValue != nil {
                enterValue(value, at: row, col: col)
                // Önbelleği geçersiz kıl
                invalidatePencilMarksCache(forRow: row, column: col)
                validateBoard()
                updateUsedNumbers()
            }
            return
        }
        
        // Değer girme işlemi - sadece doğru çözüm değerine izin ver
        if value != correctValue {
            // Yanlış değer - hata geri bildirimi ve engellenecek
            errorCount += 1
            
            // Hatalı hücreyi işaretle
            let position = Position(row: row, col: col)
            invalidCells.insert(position)
            
            // Hata geri bildirimi
            if enableHapticFeedback {
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
            // Hatayı kısa süre sonra temizle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.invalidCells.remove(position)
            }
            
            // Maksimum hata sayısını kontrol et
            if errorCount >= maxErrorCount {
                gameState = .failed
                stopTimer()
            }
            
            // Hatalı değeri girmiyoruz
            return
        } else {
            // Doğru değer
            
            // Performans: Sadece değişiklik varsa işlem yap
            if currentValue != value {
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
            }
        }
    }
    
    // MARK: - Performans Optimizasyonları
    
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
            gameState = .completed
            stopTimer()
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
    }
    
    // Tüm önbelleği geçersiz kıl
    private func invalidatePencilMarksCache() {
        pencilMarkCache.removeAll(keepingCapacity: true)
        validValuesCache.removeAll(keepingCapacity: true)
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
    
    // İpucu talep et - optimize edildi
    func requestHint() {
        // İpucu hakkı kalmadıysa ipucu verme
        if remainingHints <= 0 {
            return
        }
        
        guard let selectedCell = selectedCell else { return }
        let row = selectedCell.row
        let col = selectedCell.column
        
        // Eğer hücre zaten doluysa veya sabit bir hücre ise ipucu verme
        if board.isFixed(at: row, col: col) || board.getValue(at: row, col: col) != nil {
            return
        }
        
        // Orijinal değeri al
        if let solution = board.getOriginalValue(at: row, col: col) {
            // Hücreyi çöz
            enterValue(solution, at: row, col: col)
            
            // İpucu sayısını artır
            hintCount += 1
            
            // Kalan ipucu hakkını azalt
            remainingHints -= 1
            
            // Geçersiz hücreleri temizle
            validateBoard()
            
            // Kullanılan rakamları güncelle
            updateUsedNumbers()
        }
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
        guard gameState == .playing else { return }
        
        gameState = .completed
        timer?.invalidate()
        
        // Skoru kaydet
        ScoreManager.shared.saveScore(
            difficulty: board.difficulty,
            timeElapsed: elapsedTime,
            errorCount: errorCount,
            hintCount: 3 - remainingHints
        )
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
        board.setValue(at: row, col: col, value: value)
    }
    
    // Kalem işareti değiştirme
    func togglePencilMark(at row: Int, col: Int, value: Int) {
        board.togglePencilMark(at: row, col: col, value: value)
        
        // Önbelleği güncelle
        let key = "\(row)_\(col)"
        pencilMarkCache.removeValue(forKey: key)
    }
    
    // Kalem işareti var mı
    func isPencilMarkSet(row: Int, column: Int, value: Int) -> Bool {
        return board.isPencilMarkSet(row: row, column: column, value: value)
    }
    
    // MARK: - Oyun Kaydetme/Yükleme
    
    // Oyunu kaydet
    func saveGame() {
        print("saveGame fonksiyonu çalıştı")
        
        // Direk kaydet, saveState kontrolünü kaldır
        print("PersistenceController.saveGame fonksiyonu çalıştı")
        PersistenceController.shared.saveGame(
            board: board.getBoardArray(),
            difficulty: board.difficulty.rawValue,
            elapsedTime: elapsedTime
        )
        print("PersistenceController.saveGame tamamlandı")
        loadSavedGames() // Kaydedilmiş oyunları yeniden yükle
        print("loadSavedGames() tamamlandı")
    }
    
    // Otomatik kaydet
    private func autoSaveGame() {
        // Eğer oyun tamamlanmamışsa kaydet
        if gameState == .playing {
            print("Otomatik kaydetme başladı...")
            saveGame()
            print("Otomatik kaydetme tamamlandı.")
        } else {
            print("Oyun durumu 'şu anda' (gameState) olduğu için kaydedilmedi.")
        }
    }
    

    
    // MARK: - Saved Game Yönetimi
    
    // Kaydedilmiş oyunu yükle
    func loadGame(from savedGame: NSManagedObject) {
        print("Kayıtlı oyun yükleniyor: \(savedGame)")
        
        // Güvenli bir şekilde boardState'i al
        guard let boardData = savedGame.getData(key: "boardState") else {
            print("❌ Oyun verisi bulunamadı")
            return
        }
        
        // Kayıtlı oyunlarda zorluk seviyesini belirlemek için okuyoruz, ancak değişkenini saklamamıza veya kullanmamıza gerek yok
        // Çünkü SudokuBoard oluştururken zaten bu bilgi kaydedilmiş durumda
        // Sadece log amaçlı olarak yazdırıyoruz
        let difficultyString = savedGame.value(forKey: "difficulty") as? String ?? "Kolay"
        print("Kayıtlı oyun yükleniyor, zorluk seviyesi: \(difficultyString)")
        
        // Doğrudan oyun verilerinden SudokuBoard oluşturuyoruz
        guard let loadedBoard = loadBoardFromData(boardData) else {
            print("❌ Oyun tahta verisi yüklenemedi")
            return
        }
        
        // SudokuBoard'u kaydedilmiş oyundan yükledik, loadedBoard.difficulty özelliği zaten doğru değere sahip
        
        self.board = loadedBoard
        self.elapsedTime = savedGame.getDouble(key: "elapsedTime")
        self.pausedElapsedTime = self.elapsedTime
        self.gameState = .playing
        
        // Seçili hücreyi sıfırla
        selectedCell = nil
        
        // Kalem notları için önbelleği temizle - SavedGame modelinde pencilMarks anahtarı yok
        pencilMarkCache.removeAll(keepingCapacity: true)
        
        // İstatistikleri sıfırla - SavedGame modelinde bu anahtarlar bulunmayabilir
        // Bu yüzden varsayılan değerleri kullanıyoruz
        errorCount = 0
        hintCount = 0
        moveCount = 0
        remainingHints = 3
        
        // Kullanılan rakamları güncelle
        updateUsedNumbers()
        
        // Zamanlayıcıyı başlat
        startTime = Date()
        startTimer()
    }
    
    // Veri objesinden SudokuBoard oluştur
    private func loadBoardFromData(_ data: Data) -> SudokuBoard? {
        // Önce doğrudan decode etmeyi dene
        if let board = try? JSONDecoder().decode(SudokuBoard.self, from: data) {
            print("✅ SudokuBoard başarıyla direkt decode edildi")
            return board
        }
        
        // Bu olmazsa loadFromSavedState'i dene
        if let board = SudokuBoard.loadFromSavedState(data) {
            print("✅ loadFromSavedState ile tahta yüklendi")
            return board
        }
        
        print("❌ SudokuBoard'u decode etmekte hata")
        return nil
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
    
    // Objelerden kurtulmak için
    deinit {
        stopTimer()
    }
    
    // Oyun durumu değiştiğinde çağrılır
    private func handleGameStateChange() {
        switch gameState {
        case .completed:
            // Oyun tamamlandığında skoru kaydet
            ScoreManager.shared.saveScore(
                difficulty: board.difficulty,
                timeElapsed: elapsedTime,
                errorCount: errorCount,
                hintCount: 3 - remainingHints
            )
            
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
}

// MARK: - NSManagedObject Extensions for HighScoresView Compatibility
extension NSManagedObject {
    func getHighScoreDifficulty() -> String {
        return getString(key: "difficulty", defaultValue: "Kolay")
    }
    
    func getHighScoreElapsedTime() -> Double {
        return getDouble(key: "elapsedTime")
    }
    
    func getHighScoreDate() -> Date {
        return getDate(key: "date")
    }
}
 
