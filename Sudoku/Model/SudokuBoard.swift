import Foundation
import SwiftUI

// Sudoku tahtasını temsil eden sınıf
class SudokuBoard: ObservableObject, Codable {
    // Zorluk seviyesi
    enum Difficulty: String, CaseIterable, Identifiable, Codable {
        case easy = "Kolay"
        case medium = "Orta"
        case hard = "Zor"
        case expert = "Uzman"
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            // Text.localizedSafe yerine doğrudan LocalizationManager kullanarak diziyi alıyoruz
            let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "en"
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            let bundle = path != nil ? Bundle(path: path!) : Bundle.main
            
            return bundle?.localizedString(forKey: self.rawValue, value: self.rawValue, table: "Localizable") ?? self.rawValue
        }
        
        // Zorluk seviyesi açıklaması
        var description: String {
            switch self {
            case .easy:
                return "Başlangıç seviyesi, yeni başlayanlar için ideal"
            case .medium:
                return "Orta zorlukta, biraz tecrübe gerektirir"
            case .hard:
                return "Zorlu, stratejik düşünme becerisi gerektirir"
            case .expert:
                return "En zorlu seviye, gerçek Sudoku ustaları için"
            }
        }
        
        // Her zorluk seviyesi için bırakılacak ipucu sayısı aralığı
        var clueRange: ClosedRange<Int> {
            switch self {
            case .easy: return 40...45   // Kolay: Azaltıldı (42...47 -> 40...45)
            case .medium: return 34...38 // Orta: Azaltıldı (36...40 -> 34...38)
            case .hard: return 28...32   // Zor: Azaltıldı (30...34 -> 28...32)
            case .expert: return 24...27 // Uzman: Azaltıldı (26...29 -> 24...27)
            }
        }
    }
    
    // MARK: - Özellikler
    
    // Tahta verileri
    private var board: [[Int?]]
    private var originalBoard: [[Int?]]
    private var solution: [[Int?]]
    private var fixedCells: Set<String>
    private var pencilMarks: [String: Set<Int>]
    
    // Performans önbellekleri
    private var completeCheckCache: Bool?
    private var filledCheckCache: Int?
    private var validPlacementCache = [String: Any]()
    
    // Zorluk
    let difficulty: Difficulty
    // İpucu olarak verilen, değiştirilemeyen hücreleri belirten matris
    private var fixed: [[Bool]]
    
    // Önbellek değişkenleri
    private var emptyCellCountCache: Int?
    private var nakedSingleCountCache: Int?
    private var hiddenSingleCountCache: Int?
    private var nakedPairsUsedCache: Bool?
    private var pointingPairsUsedCache: Bool?
    private var boxLineReductionUsedCache: Bool?
    private var xWingUsedCache: Bool?
    
    // MARK: - Başlatıcı
    
    init(difficulty: Difficulty = .easy) {
        self.difficulty = difficulty
        self.board = Array(repeating: Array(repeating: nil, count: 9), count: 9)
        self.originalBoard = Array(repeating: Array(repeating: nil, count: 9), count: 9)
        self.solution = Array(repeating: Array(repeating: nil, count: 9), count: 9)
        self.fixedCells = Set<String>()
        self.pencilMarks = [:]
        self.fixed = Array(repeating: Array(repeating: false, count: 9), count: 9)
        
        generateBoard()
    }
    
    // Özel başlatıcı: Kaydedilmiş oyundan yükle
    init(board: [[Int?]], solution: [[Int]], fixed: [[Bool]], difficulty: Difficulty) {
        self.board = board
        self.solution = solution
        self.fixed = fixed
        self.difficulty = difficulty
        self.originalBoard = board
        self.fixedCells = Set<String>()
        self.pencilMarks = [:]
        
        // Kaydedilmiş oyunda zaten tüm değerler verildiği için generateBoard() çağrısına gerek yok
        // Sadece sabit hücreleri işaretle
        for row in 0..<9 {
            for col in 0..<9 {
                if fixed[row][col] {
                    let key = "\(row)_\(col)"
                    fixedCells.insert(key)
                }
            }
        }
    }
    
    // MARK: - Temel İşlemler
    
    // Hücre değeri al
    func getValue(row: Int, column: Int) -> Int? {
        guard isValidIndex(row: row, column: column) else { return nil }
        return board[row][column]
    }
    
    // Alternatif isim aynı işlem için
    func getValue(at row: Int, col: Int) -> Int? {
        return getValue(row: row, column: col)
    }
    
    // Hücre değeri ayarla
    @discardableResult
    func setValue(row: Int, column: Int, value: Int?) -> Bool {
        guard isValidIndex(row: row, column: column) else { return false }
        
        // Sabit hücreyi değiştirmeye izin verme
        if isOriginalValue(row: row, column: column) {
            return false
        }
        
        // Değer değişirse, önbellekleri temizle
        if board[row][column] != value {
            invalidateCaches()
            board[row][column] = value
            return true
        }
        
        return false
    }
    
    // Alternatif isim aynı işlem için
    @discardableResult
    func setValue(at row: Int, col: Int, value: Int?) -> Bool {
        return setValue(row: row, column: col, value: value)
    }
    
    // Hücre sabit mi (başlangıç değeri)
    func isOriginalValue(row: Int, column: Int) -> Bool {
        let key = "\(row)_\(column)"
        return fixedCells.contains(key)
    }
    
    // Alternatif isim (isFixed) aynı işlem için
    func isFixed(at row: Int, col: Int) -> Bool {
        return isOriginalValue(row: row, column: col)
    }
    
    // Çözüm değerini al
    func getSolutionValue(row: Int, column: Int) -> Int? {
        guard isValidIndex(row: row, column: column) else { return nil }
        return solution[row][column]
    }
    
    // Orijinal değeri al (çözüm)
    func getOriginalValue(at row: Int, col: Int) -> Int? {
        guard isValidIndex(row: row, column: col) else {
            logWarning("SudokuBoard.getOriginalValue: Geçersiz indeks: (\(row), \(col))")
            return nil
        }
        return solution[row][col]
    }
    
    // Hücredeki değer doğru mu kontrol et
    func isCorrectValue(row: Int, column: Int, value: Int) -> Bool {
        guard isValidIndex(row: row, column: column) else { return false }
        return solution[row][column] == value
    }
    
    // MARK: - Pencil Marks (Kalem İşaretleri)
    
    // Kalem işareti ekle/çıkar
    func togglePencilMark(row: Int, column: Int, value: Int) {
        guard isValidIndex(row: row, column: column) else { return }
        guard value >= 1 && value <= 9 else { return }
        
        let key = "\(row)_\(column)"
        
        if var cellMarks = pencilMarks[key] {
            if cellMarks.contains(value) {
                cellMarks.remove(value)
            } else {
                cellMarks.insert(value)
            }
            pencilMarks[key] = cellMarks
        } else {
            pencilMarks[key] = [value]
        }
    }
    
    // Alternatif isim aynı işlem için
    func togglePencilMark(at row: Int, col: Int, value: Int) {
        togglePencilMark(row: row, column: col, value: value)
    }
    
    // Kalem işareti var mı
    func isPencilMarkSet(row: Int, column: Int, value: Int) -> Bool {
        guard isValidIndex(row: row, column: column) else { return false }
        
        let key = "\(row)_\(column)"
        return pencilMarks[key]?.contains(value) ?? false
    }
    
    // Hücrede kalem işaretleri var mı
    func hasPencilMarks(row: Int, column: Int) -> Bool {
        guard isValidIndex(row: row, column: column) else { return false }
        
        let key = "\(row)_\(column)"
        return !(pencilMarks[key]?.isEmpty ?? true)
    }
    
    // Kalem işaretlerini al
    func getPencilMarks(row: Int, column: Int) -> Set<Int> {
        guard isValidIndex(row: row, column: column) else { return [] }
        
        let key = "\(row)_\(column)"
        return pencilMarks[key] ?? []
    }
    
    // Alternatif isim aynı işlem için
    func getPencilMarks(at row: Int, col: Int) -> Set<Int> {
        return getPencilMarks(row: row, column: col)
    }
    
    // Bir hücredeki tüm kalem notlarını sil
    func clearPencilMarks(at row: Int, col: Int) {
        guard isValidIndex(row: row, column: col) else { return }
        
        let key = "\(row)_\(col)"
        pencilMarks[key] = []
    }
    
    // MARK: - Tahta Kontrolü
    
    // Tahta tamamlandı mı?
    func isComplete() -> Bool {
        // Önbellekten kontrol et, mevcutsa kullan
        if let cached = completeCheckCache {
            return cached
        }
        
        // Boş hücre kontrolü (hızlı kontrol)
        if hasEmptyCells() {
            completeCheckCache = false
            return false
        }
        
        // Her satırın, sütunun ve bloğun 1-9 rakamlarını içerdiğini kontrol et
        for i in 0..<9 {
            // Satır kontrolü
            var rowSet = Set<Int>()
            for j in 0..<9 {
                if let value = board[i][j] {
                    rowSet.insert(value)
                }
            }
            if rowSet.count != 9 {
                completeCheckCache = false
                return false
            }
            
            // Sütun kontrolü
            var colSet = Set<Int>()
            for j in 0..<9 {
                if let value = board[j][i] {
                    colSet.insert(value)
                }
            }
            if colSet.count != 9 {
                completeCheckCache = false
                return false
            }
            
            // 3x3 blok kontrolü
            let blockRow = (i / 3) * 3
            let blockCol = (i % 3) * 3
            var blockSet = Set<Int>()
            
            for r in blockRow..<(blockRow + 3) {
                for c in blockCol..<(blockCol + 3) {
                    if let value = board[r][c] {
                        blockSet.insert(value)
                    }
                }
            }
            if blockSet.count != 9 {
                completeCheckCache = false
                return false
            }
        }
        
        // Tüm kontroller geçildi, tahta tamamlandı
        completeCheckCache = true
        return true
    }
    
    // Tahta yeterince dolu mu? (Hızlı bir ön kontrol için)
    func isBoardFilledEnough() -> Bool {
        // 65 hücre doluysa, tahta neredeyse tamamlanmış demektir (81 hücreden)
        let minimumFilledCells = 65
        var filledCount = 0
        
        // Önbellekten kontrol et, mevcutsa kullan
        if let cached = filledCheckCache, cached >= minimumFilledCells {
            return true
        }
        
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] != nil {
                    filledCount += 1
                    if filledCount >= minimumFilledCells {
                        filledCheckCache = filledCount
                        return true
                    }
                }
            }
        }
        
        filledCheckCache = filledCount
        return false
    }
    
    // Tahtada boş hücre var mı?
    func hasEmptyCells() -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == nil {
                    return true
                }
            }
        }
        return false
    }
    
    // Bir değerin belirli bir hücreye yerleştirilmesi geçerli mi?
    func isValidPlacement(row: Int, column: Int, value: Int) -> Bool {
        guard isValidIndex(row: row, column: column) else { return false }
        
        // Önbellekten kontrol et
        let cacheKey = "\(row)_\(column)_\(value)"
        if let cached = validPlacementCache[cacheKey] as? Bool {
            return cached
        }
        
        // Optimizasyon: Çözüm değeri önceden biliniyorsa, direkt kontrol et
        if let solutionValue = solution[row][column], solutionValue != value {
            validPlacementCache[cacheKey] = false
            return false
        }
        
        // Hızlı yol: Eğer hücrede zaten bir değer varsa ve o değer gelen değerden farklıysa
        if let currentValue = board[row][column], currentValue != value {
            validPlacementCache[cacheKey] = false
            return false
        }
        
        // Optimizasyon: Satır, sütun ve blok kontrollerini tek geçişte yapalım
        let blockRow = (row / 3) * 3
        let blockCol = (column / 3) * 3
        
        // Satır ve sütun için birleştirilmiş hızlı kontrol
        for i in 0..<9 {
            // Satır kontrolü (row, i)
            if let cellValue = board[row][i], cellValue == value && i != column {
                validPlacementCache[cacheKey] = false
                return false
        }
        
            // Sütun kontrolü (i, column)
            if let cellValue = board[i][column], cellValue == value && i != row {
                validPlacementCache[cacheKey] = false
                return false
            }
        }
        
        // 3x3 blok kontrolü - sadece aynı blokta ve satır/sütun dışındaki hücreler için
        for r in blockRow..<(blockRow + 3) {
            for c in blockCol..<(blockCol + 3) {
                // Satır ve sütun kontrolünde tekrar kontrol edilmiş hücreleri atlayalım
                if r == row || c == column {
                    continue
                }
                
                if let cellValue = board[r][c], cellValue == value {
                    validPlacementCache[cacheKey] = false
                    return false
                }
            }
        }
        
        // Tüm kontroller geçildi, geçerli bir yerleştirme
        validPlacementCache[cacheKey] = true
        return true
    }
    
    // MARK: - Tahta Yönetimi
    
    // Tahtayı başlangıç durumuna sıfırla
    func resetToOriginal() {
        // Tahtayı başlangıç durumuna döndür
        for row in 0..<9 {
            for col in 0..<9 {
                board[row][col] = originalBoard[row][col]
            }
        }
        
        // Kalem işaretlerini temizle
        pencilMarks.removeAll(keepingCapacity: true)
        
        // Önbellekleri temizle
        invalidateCaches()
    }
    
    // Önbellekleri temizle
    private func invalidateCaches() {
        emptyCellCountCache = nil
        nakedSingleCountCache = nil
        hiddenSingleCountCache = nil
        completeCheckCache = nil
        filledCheckCache = nil
        validPlacementCache.removeAll(keepingCapacity: true)
        nakedPairsUsedCache = nil
        pointingPairsUsedCache = nil
        boxLineReductionUsedCache = nil
        xWingUsedCache = nil
    }
    
    // MARK: - Yardımcı Metodlar
    
    // İndekslerin geçerli olup olmadığını kontrol et
    private func isValidIndex(row: Int, column: Int) -> Bool {
        return row >= 0 && row < 9 && column >= 0 && column < 9
    }
    
    // MARK: - Tahta Oluşturma
    
    // Sudoku tahtası oluştur
    private func generateBoard() {
        // Debug mesajını kaldırıyoruz
        
        // Mevcut değerleri temizle
        for row in 0..<9 {
            for col in 0..<9 {
                 board[row][col] = nil
                originalBoard[row][col] = nil
                solution[row][col] = nil
            }
        }
        
        // Çözüm içeren bir tahta oluştur
        generateSolution()
        // Debug mesajını kaldırıyoruz
        
        // Çözüm geçerli mi kontrol et
        var solutionHasNils = false
        for row in 0..<9 {
            for col in 0..<9 {
                if solution[row][col] == nil {
                    solutionHasNils = true
                    logError("Çözümde nil değer var: [\(row)][\(col)]")
                }
            }
        }
        
        // Çözüm geçersizse tekrar oluştur
        if solutionHasNils {
            logWarning("Çözümde nil değerler var, tekrar deneniyor...")
            return generateBoard()
        }
        
        // Gösterilecek ipucu sayısını belirle
        let cluesToShow = getCluesToShow()
        // Debug mesajını kaldırıyoruz
        
        // Önce çözümü tahtaya kopyala
        for row in 0..<9 {
            for col in 0..<9 {
                board[row][col] = solution[row][col]
            }
        }
        
        // Zorluk seviyesine göre özel algoritma seç
        switch difficulty {
        case .easy:
            generateEasyPuzzle(cluesToShow: cluesToShow)
        case .medium:
            generateMediumPuzzle(cluesToShow: cluesToShow)
        case .hard:
            generateHardPuzzle(cluesToShow: cluesToShow)
        case .expert:
            generateExpertPuzzle(cluesToShow: cluesToShow)
        }
        
        // Oluşan ipucu sayısını kontrol et
        var clueCount = 0
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] != nil {
                    clueCount += 1
                }
            }
        }
        // Debug mesajını kaldırıyoruz
        
        // Sabit hücreleri işaretle
        markFixedCells()
    }
    
    // Kolay seviye tahta oluştur
    private func generateEasyPuzzle(cluesToShow: Int) {
        // Kolay seviye için 40-45 ipucu bırakılır
        let cellsToRemove = 81 - cluesToShow
        
        // Hücreleri hem zorluk derecesine göre sırala hem de rastgele karıştır
        var cellsWithDifficulty = getAllCellsWithDifficultyRating()
        
        // Aynı zorluk derecesine sahip hücreleri kendi aralarında karıştır
        var startIndex = 0
        
        for i in 0..<cellsWithDifficulty.count {
            if i == cellsWithDifficulty.count - 1 || cellsWithDifficulty[i].2 != cellsWithDifficulty[i+1].2 {
                // Aynı zorluk seviyesindeki hücreleri karıştır
                let endIndex = i
                let range = startIndex...endIndex
                let subArray = Array(cellsWithDifficulty[range])
                let shuffled = subArray.shuffled()
                
                for j in 0..<shuffled.count {
                    cellsWithDifficulty[startIndex + j] = shuffled[j]
                }
                
                // Bir sonraki zorluk seviyesi için hazırlan
                if i < cellsWithDifficulty.count - 1 {
                    startIndex = i + 1
                }
            }
        }
        
        var removedCount = 0
        
        // Önce en kolay kaldırılabilecek hücreleri kaldır
        for (row, col, _) in cellsWithDifficulty {
            if removedCount >= cellsToRemove {
                break
            }
            
            let originalValue = board[row][col]
            board[row][col] = nil
            
            // Benzersiz çözüm ve dengeli dağılım kontrolü
            if hasUniqueSolution() && hasBalancedDistribution() {
                removedCount += 1
            } else {
                // Geri al
                board[row][col] = originalValue
            }
        }
    }
    
    // Orta seviye tahta oluştur
    private func generateMediumPuzzle(cluesToShow: Int) {
        // Orta seviye için 36-40 ipucu bırakılır
        let cellsToRemove = 81 - cluesToShow
        
        // Orta seviye için özel hücre kaldırma
        let allCells = getAllCellsInRandomOrder()
        var removedCount = 0
        
        // Rastgele seçilen hücreleri kaldır
        for (row, col) in allCells {
            if removedCount >= cellsToRemove {
                break
            }
            
            let originalValue = board[row][col]
            board[row][col] = nil
            
            // Orta seviye kontroller: 
            // Naked pairs ve hidden singles gerektiren bir zorluk seviyesi
            if maintainsMediumDifficulty() && hasBalancedDistribution() {
                removedCount += 1
            } else {
                // Geri al
                board[row][col] = originalValue
            }
        }
    }
    
    // Zor seviye tahta oluştur
    private func generateHardPuzzle(cluesToShow: Int) {
        // Zor seviye için 30-34 ipucu bırakılır
        let cellsToRemove = 81 - cluesToShow
        
        // Zor seviye için özel hücre kaldırma
        let allCells = getAllCellsInRandomOrder()
        var removedCount = 0
        
        // Rastgele seçilen hücreleri kaldır
        for (row, col) in allCells {
            if removedCount >= cellsToRemove {
                break
            }
            
            let originalValue = board[row][col]
            board[row][col] = nil
            
            // Zor seviye kontroller:
            // Pointing pairs ve box-line reduction gerektiren bir zorluk
            if maintainsHardDifficulty() && hasBalancedDistribution() {
                removedCount += 1
            } else {
                // Geri al
                board[row][col] = originalValue
            }
        }
    }
    
    // Uzman seviye tahta oluştur
    private func generateExpertPuzzle(cluesToShow: Int) {
        // Uzman seviye için 26-29 ipucu bırakılır
        let cellsToRemove = 81 - cluesToShow
        
        // Uzman seviye için özel hücre kaldırma
        let allCells = getAllCellsInRandomOrder()
        var removedCount = 0
        
        // Rastgele seçilen hücreleri kaldır
        for (row, col) in allCells {
            if removedCount >= cellsToRemove {
                break
            }
            
            let originalValue = board[row][col]
            board[row][col] = nil
            
            // Uzman seviye kontroller:
            // X-Wing ve ileri teknikler gerektiren bir zorluk
            if maintainsExpertDifficulty() && hasBalancedDistribution() {
                removedCount += 1
            } else {
                // Geri al
                board[row][col] = originalValue
            }
        }
    }
    
    // Tüm hücreleri rastgele sırayla al
    private func getAllCellsInRandomOrder() -> [(Int, Int)] {
        var allCells = [(Int, Int)]()
        for row in 0..<9 {
            for col in 0..<9 {
                allCells.append((row, col))
            }
        }
        allCells.shuffle()
        return allCells
    }
    
    // Hücreleri kaldırma zorluğuna göre sırala
    private func getAllCellsWithDifficultyRating() -> [(Int, Int, Int)] {
        var cellsWithDifficulty = [(Int, Int, Int)]() // (row, col, difficulty)
        
        for row in 0..<9 {
            for col in 0..<9 {
                // Her hücre için bir zorluk derecesi hesapla
                let difficulty = calculateCellRemovalDifficulty(row: row, col: col)
                
                // Rastgele bir varyasyon ekle (0-2 arası)
                let randomVariation = Int.random(in: 0...2)
                let adjustedDifficulty = difficulty + randomVariation
                
                cellsWithDifficulty.append((row, col, adjustedDifficulty))
            }
        }
        
        // Zorluk derecesine göre sırala (en kolay kaldırılabilecek önce)
        return cellsWithDifficulty.sorted { $0.2 < $1.2 }
    }
    
    // Bir hücrenin kaldırılma zorluğunu hesapla
    private func calculateCellRemovalDifficulty(row: Int, col: Int) -> Int {
        // Satır, sütun ve bloktaki dolu hücre sayısını hesapla
        var rowCount = 0, colCount = 0, blockCount = 0
        let blockRow = row / 3, blockCol = col / 3
        
        for i in 0..<9 {
            if board[row][i] != nil { rowCount += 1 }
            if board[i][col] != nil { colCount += 1 }
            
            let r = blockRow * 3 + i / 3
            let c = blockCol * 3 + i % 3
            if board[r][c] != nil { blockCount += 1 }
        }
        
        // Daha fazla dolu hücre olan birimlerden hücre kaldırmak daha kolaydır
        return -(rowCount + colCount + blockCount)
    }
    
    // Benzersiz çözüm kontrolü
    private func hasUniqueSolution() -> Bool {
        // Mevcut tahtanın kopyasını oluştur
        var tempBoard = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for r in 0..<9 {
            for c in 0..<9 {
                tempBoard[r][c] = board[r][c] ?? 0
            }
        }
        
        // Çözüm sayacı
        var solutionCount = 0
        
        // Backtracking ile çözüm sayısını bul
        func solve(row: Int, col: Int) -> Bool {
            // Eğer birden fazla çözüm bulunduysa, daha fazla aramaya gerek yok
            if solutionCount > 1 {
                return true
            }
            
            // Tüm hücreler dolduysa, bir çözüm bulundu
            if row == 9 {
                solutionCount += 1
                return solutionCount > 1 // Birden fazla çözüm bulunduysa true döndür
            }
            
            // Bir sonraki hücreye geç
            let nextRow = col == 8 ? row + 1 : row
            let nextCol = col == 8 ? 0 : col + 1
            
            // Eğer hücre zaten doluysa, bir sonraki hücreye geç
            if tempBoard[row][col] != 0 {
                return solve(row: nextRow, col: nextCol)
            }
            
            // Tüm olası değerleri dene
            for num in 1...9 {
                if isValidPlacement(row: row, column: col, value: num, board: tempBoard) {
                    tempBoard[row][col] = num
                    
                    // Bir sonraki hücreye geç
                    if solve(row: nextRow, col: nextCol) {
                        // Birden fazla çözüm bulunduysa ve hala aranıyorsa
                        if solutionCount > 1 {
                            return true
                        }
                        // Backtrack - diğer olası çözümleri aramak için
                        tempBoard[row][col] = 0
                    } else {
                        // Çözüm bulunamadıysa, backtrack
                        tempBoard[row][col] = 0
                    }
                }
            }
            
            return false
        }
        
        // Çözüm aramaya başla
        _ = solve(row: 0, col: 0)
        
        // Tam olarak bir çözüm varsa true döndür
        return solutionCount == 1
    }
    
    // Geçici tahta için yerleştirme kontrolü
    private func isValidPlacement(row: Int, column: Int, value: Int, board: [[Int]]) -> Bool {
        // Satır kontrolü
        for i in 0..<9 {
            if board[row][i] == value {
                return false
            }
        }
        
        // Sütun kontrolü
        for i in 0..<9 {
            if board[i][column] == value {
                return false
            }
        }
        
        // 3x3 blok kontrolü
        let blockRow = (row / 3) * 3
        let blockCol = (column / 3) * 3
        
        for r in 0..<3 {
            for c in 0..<3 {
                if board[blockRow + r][blockCol + c] == value {
                    return false
                }
            }
        }
        
        return true
    }
    
    // Basit çözülebilirlik kontrolü
    private func maintainsSimpleSolving() -> Bool {
        // Kolay seviye için: 
        // - Tahta çözülebilir olmalı
        // - Benzersiz çözüm kontrolü
        return hasUniqueSolution()
    }
    
    // Dengeli dağılım kontrolü
    private func hasBalancedDistribution() -> Bool {
        // Her blok, satır ve sütundaki ipucu sayısını kontrol et
        let blockMinimum: Int
        let rowColMinimum: Int
        
        switch difficulty {
        case .easy:
            blockMinimum = 3
            rowColMinimum = 2
        case .medium:
            blockMinimum = 2
            rowColMinimum = 1
        case .hard, .expert:
            blockMinimum = 2
            rowColMinimum = 1
        }
        
        // Blok kontrolleri
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                var blockCount = 0
                for r in 0..<3 {
                    for c in 0..<3 {
                        let row = blockRow * 3 + r
                        let col = blockCol * 3 + c
                        if board[row][col] != nil {
                            blockCount += 1
                        }
                    }
                }
                if blockCount < blockMinimum {
                    return false
                }
            }
        }
        
        // Satır ve sütun kontrolleri
        for i in 0..<9 {
            var rowCount = 0
            var colCount = 0
            for j in 0..<9 {
                if board[i][j] != nil {
                    rowCount += 1
                }
                if board[j][i] != nil {
                    colCount += 1
                }
            }
            if rowCount < rowColMinimum || colCount < rowColMinimum {
                return false
            }
        }
        
        return true
    }
    
    // Orta seviye zorluk kontrolü
    private func maintainsMediumDifficulty() -> Bool {
        // Orta seviye: Logic çözülebilir olmalı
        return testLogicalSolvability()
    }
    
    // Zor seviye zorluk kontrolü
    private func maintainsHardDifficulty() -> Bool {
        // Zor seviye: Logic çözülebilir olmalı ve ileri teknikler gerektirmeli
        return testLogicalSolvability()
    }
    
    // Uzman seviye zorluk kontrolü
    private func maintainsExpertDifficulty() -> Bool {
        // Uzman seviye: Logic çözülebilir olmalı ve en ileri teknikleri gerektirmeli
        return testLogicalSolvability()
    }
    
    // Çözümü oluştur
    private func generateSolution() {
        // Doğrudan hızlı ve garantili yöntemi kullan
        // Debug mesajını kaldırıyoruz
        generateSimpleSolution()
    }
    
    // Basit, garantili bir çözüm oluştur
    private func generateSimpleSolution() {
        // Tamamen temiz bir başlangıç
        for row in 0..<9 {
            for col in 0..<9 {
                board[row][col] = nil
                solution[row][col] = nil
            }
        }
        
        // Tamamen rastgele bir sudoku üretmek yerine, basePattern kullanıp onu çok daha fazla karıştıralım
        // İlk olarak temel bir desen oluşturalım (standart Latin karesi)
        var basePattern = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        
        // İlk satırı 1-9 arasında rastgele düzenleyelim
        var firstRow = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        firstRow.shuffle() // İlk satırı rastgele karıştır
        
        // İlk satırı yerleştir
        for col in 0..<9 {
            basePattern[0][col] = firstRow[col]
        }
        
        // Sonraki satırları otomatik olarak kaydırarak oluştur (Latin kare özelliği)
        for row in 1..<9 {
            // Her satırı bir önceki satıra göre 3 adım kaydır (blok yapısını korurken çakışmaları önler)
            let offset = (row % 3 == 0) ? 1 : 3
            
            for col in 0..<9 {
                let sourceIdx = (col + offset) % 9
                basePattern[row][col] = basePattern[row-1][sourceIdx]
            }
        }
        
        // Şimdi bu base pattern'i tahtaya kopyalayalım
        for row in 0..<9 {
            for col in 0..<9 {
                board[row][col] = basePattern[row][col]
                solution[row][col] = basePattern[row][col]
            }
        }
        
        // Şimdi çok daha agresif bir karıştırma işlemi uygulayalım
        mixSudokuCompletely()
    }
    
    // Sudoku'yu tamamen karıştır
    private func mixSudokuCompletely() {
        // Daha fazla karıştırma işlemi uygula (100 kez)
        for _ in 0..<100 {
            // Rastgele bir dönüşüm seç
            let transformation = Int.random(in: 0..<8)
            
            switch transformation {
            case 0:
                // Satır bloklarını karıştır
                let blocks = [0, 1, 2].shuffled()
                swapRowBlocks(blocks[0], blocks[1])
            case 1:
                // Sütun bloklarını karıştır
                let blocks = [0, 1, 2].shuffled()
                swapColumnBlocks(blocks[0], blocks[1])
            case 2:
                // Blok içi satırları karıştır
                let blockRow = Int.random(in: 0..<3)
                let rowsInBlock = [0, 1, 2].shuffled()
                swapRows(blockRow * 3 + rowsInBlock[0], blockRow * 3 + rowsInBlock[1])
            case 3:
                // Blok içi sütunları karıştır
                let blockCol = Int.random(in: 0..<3)
                let colsInBlock = [0, 1, 2].shuffled()
                swapColumns(blockCol * 3 + colsInBlock[0], blockCol * 3 + colsInBlock[1])
            case 4:
                // Sayı değerlerini değiştir (1-9 arası iki sayıyı takas et)
                let num1 = Int.random(in: 1...9)
                var num2 = Int.random(in: 1...9)
                while num2 == num1 {
                    num2 = Int.random(in: 1...9)
                }
                swapValues(num1, num2)
            case 5:
                // Tahtayı 90 derece döndür
                rotateBoard()
            case 6:
                // Tüm satırları karıştır (blok yapısını koruyarak)
                for blockRow in 0..<3 {
                    let rows = [0, 1, 2].shuffled()
                    swapRows(blockRow * 3 + rows[0], blockRow * 3 + rows[1])
                    swapRows(blockRow * 3 + rows[1], blockRow * 3 + rows[2])
                }
            case 7:
                // Tüm sütunları karıştır (blok yapısını koruyarak)
                for blockCol in 0..<3 {
                    let cols = [0, 1, 2].shuffled()
                    swapColumns(blockCol * 3 + cols[0], blockCol * 3 + cols[1])
                    swapColumns(blockCol * 3 + cols[1], blockCol * 3 + cols[2])
                }
            default:
                break
            }
        }
    }
    
    // İki sütun bloğunu değiştir
    private func swapColumnBlocks(_ block1: Int, _ block2: Int) {
        guard block1 != block2 else { return }
        
        let col1 = block1 * 3
        let col2 = block2 * 3
        
        // Her blokta 3 sütun var
        for i in 0..<3 {
            swapColumns(col1 + i, col2 + i)
        }
    }
    
    // Tahtadaki iki sayı değerini değiştir
    private func swapValues(_ val1: Int, _ val2: Int) {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == val1 {
                    board[row][col] = val2
                    solution[row][col] = val2
                } else if board[row][col] == val2 {
                    board[row][col] = val1
                    solution[row][col] = val1
                }
            }
        }
    }
    
    // Tahtayı 90 derece döndür
    private func rotateBoard() {
        let oldBoard = board
        let oldSolution = solution
        
        for row in 0..<9 {
            for col in 0..<9 {
                // 90 derece döndürme: (row, col) -> (col, 8-row)
                board[col][8-row] = oldBoard[row][col]
                solution[col][8-row] = oldSolution[row][col]
            }
        }
    }
    
    // Çözümü rastgele karıştır (geçerliliği koruyarak)
    private func shuffleSolution() {
        // 1-9 arasındaki değerleri rastgele permütasyonla değiştir
        // Daha basit ve daha güvenli bir yaklaşım kullanalım
        
        // Hangi değerin yerine hangi değerin geçeceğini belirle (karıştırılmış 1-9 dizisi)
        var numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        numbers.shuffle() 
        
        // Tüm hücreleri dolaş ve değerleri değiştir
        // Değer eşleştirmelerini tek bir adımda yaparak dizi indeksleme hatalarından kaçınalım
        for row in 0..<9 {
            for col in 0..<9 {
                // Önce geçici bir değişkene atayarak sonradan ilgili değeri kullanalım
                if let currentValue = solution[row][col] {
                    // currentValue 1-9 arasında olacaktır, buna göre yeni değeri belirleyelim
                    if currentValue >= 1 && currentValue <= 9 {
                        let newIndex = currentValue - 1  // 0-tabanlı indekse dönüştür
                        if newIndex < numbers.count {
                            let newValue = numbers[newIndex]
                            solution[row][col] = newValue
                            board[row][col] = newValue
                        }
                    }
                }
            }
        }
    }
    
    // Satırları ve sütunları bloklar içinde karıştır (geçerliliği koruyarak)
    private func shuffleRowsAndColumns() {
        // Daha fazla karıştırma için döngü ekleyelim
        for _ in 0..<3 {
            // 3x3 blokları kendi içinde karıştır
            shuffleBlocksWithinGrid()
            
        // Her bir 3x3 blok içindeki satırları karıştır
        for blockRow in 0..<3 {
            // 0, 1, 2 satır indekslerini karıştır
            let rowIndices = [0, 1, 2].shuffled()
            
            // Bu blok içindeki satırları karıştır
            let baseRow = blockRow * 3
            swapRows(baseRow, baseRow + rowIndices[0])
            swapRows(baseRow + 1, baseRow + rowIndices[1])
            swapRows(baseRow + 2, baseRow + rowIndices[2])
        }
        
        // Her bir 3x3 blok içindeki sütunları karıştır
        for blockCol in 0..<3 {
            // 0, 1, 2 sütun indekslerini karıştır
            let colIndices = [0, 1, 2].shuffled()
            
            // Bu blok içindeki sütunları karıştır
            let baseCol = blockCol * 3
            swapColumns(baseCol, baseCol + colIndices[0])
            swapColumns(baseCol + 1, baseCol + colIndices[1])
            swapColumns(baseCol + 2, baseCol + colIndices[2])
            }
        }
    }
    
    // 3x3 blokları birbirleriyle karıştır (satır ve sütun blokları)
    private func shuffleBlocksWithinGrid() {
        // Satır blokları karıştır (0, 1, 2 satır bloğu)
        let rowBlockIndices = [0, 1, 2].shuffled()
        
        // İlk bloku karıştır (0 ile rowBlockIndices[0])
        if 0 != rowBlockIndices[0] {
        for i in 0..<3 {
                swapRows(0 * 3 + i, rowBlockIndices[0] * 3 + i)
            }
        }
        
        // İkinci bloku karıştır (1 ile rowBlockIndices[1])
        if 1 != rowBlockIndices[1] {
        for i in 0..<3 {
                swapRows(1 * 3 + i, rowBlockIndices[1] * 3 + i)
            }
        }
        
        // Üçüncü bloku karıştır (2 ile rowBlockIndices[2])
        if 2 != rowBlockIndices[2] {
            for i in 0..<3 {
                swapRows(2 * 3 + i, rowBlockIndices[2] * 3 + i)
            }
        }
        
        // Sütun blokları karıştır (0, 1, 2 sütun bloğu)
        let colBlockIndices = [0, 1, 2].shuffled()
        
        // İlk bloku karıştır (0 ile colBlockIndices[0])
        if 0 != colBlockIndices[0] {
            for i in 0..<3 {
                swapColumns(0 * 3 + i, colBlockIndices[0] * 3 + i)
            }
        }
        
        // İkinci bloku karıştır (1 ile colBlockIndices[1])
        if 1 != colBlockIndices[1] {
            for i in 0..<3 {
                swapColumns(1 * 3 + i, colBlockIndices[1] * 3 + i)
            }
        }
        
        // Üçüncü bloku karıştır (2 ile colBlockIndices[2])
        if 2 != colBlockIndices[2] {
            for i in 0..<3 {
                swapColumns(2 * 3 + i, colBlockIndices[2] * 3 + i)
            }
        }
    }
    
    // İki satırı takas et
    private func swapRows(_ row1: Int, _ row2: Int) {
        guard row1 != row2 else { return }
        
        for col in 0..<9 {
            let temp = board[row1][col]
            board[row1][col] = board[row2][col]
            board[row2][col] = temp
            
            let tempSol = solution[row1][col]
            solution[row1][col] = solution[row2][col]
            solution[row2][col] = tempSol
        }
    }
    
    // İki sütunu takas et
    private func swapColumns(_ col1: Int, _ col2: Int) {
        guard col1 != col2 else { return }
        
        for row in 0..<9 {
            let temp = board[row][col1]
            board[row][col1] = board[row][col2]
            board[row][col2] = temp
            
            let tempSol = solution[row][col1]
            solution[row][col1] = solution[row][col2]
            solution[row][col2] = tempSol
        }
    }
    
    // İki satır bloğunu takas et (her biri 3 satırdan oluşur)
    private func swapRowBlocks(_ block1: Int, _ block2: Int) {
        guard block1 != block2 else { return }
        
        let row1 = block1 * 3
        let row2 = block2 * 3
        
        // Her blokta 3 satır var
        for i in 0..<3 {
            swapRows(row1 + i, row2 + i)
        }
    }
    
    // Dengeli bir başlangıç tahtası oluştur
    private func createBalancedStartingBoard() {
        // Tahtayı temizle
        for row in 0..<9 {
            for col in 0..<9 {
                board[row][col] = nil
            }
        }
        
        // Başlangıç olarak her bloğa rastgele değerler yerleştir
        // İlk geçişte daha fazla hücre dolduralım ki çözücünün işi kolaylaşsın
        
        // Her blokta birkaç sayı yerleştir
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                // Her blokta 2-3 sayı yerleştir
                let cellCount = Int.random(in: 2...3)
                var placed = 0
                
                // Blok içindeki tüm hücreleri karıştır
                var blockCells = [(Int, Int)]()
                for r in 0..<3 {
                    for c in 0..<3 {
                        blockCells.append((blockRow * 3 + r, blockCol * 3 + c))
                    }
                }
                blockCells.shuffle()
                
                // Karışık hücrelere değer yerleştirmeyi dene
                for (row, col) in blockCells {
                    if placed >= cellCount {
                        break
                    }
                    
                    // 1-9 arası tüm değerleri karıştırıp dene
                    let valuesToTry = Array(1...9).shuffled()
                    
                    for value in valuesToTry {
                        if isValidPlacement(row: row, column: col, value: value) {
                            board[row][col] = value
                            placed += 1
                            break
                        }
                    }
                }
            }
        }
        
        // Ek hücreler ekle - her satır ve sütunda
        // Satırlar için
        for row in 0..<9 {
            let additionalCount = Int.random(in: 0...2) // Her satıra 0-2 ek sayı
            var added = 0
            
            let cols = Array(0..<9).shuffled()
            for col in cols {
                if board[row][col] == nil && added < additionalCount {
                    let possibleValues = getPossibleValues(row: row, column: col)
                    if !possibleValues.isEmpty {
                        board[row][col] = possibleValues.randomElement()
                        added += 1
                    }
                }
            }
        }
        
        // Sütunlar için de benzer işlem yap
        for col in 0..<9 {
            let additionalCount = Int.random(in: 0...2) // Her sütuna 0-2 ek sayı
            var added = 0
            
            let rows = Array(0..<9).shuffled()
            for row in rows {
                if board[row][col] == nil && added < additionalCount {
                    let possibleValues = getPossibleValues(row: row, column: col)
                    if !possibleValues.isEmpty {
                        board[row][col] = possibleValues.randomElement()
                        added += 1
                    }
                }
            }
        }
    }
    
    // Bir hücreye yerleştirilebilecek olası değerleri getir
    private func getPossibleValues(row: Int, column: Int) -> Set<Int> {
        guard isValidIndex(row: row, column: column) else { return [] }
        
        // Eğer hücrede zaten değer varsa, boş set döndür
        if board[row][column] != nil {
            return []
        }
        
        // Optimize edilmiş yaklaşım: tüm değerleri bir set olarak al ve kullanılanları çıkar
        var possibleValues = Set(1...9)
        
        // Optimizasyon: Satır, sütun ve blok kontrollerini tek geçişte yapalım
        let blockRow = (row / 3) * 3
        let blockCol = (column / 3) * 3
        
        // Satır ve sütun için birleştirilmiş tarama
        for i in 0..<9 {
            // Satırdaki kullanılan değerleri çıkar
            if let value = board[row][i] {
                possibleValues.remove(value)
            }
            
            // Sütundaki kullanılan değerleri çıkar
            if let value = board[i][column] {
                possibleValues.remove(value)
            }
        }
        
        // 3x3 blok kontrolü - satır ve sütunda kontrol edilmeyen hücreler için
        for r in blockRow..<(blockRow + 3) {
            for c in blockCol..<(blockCol + 3) {
                // Satır ve sütun kontrolünde tekrar kontrol edilmiş hücreleri atlayalım
                if r == row || c == column {
                    continue
                }
                
                if let value = board[r][c] {
                    possibleValues.remove(value)
                }
            }
        }
        
        return possibleValues
    }
    
    // Tahtayı çöz (geri izleme algoritması)
    private func solveBoard(_ board: inout [[Int?]]) -> Bool {
        // Performans optimizasyonu: Önce tüm boş hücreleri bul ve sırala
        var emptyCells = [(row: Int, col: Int)]()
        
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == nil {
                    emptyCells.append((row, col))
                }
            }
        }
        
        // Boş hücre yoksa tahta çözülmüş demektir
        if emptyCells.isEmpty {
            return true
        }
        
        // Performans optimizasyonu: Boş hücreleri olası değer sayısına göre sırala (en az olasılıklı önce)
        emptyCells.sort { (cell1, cell2) -> Bool in
            let values1 = possibleValues(for: cell1.row, col: cell1.col, in: board)
            let values2 = possibleValues(for: cell2.row, col: cell2.col, in: board)
            return values1.count < values2.count
        }
        
        // İlk hücreyi al (en az olasılığa sahip)
        let (row, col) = emptyCells[0]
        
        // Bu hücre için olası değerleri bul ve dene
        let possibleVals = possibleValues(for: row, col: col, in: board)
        
        // Hücre için olası değer yoksa çözümü başarısız
        if possibleVals.isEmpty {
            return false
        }
        
        // Tüm olası değerleri dene
        for value in possibleVals {
            // Değeri yerleştir
            board[row][col] = value
            
            // Geriye kalan tahtayı tekrar çözmeyi dene
            if solveBoard(&board) {
                return true
            }
            
            // Çözüm başarısız olduysa geri al ve başka değer dene
            board[row][col] = nil
        }
        
        // Hiçbir değer işe yaramadıysa çözülemez
        return false
    }
    
    // Zorluk derecesine göre gösterilecek ipucu sayısını belirle
    private func getCluesToShow() -> Int {
        // clueRange özelliğinden rastgele bir değer seç
        let range = difficulty.clueRange
        return Int.random(in: range)
    }
    
    // Sabit (başlangıç) hücreleri işaretle
    private func markFixedCells() {
        fixedCells.removeAll(keepingCapacity: true)
        
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] != nil {
                    let key = "\(row)_\(col)"
                    fixedCells.insert(key)
                }
            }
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case board, solution, fixed, difficulty, pencilMarks
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(board, forKey: .board)
        try container.encode(solution, forKey: .solution)
        try container.encode(fixed, forKey: .fixed)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(pencilMarks, forKey: .pencilMarks)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        board = try container.decode([[Int?]].self, forKey: .board)
        solution = try container.decode([[Int?]].self, forKey: .solution)
        fixed = try container.decode([[Bool]].self, forKey: .fixed)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        pencilMarks = try container.decode([String: Set<Int>].self, forKey: .pencilMarks)
        originalBoard = board
        fixedCells = Set<String>()
        
        // Sabit hücreleri işaretle
        for row in 0..<9 {
            for col in 0..<9 {
                if fixed[row][col] {
                    let key = "\(row)_\(col)"
                    fixedCells.insert(key)
                }
            }
        }
        
        // Önbellekleri temizle
        completeCheckCache = nil
        filledCheckCache = nil
        validPlacementCache = [:]
    }
    
    // MARK: - Game Saving/Loading
    
    /// Oyun durumunu kaydetmek için Data nesnesine çevirir
    func saveState() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    /// Tahtayı 2D Int dizisine dönüştür (nil değerler 0 olarak kaydedilir)
    func getBoardArray() -> [[Int]] {
        var boardArray = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        
        for row in 0..<9 {
            for col in 0..<9 {
                boardArray[row][col] = board[row][col] ?? 0
            }
        }
        
        return boardArray
    }
    
    /// Kaydedilmiş oyun durumundan SudokuBoard nesnesi oluşturur
    static func loadFromSavedState(_ data: Data) -> SudokuBoard? {
        if let json = try? JSONSerialization.jsonObject(with: data) {
            // Yeni format (Dictionary) kontrolü
            if let boardDict = json as? [String: Any],
               let boardArray = boardDict["board"] as? [[Int]],
               let difficultyString = boardDict["difficulty"] as? String,
               let difficulty = Difficulty(rawValue: difficultyString) {
                
                logInfo("Yeni format tespit edildi")
                // Yeni bir SudokuBoard oluştur
                let sudokuBoard = SudokuBoard(difficulty: difficulty)
                
                // Tahta verilerini yükleyelim
                for row in 0..<9 {
                    for col in 0..<9 {
                        let value = boardArray[row][col]
                        if value != 0 {
                            sudokuBoard.setValue(at: row, col: col, value: value)
                        }
                    }
                }
                
                return sudokuBoard
            } 
            // Eski format (düz array) kontrolü
            else if let boardArray = json as? [[Int]] {
                logInfo("Eski format tespit edildi")
                let sudokuBoard = SudokuBoard(difficulty: .easy)
                
                for row in 0..<9 {
                    for col in 0..<9 {
                        let value = boardArray[row][col]
                        if value != 0 {
                            sudokuBoard.setValue(at: row, col: col, value: value)
                        }
                    }
                }
                
                return sudokuBoard
            }
        }
        
        // Kaydedilmiş verileri temizleyelim
        logWarning("Format anlaşılabilir değil, kaydedilmiş verileri siliyor olabilirsiniz")
        return nil
    }
    
    // Constraint Propagation ve Elimine yöntemi ile bir çözüm bul
    private func solveSudokuElimination(_ board: [[Int?]]) -> [[Int?]]? {
        var boardCopy = board
        
        // Önce Constraint Propagation uygula
        if let propagatedBoard = applyConstraintPropagation(boardCopy) {
            // Constraint Propagation ile tamamen çözülebildi mi kontrol et
            if isCompleteSolution(propagatedBoard) {
                return propagatedBoard
            }
            boardCopy = propagatedBoard
        } else {
            // Constraint Propagation çelişki buldu, çözüm yok
            return nil
        }
        
        var emptyPositions = [(Int, Int)]()
        
        // Boş pozisyonları bul
        for row in 0..<9 {
            for col in 0..<9 {
                if boardCopy[row][col] == nil {
                    emptyPositions.append((row, col))
                }
            }
        }
        
        // Hiç boş konum yoksa çözüm tamamlanmıştır
        if emptyPositions.isEmpty {
            return boardCopy
        }
        
        // Boş pozisyonları, mümkün olan değer sayısına göre sırala (MRV heuristiği)
        emptyPositions.sort { pos1, pos2 in
            let (row1, col1) = pos1
            let (row2, col2) = pos2
            
            let possibleValues1 = possibleValues(for: row1, col: col1, in: boardCopy)
            let possibleValues2 = possibleValues(for: row2, col: col2, in: boardCopy)
            
            return possibleValues1.count < possibleValues2.count
        }
        
        // En az olasılığa sahip hücreyi al
        let (nextRow, nextCol) = emptyPositions.first!
        let possibleValuesForCell = possibleValues(for: nextRow, col: nextCol, in: boardCopy)
        
        // Olası değer yoksa çözüm bulunamadı
        if possibleValuesForCell.isEmpty {
            return nil
        }
        
        // Mümkün değerler, rastgele sırada denenir
        let cellsToTry = possibleValuesForCell.shuffled()
        
        // Her olası değeri dene
        for value in cellsToTry {
            boardCopy[nextRow][nextCol] = value
            
            // Rekürsif çözmeyi dene
            if let solution = solveSudokuElimination(boardCopy) {
                return solution
            }
            
            // Çözüm bulunamadıysa, hücreyi tekrar boşalt
            boardCopy[nextRow][nextCol] = nil
        }
        
        // Çözüm bulunamadı
        return nil
    }
    
    // Constraint Propagation tekniğini uygula
    private func applyConstraintPropagation(_ board: [[Int?]]) -> [[Int?]]? {
        var boardCopy = board
        var changed = true
        
        // Değişiklik olmayıncaya kadar devam et
        while changed {
            changed = false
            
            // 1. Naked Singles: Her hücre için tek olasılık varsa, o değeri yerleştir
            if applyNakedSingles(&boardCopy) {
                changed = true
            }
            
            // 2. Hidden Singles: Birim (satır, sütun, blok) içinde benzersiz olasılıkları bul
            if applyHiddenSingles(&boardCopy) {
                changed = true
            }
            
            // 3. Pointing Pairs/Triples: Blok içindeki aynı satır/sütundaki olasılıklar
            // possibleValues değişkeni burada tanımlanmadığı için bu tekniği atlıyoruz
            // Bu teknik testLogicalSolvability fonksiyonunda kullanılıyor
            // if applyPointingPairs(&boardCopy, possibleValues) {
            //     changed = true
            // }
        }
        
        // Tahta geçerli mi kontrol et
        if !isBoardValid(boardCopy) {
            return nil
        }
        
        return boardCopy
    }
    
    // Naked Singles: Tek olasılığı olan hücreleri doldur
    private func applyNakedSingles(_ board: inout [[Int?]]) -> Bool {
        var changed = false
        
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == nil {
                    let possibilities = possibleValues(for: row, col: col, in: board)
                    
                    if possibilities.count == 1, let value = possibilities.first {
                        board[row][col] = value
                        changed = true
                    } else if possibilities.isEmpty {
                        // Hiç olasılık yoksa, bu tahta çözülemez
                        return false
                    }
                }
            }
        }
        
        return changed
    }
    
    // Hidden Singles: Birim içinde sadece bir hücrede olabilen değerleri bul
    private func applyHiddenSingles(_ board: inout [[Int?]]) -> Bool {
        var changed = false
        
        // Her birim türünü kontrol et: satır, sütun ve blok
        // 1. Satırları kontrol et
        for row in 0..<9 {
            changed = changed || findHiddenSinglesInRow(row, board: &board)
        }
        
        // 2. Sütunları kontrol et
        for col in 0..<9 {
            changed = changed || findHiddenSinglesInColumn(col, board: &board)
        }
        
        // 3. 3x3 blokları kontrol et
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                changed = changed || findHiddenSinglesInBlock(blockRow, blockCol, board: &board)
            }
        }
        
        return changed
    }
    
    // Bir satırda hidden singles bul
    private func findHiddenSinglesInRow(_ row: Int, board: inout [[Int?]]) -> Bool {
        var changed = false
        var valueCounts = [Int: [Int]]()
        
        // Her değer için, o değerin yerleştirilebileceği sütunları bul
        for value in 1...9 {
            valueCounts[value] = []
        }
        
        // Satırdaki boş hücreleri ve olasılıkları incele
        for col in 0..<9 {
            if board[row][col] == nil {
                let possibilities = possibleValues(for: row, col: col, in: board)
                for value in possibilities {
                    valueCounts[value]?.append(col)
                }
            }
        }
        
        // Sadece bir hücrede olabilen değerleri bul
        for (value, columns) in valueCounts {
            if columns.count == 1 {
                let col = columns[0]
                if board[row][col] == nil {
                    board[row][col] = value
                    changed = true
                }
            }
        }
        
        return changed
    }
    
    // Bir sütunda hidden singles bul
    private func findHiddenSinglesInColumn(_ col: Int, board: inout [[Int?]]) -> Bool {
        var changed = false
        var valueCounts = [Int: [Int]]()
        
        // Her değer için, o değerin yerleştirilebileceği satırları bul
        for value in 1...9 {
            valueCounts[value] = []
        }
        
        // Sütundaki boş hücreleri ve olasılıkları incele
        for row in 0..<9 {
            if board[row][col] == nil {
                let possibilities = possibleValues(for: row, col: col, in: board)
                for value in possibilities {
                    valueCounts[value]?.append(row)
                }
            }
        }
        
        // Sadece bir hücrede olabilen değerleri bul
        for (value, rows) in valueCounts {
            if rows.count == 1 {
                let row = rows[0]
                if board[row][col] == nil {
                    board[row][col] = value
                    changed = true
                }
            }
        }
        
        return changed
    }
    
    // Bir 3x3 blokta hidden singles bul
    private func findHiddenSinglesInBlock(_ blockRow: Int, _ blockCol: Int, board: inout [[Int?]]) -> Bool {
        var changed = false
        var valueCounts = [Int: [(Int, Int)]]()
        
        // Her değer için, o değerin yerleştirilebileceği hücreleri bul
        for value in 1...9 {
            valueCounts[value] = []
        }
        
        // Bloktaki boş hücreleri ve olasılıkları incele
        for r in 0..<3 {
            for c in 0..<3 {
                let row = blockRow * 3 + r
                let col = blockCol * 3 + c
                
                if board[row][col] == nil {
                    let possibilities = possibleValues(for: row, col: col, in: board)
                    for value in possibilities {
                        valueCounts[value]?.append((row, col))
                    }
                }
            }
        }
        
        // Sadece bir hücrede olabilen değerleri bul
        for (value, cells) in valueCounts {
            if cells.count == 1 {
                let (row, col) = cells[0]
                if board[row][col] == nil {
                    board[row][col] = value
                    changed = true
                }
            }
        }
        
        return changed
    }
    
    // Pointing Pairs/Triples: Blok içindeki aynı satır/sütundaki olasılıkları kullanarak eleme
    private func applyPointingPairs(_ board: inout [[Int?]], _ possibleValues: [[[Bool]]]) -> Bool {
        var changed = false
        let blockSize = 3
        
        // Her 3x3 blok için
        for blockRow in 0..<blockSize {
            for blockCol in 0..<blockSize {
                // Her olası değer için (1-9)
                for value in 1...9 {
                    // Değeri 0-bazlı indekse çevir
                    let valueIndex = value - 1
                    
                    // Bu değerin bu blokta hangi satırlarda ve sütunlarda olabileceğini bul
                    var rowOccurrences = [Int: Int](minimumCapacity: blockSize)
                    var colOccurrences = [Int: Int](minimumCapacity: blockSize)
                    
                    // Blok içindeki hücreleri tara
                    for r in 0..<blockSize {
                        for c in 0..<blockSize {
                            let row = blockRow * blockSize + r
                            let col = blockCol * blockSize + c
                            
                            if possibleValues[row][col][valueIndex] {
                                rowOccurrences[r, default: 0] += 1
                                colOccurrences[c, default: 0] += 1
                            }
                        }
                    }
                    
                    // Pointing Pair/Triple for Rows - Optimize edilmiş versiyon
                    if rowOccurrences.count == 1, let (blockRowIndex, count) = rowOccurrences.first, count >= 2 {
                        let actualRow = blockRow * blockSize + blockRowIndex
                        // Bu değer sadece bir satırda ve bu blokta olabiliyorsa, satırın diğer bloklardaki hücrelerinden bu değeri çıkar
                        changed = changed || removeValueFromOtherBlocksInRow(value, row: actualRow, exceptBlockCol: blockCol, board: &board)
                    }
                    
                    // Pointing Pair/Triple for Columns - Optimize edilmiş versiyon
                    if colOccurrences.count == 1, let (blockColIndex, count) = colOccurrences.first, count >= 2 {
                        let actualCol = blockCol * blockSize + blockColIndex
                        // Bu değer sadece bir sütunda ve bu blokta olabiliyorsa, sütunun diğer bloklardaki hücrelerinden bu değeri çıkar
                        changed = changed || removeValueFromOtherBlocksInColumn(value, col: actualCol, exceptBlockRow: blockRow, board: &board)
                    }
                    
                    // Pointing Pair/Triple for Rows - Optimize edilmiş versiyon
                    if rowOccurrences.count == 1, let (blockRowIndex, count) = rowOccurrences.first, count > 0 {
                        let actualRow = blockRow * blockSize + blockRowIndex
                        // Bu değer sadece bir satırda ve bu blokta olabiliyorsa, satırın diğer bloklardaki hücrelerinden bu değeri çıkar
                        changed = changed || removeValueFromOtherBlocksInRow(value, row: actualRow, exceptBlockCol: blockCol, board: &board)
                    }
                    
                    // Pointing Pair/Triple for Columns
                    let colsWithValue = colOccurrences.filter { $0.value > 0 }
                    if colsWithValue.count == 1, let (blockColIndex, _) = colsWithValue.first {
                        let actualCol = blockCol * 3 + blockColIndex
                        // Bu değer sadece bir sütunda ve bu blokta olabiliyorsa, sütunun diğer bloklardaki hücrelerinden bu değeri çıkar
                        changed = changed || removeValueFromOtherBlocksInColumn(value, col: actualCol, exceptBlockRow: blockRow, board: &board)
                    }
                }
            }
        }
        
        return changed
    }
    
    // Bir satırın diğer bloklarındaki hücrelerden belirli bir değeri çıkar
    private func removeValueFromOtherBlocksInRow(_ value: Int, row: Int, exceptBlockCol: Int, board: inout [[Int?]]) -> Bool {
        var changed = false
        _ = row / 3 // blockRow kullanılmıyor, uyarıyı engellemek için _ kullanıyoruz
        
        for col in 0..<9 {
            let blockCol = col / 3
            if blockCol != exceptBlockCol && board[row][col] == nil {
                let possibilities = possibleValues(for: row, col: col, in: board)
                if possibilities.contains(value) {
                    // Bu hücrenin yeni olasılıkları
                    var newPossibilities = possibilities
                    newPossibilities.removeAll { $0 == value }
                    
                    // Eğer sadece bir olasılık kaldıysa, o değeri yerleştir
                    if newPossibilities.count == 1 {
                        board[row][col] = newPossibilities.first
                        changed = true
                    }
                }
            }
        }
        
        return changed
    }
    
    // Bir sütunun diğer bloklarındaki hücrelerden belirli bir değeri çıkar
    private func removeValueFromOtherBlocksInColumn(_ value: Int, col: Int, exceptBlockRow: Int, board: inout [[Int?]]) -> Bool {
        var changed = false
        _ = col / 3 // blockCol kullanılmıyor, uyarıyı engellemek için _ kullanıyoruz
        
        for row in 0..<9 {
            let blockRow = row / 3
            if blockRow != exceptBlockRow && board[row][col] == nil {
                let possibilities = possibleValues(for: row, col: col, in: board)
                if possibilities.contains(value) {
                    // Bu hücrenin yeni olasılıkları
                    var newPossibilities = possibilities
                    newPossibilities.removeAll { $0 == value }
                    
                    // Eğer sadece bir olasılık kaldıysa, o değeri yerleştir
                    if newPossibilities.count == 1 {
                        board[row][col] = newPossibilities.first
                        changed = true
                    }
                }
            }
        }
        
        return changed
    }
    
    // Tahtanın geçerli olup olmadığını kontrol et (çelişki var mı)
    private func isBoardValid(_ board: [[Int?]]) -> Bool {
        // Satır kontrolü
        for row in 0..<9 {
            var seen = Set<Int>()
            for col in 0..<9 {
                if let value = board[row][col] {
                    if seen.contains(value) {
                        return false
                    }
                    seen.insert(value)
                }
            }
        }
        
        // Sütun kontrolü
        for col in 0..<9 {
            var seen = Set<Int>()
            for row in 0..<9 {
                if let value = board[row][col] {
                    if seen.contains(value) {
                        return false
                    }
                    seen.insert(value)
                }
            }
        }
        
        // 3x3 blok kontrolü
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                var seen = Set<Int>()
                for r in 0..<3 {
                    for c in 0..<3 {
                        let row = blockRow * 3 + r
                        let col = blockCol * 3 + c
                        if let value = board[row][col] {
                            if seen.contains(value) {
                                return false
                            }
                            seen.insert(value)
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    // Tahtanın tamamen doldurulup doldurulmadığını kontrol et
    private func isCompleteSolution(_ board: [[Int?]]) -> Bool {
        // Tüm hücrelerin dolu olduğunu kontrol et
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == nil {
                    return false
                }
            }
        }
        
        // Genel geçerlilik kontrolü
        return isBoardValid(board)
    }
    
    // Belirli bir hücre için olası değerleri bul
    private func possibleValues(for row: Int, col: Int, in board: [[Int?]]) -> [Int] {
        // Hücre zaten dolu ise, boş liste döndür
        if board[row][col] != nil {
            return []
        }
        
        // Tüm olası değerler
        var possibleNumbers = Array(1...9)
        
        // Satır kontrolü
        for c in 0..<9 {
            if let value = board[row][c], value > 0, let index = possibleNumbers.firstIndex(of: value) {
                possibleNumbers.remove(at: index)
            }
        }
        
        // Sütun kontrolü
        for r in 0..<9 {
            if let value = board[r][col], value > 0, let index = possibleNumbers.firstIndex(of: value) {
                possibleNumbers.remove(at: index)
            }
        }
        
        // Kutu (3x3 blok) kontrolü
        let boxRow = row - row % 3
        let boxCol = col - col % 3
        
        for r in boxRow..<boxRow+3 {
            for c in boxCol..<boxCol+3 {
                if let value = board[r][c], value > 0, let index = possibleNumbers.firstIndex(of: value) {
                    possibleNumbers.remove(at: index)
                }
            }
        }
        
        return possibleNumbers
    }
    
    // Belirli bir birimde (satır, sütun, blok) hidden single sayısını hesapla
    private func countHiddenSinglesInUnit(unit: [(Int, Int)]) -> Int {
        var count = 0
        var unitEmptyCells = [(Int, Int)]()
        
        // Önce birimin boş hücrelerini belirle - daha az işlem yapma
        for (row, col) in unit {
            if board[row][col] == nil {
                unitEmptyCells.append((row, col))
            }
        }
        
        // Boş hücre yoksa zaman kaybetme
        if unitEmptyCells.isEmpty {
            return 0
        }
        
        // Daha verimli olarak her değer için hidden single kontrolü yap
        for value in 1...9 {
            // Bu birim için bu değerin yerleştirilebileceği hücreler
            var possibleCells = [(Int, Int)]()
            
            // Maksimum 2 hücre kontrolü gerektir, 3 veya daha fazla olursa hidden single değildir
            for (row, col) in unitEmptyCells {
                if isValidPlacement(row: row, column: col, value: value) {
                    possibleCells.append((row, col))
                    
                    // 2'den fazla olursa gereksiz işlemi durdur
                    if possibleCells.count > 2 {
                        break
                    }
                }
            }
            
            // Eğer değer sadece bir hücreye yerleştirilebiliyorsa ve bu hücre naked single değilse,
            // bu bir hidden single'dır
            if possibleCells.count == 1 {
                let (row, col) = possibleCells[0]
                let allPossibleValues = getPossibleValues(row: row, column: col)
                if allPossibleValues.count > 1 {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    // Kullanıcı için tahtanın açıklamasını dışa aktar
    func boardDescription() -> String {
        var description = "Sudoku Tahtası (Zorluk: \(difficulty.rawValue))\n"
        
        for row in 0..<9 {
            if row % 3 == 0 && row != 0 {
                description += "------+-------+------\n"
            }
            
            for col in 0..<9 {
                if col % 3 == 0 && col != 0 {
                    description += "| "
                }
                
                if let value = board[row][col] {
                    description += "\(value) "
                } else {
                    description += "· "
                }
            }
            
            description += "\n"
        }
        
        return description
    }
    
    // MARK: - Hücre işlemleri (dışarıdan erişim için)
    
    // Bir hücredeki değeri ayarla
    func setValue(_ value: Int?, atRow row: Int, column: Int) {
        guard isValidIndex(row: row, column: column) && !isOriginalValue(row: row, column: column) else { return }
        
        // Önbellekleri temizle, çünkü tahta değişecek
        invalidateCaches()
        
        board[row][column] = value
    }
    
    // MARK: - Zorluk testi yardımcı metodları
    
    // Bir hücredeki değerleri kontrol ederek olası değerleri hesapla
    private func getPossibleNumbersForCell(row: Int, col: Int) -> [Int] {
        var possibleNumbers = [Int]()
        
        for num in 1...9 {
            if isValidPlacement(row: row, column: col, value: num) {
                possibleNumbers.append(num)
            }
        }
        
        return possibleNumbers
    }
    
    // İpucu dağılımını kontrol eden fonksiyon
    private func validateIpucuDagilimi() -> Bool {
        // Her 3x3 bloğunda minimum ipucu zorunluluğu
        let minBlockClues: Int
        
        // Zorluk seviyesine göre minimum blok ipucu sayısını belirle
        switch difficulty {
        case .easy:
            minBlockClues = 3 // Kolay için 3 ipucu
        case .medium:
            minBlockClues = 2 // Orta için 2 ipucu
        case .hard, .expert:
            minBlockClues = 2 // Zor ve uzman için 2 ipucu
        }
        
        // Her 3x3 bloğunda en az minBlockClues ipucu olmasını kontrol et
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                var ipucuSayisi = 0
                for r in 0..<3 {
                    for c in 0..<3 {
                        let row = blockRow * 3 + r
                        let col = blockCol * 3 + c
                        if board[row][col] != nil {
                            ipucuSayisi += 1
                        }
                    }
                }
                // Blokta en az minBlockClues ipucu yoksa false dön
                if ipucuSayisi < minBlockClues {
                    return false
                }
            }
        }
        
        // Satır ve sütunlardaki minimum ipucu zorunluluğu
        let minRowColClues: Int
        
        // Zorluk seviyesine göre minimum satır/sütun ipucu sayısını belirle
        switch difficulty {
        case .easy:
            minRowColClues = 2 // Kolay için 2 ipucu
        case .medium, .hard, .expert:
            minRowColClues = 1 // Diğer seviyeler için 1 ipucu yeterli
        }
        
        // Satır ve sütunlarda da minimum ipucu sayısını kontrol et
        for i in 0..<9 {
            var satirIpucu = 0
            var sutunIpucu = 0
            for j in 0..<9 {
                if board[i][j] != nil {
                    satirIpucu += 1
                }
                if board[j][i] != nil {
                    sutunIpucu += 1
                }
            }
            // Her satır ve sütunda en az minRowColClues ipucu olmalı
            if satirIpucu < minRowColClues || sutunIpucu < minRowColClues {
                return false
            }
        }
        
        return true
    }
    
    // Mantıksal çözülebilirlik test fonksiyonu
    private func testLogicalSolvability() -> Bool {
        // Tahtanın kopyasını oluştur
        var boardCopy = [[Int?]](repeating: [Int?](repeating: nil, count: 9), count: 9)
        for row in 0..<9 {
            for col in 0..<9 {
                boardCopy[row][col] = board[row][col]
            }
        }
        
        // Olası değerleri içeren bir yapı tanımla
        var possibleValues = [[[Bool]]](repeating: [[Bool]](repeating: [Bool](repeating: true, count: 9), count: 9), count: 9)
        
        // Mevcut değerleri temel alarak olası değerleri başlat
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = boardCopy[row][col] {
                    for i in 0..<9 {
                        possibleValues[row][i][value-1] = false
                        possibleValues[i][col][value-1] = false
                    }
                    let blockRow = (row / 3) * 3
                    let blockCol = (col / 3) * 3
                    for r in 0..<3 {
                        for c in 0..<3 {
                            possibleValues[blockRow + r][blockCol + c][value-1] = false
                        }
                    }
                    possibleValues[row][col] = [Bool](repeating: false, count: 9)
                    possibleValues[row][col][value-1] = true
                }
            }
        }
        
        var changed = true
        var iterationCount = 0
        let maxIterations = 100 // Sonsuz döngüden kaçınmak için
        
        // Tekniklerin kullanımını takip et
        var usedNakedPairs = false
        var usedPointingPairs = false
        var usedBoxLineReduction = false
        var usedXWing = false
        
        while changed && iterationCount < maxIterations {
            changed = false
            iterationCount += 1
            
            // Naked Singles tekniği
            for row in 0..<9 {
                for col in 0..<9 {
                    if boardCopy[row][col] == nil {
                        var candidates = [Int]()
                        for val in 0..<9 {
                            if possibleValues[row][col][val] {
                                candidates.append(val + 1)
                            }
                        }
                        
                        if candidates.count == 1 {
                            boardCopy[row][col] = candidates[0]
                            changed = true
                            
                            // Değerleri güncelle
                            let value = candidates[0]
                            for i in 0..<9 {
                                if i != col {
                                    possibleValues[row][i][value-1] = false
                                }
                                if i != row {
                                    possibleValues[i][col][value-1] = false
                                }
                            }
                            
                            let blockRow = (row / 3) * 3
                            let blockCol = (col / 3) * 3
                            for r in 0..<3 {
                                for c in 0..<3 {
                                    if blockRow + r != row || blockCol + c != col {
                                        possibleValues[blockRow + r][blockCol + c][value-1] = false
                                    }
                                }
                            }
                            
                            possibleValues[row][col] = [Bool](repeating: false, count: 9)
                            possibleValues[row][col][value-1] = true
                        }
                    }
                }
            }
            
            // Hidden Singles tekniği (satırlar için)
            for row in 0..<9 {
                for val in 0..<9 {
                    var count = 0
                    var lastCol = -1
                    
                    for col in 0..<9 {
                        if boardCopy[row][col] == nil && possibleValues[row][col][val] {
                            count += 1
                            lastCol = col
                        }
                    }
                    
                    if count == 1 && lastCol != -1 {
                        boardCopy[row][lastCol] = val + 1
                        changed = true
                        
                        // Değerleri güncelle
                        for i in 0..<9 {
                            if i != val {
                                possibleValues[row][lastCol][i] = false
                            }
                        }
                        
                        for i in 0..<9 {
                            if i != row {
                                possibleValues[i][lastCol][val] = false
                            }
                        }
                        
                        let blockRow = (row / 3) * 3
                        let blockCol = (lastCol / 3) * 3
                        for r in 0..<3 {
                            for c in 0..<3 {
                                if blockRow + r != row || blockCol + c != lastCol {
                                    possibleValues[blockRow + r][blockCol + c][val] = false
                                }
                            }
                        }
                    }
                }
            }
            
            // Hidden Singles tekniği (sütunlar için)
            for col in 0..<9 {
                for val in 0..<9 {
                    var count = 0
                    var lastRow = -1
                    
                    for row in 0..<9 {
                        if boardCopy[row][col] == nil && possibleValues[row][col][val] {
                            count += 1
                            lastRow = row
                        }
                    }
                    
                    if count == 1 && lastRow != -1 {
                        boardCopy[lastRow][col] = val + 1
                        changed = true
                        
                        // Değerleri güncelle
                        for i in 0..<9 {
                            if i != val {
                                possibleValues[lastRow][col][i] = false
                            }
                        }
                        
                        for i in 0..<9 {
                            if i != col {
                                possibleValues[lastRow][i][val] = false
                            }
                        }
                        
                        let blockRow = (lastRow / 3) * 3
                        let blockCol = (col / 3) * 3
                        for r in 0..<3 {
                            for c in 0..<3 {
                                if blockRow + r != lastRow || blockCol + c != col {
                                    possibleValues[blockRow + r][blockCol + c][val] = false
                                }
                            }
                        }
                    }
                }
            }
            
            // Hidden Singles tekniği (bloklar için)
            for blockRow in 0..<3 {
                for blockCol in 0..<3 {
                    for val in 0..<9 {
                        var count = 0
                        var lastRow = -1
                        var lastCol = -1
                        
                        for r in 0..<3 {
                            for c in 0..<3 {
                                let row = blockRow * 3 + r
                                let col = blockCol * 3 + c
                                if boardCopy[row][col] == nil && possibleValues[row][col][val] {
                                    count += 1
                                    lastRow = row
                                    lastCol = col
                                }
                            }
                        }
                        
                        if count == 1 && lastRow != -1 && lastCol != -1 {
                            boardCopy[lastRow][lastCol] = val + 1
                            changed = true
                            
                            // Değerleri güncelle
                            for i in 0..<9 {
                                if i != val {
                                    possibleValues[lastRow][lastCol][i] = false
                                }
                            }
                            
                            for i in 0..<9 {
                                if i != lastCol {
                                    possibleValues[lastRow][i][val] = false
                                }
                                if i != lastRow {
                                    possibleValues[i][lastCol][val] = false
                                }
                            }
                        }
                    }
                }
            }
            
            // Naked Pairs tekniği (Orta seviye için)
            if difficulty == .medium || difficulty == .hard || difficulty == .expert {
                let nakedPairsChanged = findNakedPairs(&possibleValues)
                changed = changed || nakedPairsChanged
                if nakedPairsChanged {
                    usedNakedPairs = true
                }
            }
            
            // Pointing Pairs tekniği (Zor seviye için)
            if difficulty == .hard || difficulty == .expert {
                let pointingPairsChanged = findPointingPairs(&possibleValues)
                changed = changed || pointingPairsChanged
                if pointingPairsChanged {
                    usedPointingPairs = true
                }
                
                // Box-Line Reduction tekniği (Zor seviye için)
                let boxLineReductionChanged = findBoxLineReduction(&possibleValues)
                changed = changed || boxLineReductionChanged
                if boxLineReductionChanged {
                    usedBoxLineReduction = true
                }
                
                // X-Wing tekniği (Zor seviye için)
                let xWingChanged = findXWing(&possibleValues)
                changed = changed || xWingChanged
                if xWingChanged {
                    usedXWing = true
                }
            }
        }
        
        // Kullanılan teknikleri kaydet
        if difficulty == .medium {
            nakedPairsUsedCache = usedNakedPairs
        }
        else if difficulty == .hard {
            nakedPairsUsedCache = usedNakedPairs
            pointingPairsUsedCache = usedPointingPairs
            boxLineReductionUsedCache = usedBoxLineReduction
            xWingUsedCache = usedXWing
        }
        
        // Tüm hücreler dolu mu kontrol et
        for row in 0..<9 {
            for col in 0..<9 {
                if boardCopy[row][col] == nil {
                    return false // Mantıksal tekniklerle tam çözülemedi
                }
            }
        }
        
        return true // Mantıksal tekniklerle çözülebildi
    }
    
    // Birimi temsil etmek için enum (satır, sütun, blok)
    private enum UnitType {
        case row, column, block
    }
    
    // Naked Pair tekniği ile olası değerleri elimine et
    private func findNakedPairs(_ possibleValues: inout [[[Bool]]]) -> Bool {
        var changed = false
        
        // Satırlarda Naked Pair ara
        for row in 0..<9 {
            changed = changed || findNakedPairsInUnit(possibleValues: &possibleValues, unitType: .row, unitIndex: row)
        }
        
        // Sütunlarda Naked Pair ara
        for col in 0..<9 {
            changed = changed || findNakedPairsInUnit(possibleValues: &possibleValues, unitType: .column, unitIndex: col)
        }
        
        // Bloklarda Naked Pair ara
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                changed = changed || findNakedPairsInUnit(possibleValues: &possibleValues, unitType: .block, unitIndex: blockRow * 3 + blockCol)
            }
        }
        
        return changed
    }
    
    // Belirli bir birimdeki Naked Pair'leri bul
    private func findNakedPairsInUnit(possibleValues: inout [[[Bool]]], unitType: UnitType, unitIndex: Int) -> Bool {
        var changed = false
        
        // Birim içindeki hücreleri topla
        var cells = [(row: Int, col: Int)]()
        switch unitType {
        case .row:
            for col in 0..<9 {
                cells.append((row: unitIndex, col: col))
            }
        case .column:
            for row in 0..<9 {
                cells.append((row: row, col: unitIndex))
            }
        case .block:
            let blockRow = unitIndex / 3
            let blockCol = unitIndex % 3
            for r in 0..<3 {
                for c in 0..<3 {
                    cells.append((row: blockRow * 3 + r, col: blockCol * 3 + c))
                }
            }
        }
        
        // Tüm olası hücre çiftlerini kontrol et
        for i in 0..<cells.count {
            for j in (i+1)..<cells.count {
                let cell1 = cells[i]
                let cell2 = cells[j]
                
                // Her iki hücredeki olası değerleri bul
                var candidates1 = [Int]()
                var candidates2 = [Int]()
                
                for val in 0..<9 {
                    if possibleValues[cell1.row][cell1.col][val] {
                        candidates1.append(val)
                    }
                    if possibleValues[cell2.row][cell2.col][val] {
                        candidates2.append(val)
                    }
                }
                
                // İki hücrede tam olarak aynı iki değer varsa
                if candidates1.count == 2 && candidates2.count == 2 && 
                   candidates1 == candidates2 {
                    
                    // Diğer hücrelerdeki bu değerleri elimine et
                    for k in 0..<cells.count {
                        if k != i && k != j {
                            let cell = cells[k]
                            for val in candidates1 {
                                if possibleValues[cell.row][cell.col][val] {
                                    possibleValues[cell.row][cell.col][val] = false
                                    changed = true
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return changed
    }
    
    // Pointing Pair/Triple tekniği - bir bloktaki bir değer sadece bir satır veya sütunda olabiliyorsa,
    // o satır/sütunun blok dışındaki hücrelerinden bu değeri elimine eder
    private func findPointingPairs(_ possibleValues: inout [[[Bool]]]) -> Bool {
        var changed = false
        
        // Her bir 3x3 blok için kontrol et
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                // 1'den 9'a kadar her değer için
                for value in 0..<9 {
                    // Bu bloktaki bu değerin olası konumlarını bul
                    var possibleRowPositions = Set<Int>()
                    var possibleColPositions = Set<Int>()
                    
                    for r in 0..<3 {
                        for c in 0..<3 {
                            let row = blockRow * 3 + r
                            let col = blockCol * 3 + c
                            
                            if possibleValues[row][col][value] {
                                possibleRowPositions.insert(r)
                                possibleColPositions.insert(c)
                            }
                        }
                    }
                    
                    // Değer sadece bir satırda mı?
                    if possibleRowPositions.count == 1, let r = possibleRowPositions.first {
                        let row = blockRow * 3 + r
                        
                        // Bu satırın blok dışındaki kısmında değeri elimine et
                        for c in 0..<9 {
                            let blockOfCol = c / 3
                            
                            // Sadece blok dışındaki sütunlarda değişiklik yap
                            if blockOfCol != blockCol && possibleValues[row][c][value] {
                                possibleValues[row][c][value] = false
                                changed = true
                            }
                        }
                    }
                    
                    // Değer sadece bir sütunda mı?
                    if possibleColPositions.count == 1, let c = possibleColPositions.first {
                        let col = blockCol * 3 + c
                        
                        // Bu sütunun blok dışındaki kısmında değeri elimine et
                        for r in 0..<9 {
                            let blockOfRow = r / 3
                            
                            // Sadece blok dışındaki satırlarda değişiklik yap
                            if blockOfRow != blockRow && possibleValues[r][col][value] {
                                possibleValues[r][col][value] = false
                                changed = true
                            }
                        }
                    }
                }
            }
        }
        
        return changed
    }
    
    // Box-Line Reduction tekniği - bir satır/sütunda bir değer sadece bir blokta olabiliyorsa,
    // o bloğun satır/sütun dışındaki hücrelerinden bu değeri elimine eder
    private func findBoxLineReduction(_ possibleValues: inout [[[Bool]]]) -> Bool {
        var changed = false
        
        // Satırlarda kontrolü yap
        for row in 0..<9 {
            // 1'den 9'a kadar her değer için
            for value in 0..<9 {
                // Bu satırdaki bu değerin olası konumlarını bul
                var possibleBlockCols = Set<Int>()
                
                for col in 0..<9 {
                    if possibleValues[row][col][value] {
                        possibleBlockCols.insert(col / 3)
                    }
                }
                
                // Değer sadece bir blokta mı?
                if possibleBlockCols.count == 1, let blockCol = possibleBlockCols.first {
                    let blockRow = row / 3
                    
                    // Bu bloğun, bu satır dışındaki kısmında değeri elimine et
                    for r in blockRow * 3..<blockRow * 3 + 3 {
                        // Sadece farklı satırlarda
                        if r != row {
                            for c in blockCol * 3..<blockCol * 3 + 3 {
                                if possibleValues[r][c][value] {
                                    possibleValues[r][c][value] = false
                                    changed = true
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Sütunlarda kontrolü yap
        for col in 0..<9 {
            // 1'den 9'a kadar her değer için
            for value in 0..<9 {
                // Bu sütundaki bu değerin olası konumlarını bul
                var possibleBlockRows = Set<Int>()
                
                for row in 0..<9 {
                    if possibleValues[row][col][value] {
                        possibleBlockRows.insert(row / 3)
                    }
                }
                
                // Değer sadece bir blokta mı?
                if possibleBlockRows.count == 1, let blockRow = possibleBlockRows.first {
                    let blockCol = col / 3
                    
                    // Bu bloğun, bu sütun dışındaki kısmında değeri elimine et
                    for c in blockCol * 3..<blockCol * 3 + 3 {
                        // Sadece farklı sütunlarda
                        if c != col {
                            for r in blockRow * 3..<blockRow * 3 + 3 {
                                if possibleValues[r][c][value] {
                                    possibleValues[r][c][value] = false
                                    changed = true
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return changed
    }
    
    // X-Wing tekniği - iki satırda bir değer sadece aynı iki sütunda olabiliyorsa, 
    // diğer satırlardaki bu sütunlardan bu değeri elimine eder.
    // Benzer şekilde iki sütunda bir değer sadece aynı iki satırda olabiliyorsa,
    // diğer sütunlardaki bu satırlardan bu değeri elimine eder.
    private func findXWing(_ possibleValues: inout [[[Bool]]]) -> Bool {
        var changed = false
        
        // Satırları kontrol et
        for value in 0..<9 {
            for row1 in 0..<8 {
                // Bu satırda bu değerin olası sütunlarını bul
                var cols1 = [Int]()
                for col in 0..<9 {
                    if possibleValues[row1][col][value] {
                        cols1.append(col)
                    }
                }
                
                // Sadece 2 olası sütun bulunduysa devam et
                if cols1.count == 2 {
                    for row2 in (row1+1)..<9 {
                        // İkinci satırda bu değerin olası sütunlarını bul
                        var cols2 = [Int]()
                        for col in 0..<9 {
                            if possibleValues[row2][col][value] {
                                cols2.append(col)
                            }
                        }
                        
                        // İkinci satırda da aynı 2 sütun bulundu mu?
                        if cols2.count == 2 && cols1 == cols2 {
                            // X-Wing bulundu! Diğer satırlardaki bu sütunlardan değeri elimine et
                            for row in 0..<9 {
                                if row != row1 && row != row2 {
                                    for col in cols1 {
                                        if possibleValues[row][col][value] {
                                            possibleValues[row][col][value] = false
                                            changed = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Sütunları kontrol et
        for value in 0..<9 {
            for col1 in 0..<8 {
                // Bu sütunda bu değerin olası satırlarını bul
                var rows1 = [Int]()
                for row in 0..<9 {
                    if possibleValues[row][col1][value] {
                        rows1.append(row)
                    }
                }
                
                // Sadece 2 olası satır bulunduysa devam et
                if rows1.count == 2 {
                    for col2 in (col1+1)..<9 {
                        // İkinci sütunda bu değerin olası satırlarını bul
                        var rows2 = [Int]()
                        for row in 0..<9 {
                            if possibleValues[row][col2][value] {
                                rows2.append(row)
                            }
                        }
                        
                        // İkinci sütunda da aynı 2 satır bulundu mu?
                        if rows2.count == 2 && rows1 == rows2 {
                            // X-Wing bulundu! Diğer sütunlardaki bu satırlardan değeri elimine et
                            for col in 0..<9 {
                                if col != col1 && col != col2 {
                                    for row in rows1 {
                                        if possibleValues[row][col][value] {
                                            possibleValues[row][col][value] = false
                                            changed = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return changed
    }
}
