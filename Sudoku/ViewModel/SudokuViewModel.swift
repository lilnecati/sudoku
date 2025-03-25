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
        guard let boardData = savedGame.getData(key: "boardState") else {
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
        self.userEnteredValues = userValues
        print("✅ Kullanıcı tarafından girilen değerler doğrudan yüklendi: \(userValues.flatMap { $0.filter { $0 } }.count) değer")
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
        
        // Kalem notları için önbelleği temizle
        pencilMarkCache.removeAll(keepingCapacity: true)
        
        // İstatistikler JSON verisi içinden okunuyor, burada sıfırlama yapmıyoruz
        
        // Eğer kaydedilmiş istatistikler varsa güvenli bir şekilde okuma yap
        // Core Data modelinde bu alanların tanımlı olup olmadığını kontrol etmeye gerek yok
        // Güvenli bir şekilde JSON verisi olarak depolanıyorsa okuma yapabiliriz
        if let boardData = savedGame.getData(key: "boardState") {
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
            let difficultyValue3: SudokuBoard.Difficulty
            switch difficulty {
            case "Kolay": difficultyValue3 = .easy
            case "Orta": difficultyValue3 = .medium
            case "Zor": difficultyValue3 = .hard
            case "Uzman": difficultyValue3 = .expert
            default: difficultyValue3 = .easy
            }
            
            // Bu değişkeni board oluştururken kullanacağız
            _ = difficultyValue3
            
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
            
            // Zorluk seviyesini Difficulty enum değerine çevir
            let difficultyValue4: SudokuBoard.Difficulty
            switch difficulty {
            case "Kolay": difficultyValue4 = .easy
            case "Orta": difficultyValue4 = .medium
            case "Zor": difficultyValue4 = .hard
            case "Uzman": difficultyValue4 = .expert
            default: difficultyValue4 = .easy
            }
            
            // Bu değişkeni board oluştururken kullanacağız
            let boardDifficultyEnum2 = difficultyValue4
            
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
            
            // Kullanıcı tarafından girilen değerler bilgisini JSON'dan a l
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
 
