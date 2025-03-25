import Foundation

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
            return self.rawValue
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
            case .easy: return 36...40
            case .medium: return 29...35
            case .hard: return 25...28
            case .expert: return 17...24
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
    private var validPlacementCache: [String: Bool] = [:]
    
    // Zorluk
    let difficulty: Difficulty
    
    // İpucu olarak verilen, değiştirilemeyen hücreleri belirten matris
    private var fixed: [[Bool]]
    
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
            print("⚠️ SudokuBoard.getOriginalValue: Geçersiz indeks: (\(row), \(col))")
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
        if let cached = validPlacementCache[cacheKey] {
            return cached
        }
        
        // Satır kontrolü
        for col in 0..<9 {
            if col != column, board[row][col] == value {
                validPlacementCache[cacheKey] = false
                return false
            }
        }
        
        // Sütun kontrolü
        for r in 0..<9 {
            if r != row, board[r][column] == value {
                validPlacementCache[cacheKey] = false
                return false
            }
        }
        
        // 3x3 blok kontrolü
        let blockRow = (row / 3) * 3
        let blockCol = (column / 3) * 3
        
        for r in blockRow..<(blockRow + 3) {
            for col in blockCol..<(blockCol + 3) {
                if r != row || col != column, board[r][col] == value {
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
        completeCheckCache = nil
        filledCheckCache = nil
        validPlacementCache.removeAll(keepingCapacity: true)
    }
    
    // MARK: - Yardımcı Metodlar
    
    // İndekslerin geçerli olup olmadığını kontrol et
    private func isValidIndex(row: Int, column: Int) -> Bool {
        return row >= 0 && row < 9 && column >= 0 && column < 9
    }
    
    // MARK: - Tahta Oluşturma
    
    // Sudoku tahtası oluştur
    private func generateBoard() {
        print("Tahta oluşturuluyor...")
        
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
        print("Çözüm oluşturuldu")
        
        // Çözümü kontrol et
        var solutionHasNils = false
        for row in 0..<9 {
            for col in 0..<9 {
                if solution[row][col] == nil {
                    solutionHasNils = true
                    print("HATA: Çözümde nil değer var: [\(row)][\(col)]")
                }
            }
        }
        
        if solutionHasNils {
            print("Çözümde nil değerler var, tekrar deneniyor...")
            return generateBoard() // Çözüm geçersizse tekrar dene
        }
        
        // Gösterilecek ipucu sayısını belirle
        let cluesToShow = getCluesToShow()
        print("Gösterilecek ipucu sayısı: \(cluesToShow)")
        let cellsToRemove = 81 - cluesToShow
        
        // Önce çözümü tahtaya kopyalayıp ardından hücre kaldır
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = solution[row][col] {
                    board[row][col] = value
                } else {
                    print("HATA: Çözümde [\(row)][\(col)] nil!")
                }
            }
        }
        
        // Kaldırılacak hücreleri belirle ve kaldır
        removeRandomCells(count: cellsToRemove)
        
        // Oluşan ipucu sayısını kontrol et
        var clueCount = 0
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] != nil {
                    clueCount += 1
                }
            }
        }
        print("Oluşturulan ipucu sayısı: \(clueCount)")
        
        // Eğer hiç ipucu yoksa veya çok az ipucu varsa tekrar dene
        if clueCount < 10 || clueCount < cluesToShow - 10 {
            print("Çok az ipucu var (\(clueCount)), tekrar deneniyor...")
            return generateBoard()
        }
        
        // Başlangıçta görünen hücreleri sabit olarak işaretle
        markFixedCells()
        
        // Önbellekleri temizle
        invalidateCaches()
    }
    
    // Çözümü oluştur
    private func generateSolution() {
        // Doğrudan hızlı ve garantili yöntemi kullan
        print("Hızlı çözüm yöntemi kullanılıyor...")
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
        
        // Bilinen çalışan bir yöntem kullan: 3x3 bloklar içinde sayıları kaydır
        let basePattern = [
            [1, 2, 3, 4, 5, 6, 7, 8, 9],
            [4, 5, 6, 7, 8, 9, 1, 2, 3],
            [7, 8, 9, 1, 2, 3, 4, 5, 6],
            [2, 3, 4, 5, 6, 7, 8, 9, 1],
            [5, 6, 7, 8, 9, 1, 2, 3, 4],
            [8, 9, 1, 2, 3, 4, 5, 6, 7],
            [3, 4, 5, 6, 7, 8, 9, 1, 2],
            [6, 7, 8, 9, 1, 2, 3, 4, 5],
            [9, 1, 2, 3, 4, 5, 6, 7, 8]
        ]
        
        // Temel deseni tahtaya kopyala
        for row in 0..<9 {
            for col in 0..<9 {
                board[row][col] = basePattern[row][col]
                solution[row][col] = basePattern[row][col]
            }
        }
        
        // Değerleri karıştır - sayı eşleştirmelerini değiştir, yapıyı korur
        shuffleSolution()
        
        // Ek olarak satırları ve sütunları blok içinde karıştır
        shuffleRowsAndColumns()
    }
    
    // Çözümü rastgele karıştır (geçerliliği koruyarak)
    private func shuffleSolution() {
        // Değer değişimleri (1-9 arası değerleri birbirleriyle değiştir)w
        var valueMap = Array(1...9)
        valueMap.shuffle()
        valueMap.insert(0, at: 0) // 0 indeksini kullanmak için
        
        // Tüm hücrelerdeki değerleri eşlenik değerleriyle değiştir
        for row in 0..<9 {
            for col in 0..<9 {
                if let value = solution[row][col] {
                    solution[row][col] = valueMap[value]
                    board[row][col] = valueMap[value]
                }
            }
        }
    }
    
    // Satırları ve sütunları bloklar içinde karıştır (geçerliliği koruyarak)
    private func shuffleRowsAndColumns() {
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
        
        // Blokların kendilerini de karıştır
        // Önce satır bloklarını karıştır
        let rowBlockOrder = [0, 1, 2].shuffled()
        for i in 0..<3 {
            if i != rowBlockOrder[i] {
                swapRowBlocks(i, rowBlockOrder[i])
            }
        }
        
        // Sonra sütun bloklarını karıştır
        let colBlockOrder = [0, 1, 2].shuffled()
        for i in 0..<3 {
            if i != colBlockOrder[i] {
                swapColumnBlocks(i, colBlockOrder[i])
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
    
    // İki sütun bloğunu takas et (her biri 3 sütundan oluşur)
    private func swapColumnBlocks(_ block1: Int, _ block2: Int) {
        guard block1 != block2 else { return }
        
        let col1 = block1 * 3
        let col2 = block2 * 3
        
        // Her blokta 3 sütun var
        for i in 0..<3 {
            swapColumns(col1 + i, col2 + i)
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
    private func getPossibleValues(row: Int, column: Int) -> [Int] {
        var possibleValues = [Int]()
        
        for value in 1...9 {
            if isValidPlacement(row: row, column: column, value: value) {
        
                possibleValues.append(value)
            }
        }
        
        return possibleValues
    }
    
    // Tahtayı çöz (geri izleme algoritması)
    private func solveSudoku() -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == nil {
                    // Rastgele sıralanmış değerleri dene
                    let values = Array(1...9).shuffled()
                    
                    for value in values {
                        if isValidPlacement(row: row, column: col, value: value) {
                            board[row][col] = value
                            
                            if solveSudoku() {
                                return true
                            }
                            
                            board[row][col] = nil
                        }
                    }
                    
                    return false
                }
            }
        }
        
        return true
    }
    
    // Rastgele hücreleri kaldır
    private func removeRandomCells(count: Int) {
        // Önce tahtayı orijinal tahtaya kopyala
        for row in 0..<9 {
            for col in 0..<9 {
                originalBoard[row][col] = board[row][col]
            }
        }
        
        // Stratejik kaldırma için tüm hücreleri kategorize et
        // 1. 3x3 blokların köşeleri (4'er hücre)
        // 2. 3x3 blokların kenarları (12 hücre)
        // 3. 3x3 blokların merkezleri (1'er hücre)
        // 4. Diğer hücreler (remaining)
        
        var cornerCells = [(Int, Int)]() // 3x3 blok köşeleri
        var edgeCells = [(Int, Int)]() // 3x3 bloğun kenar hücreleri
        var centerCells = [(Int, Int)]() // 3x3 bloğun merkez hücreleri
        var otherCells = [(Int, Int)]() // Diğer hücreler
        
        for row in 0..<9 {
            for col in 0..<9 {
                let inBlockRow = row % 3
                let inBlockCol = col % 3
                
                if (inBlockRow == 0 || inBlockRow == 2) && (inBlockCol == 0 || inBlockCol == 2) {
                    // Köşe hücre
                    cornerCells.append((row, col))
                } else if inBlockRow == 1 && inBlockCol == 1 {
                    // Merkez hücre
                    centerCells.append((row, col))
                } else if inBlockRow == 1 || inBlockCol == 1 {
                    // Kenar hücre
                    edgeCells.append((row, col))
                } else {
                    // Diğer hücreler
                    otherCells.append((row, col))
                }
            }
        }
        
        // Hücreleri karıştır
        cornerCells.shuffle()
        edgeCells.shuffle()
        centerCells.shuffle()
        otherCells.shuffle()
        
        // Blok başına kalan hücre sayısını takip et
        var cellsRemainingInBlock = Array(repeating: Array(repeating: 9, count: 3), count: 3)
        
        // Her blokta en az bu kadar hücre kalsın (zorluk derecesine göre değişir)
        let minPerBlock: Int
        switch difficulty {
        case .easy:
            minPerBlock = 3 // Kolay seviyede her blokta en az 3 hücre
        case .medium:
            minPerBlock = 2 // Orta seviyede her blokta en az 2 hücre
        case .hard:
            minPerBlock = 2 // Zor seviyede her blokta en az 2 hücre
        case .expert:
            minPerBlock = 1 // Uzman seviyede her blokta en az 1 hücre
        }
        
        // Tüm hücreleri tek bir listede birleştir ve karıştır
        // Bu sayede daha dengeli bir dağılım sağlayabiliriz
        var allCells = cornerCells + edgeCells + centerCells + otherCells
        allCells.shuffle()
        
        var removed = 0
        
        // Birinci aşama: Blok kısıtlamalarını kontrol ederek hücreleri kaldır
        let cellsToRemoveInPhase1 = Int(Double(count) * 0.7) // İlk aşamada %70'ini kaldır
        
        for i in 0..<allCells.count {
            if removed >= cellsToRemoveInPhase1 {
                break
            }
            
            let (row, col) = allCells[i]
            let blockRow = row / 3
            let blockCol = col / 3
            
            // Bu bloktaki hücre sayısını kontrol et
            if cellsRemainingInBlock[blockRow][blockCol] <= minPerBlock {
                // Bu blokta yeterince az hücre kaldı, bu hücreyi koruyalım
                continue
            }
            
            // Hücreyi kaldır
            board[row][col] = nil
            cellsRemainingInBlock[blockRow][blockCol] -= 1
            removed += 1
        }
        
        // İkinci aşama: Kalan hücreleri rastgele kaldır (kısıtlamaları biraz gevşeterek)
        if removed < count {
            // Kalan hücreleri al
            var remainingCells = [(Int, Int)]()
            for row in 0..<9 {
                for col in 0..<9 {
                    if board[row][col] != nil {
                        remainingCells.append((row, col))
                    }
                }
            }
            remainingCells.shuffle()
            
            // Çok katı olmayan bir ikinci aşama
            for (row, col) in remainingCells {
                let blockRow = row / 3
                let blockCol = col / 3
                
                // Kritik kısıtlama: Her blokta en az 1 hücre kalsın
                if cellsRemainingInBlock[blockRow][blockCol] <= 1 {
                    continue
                }
                
                board[row][col] = nil
                cellsRemainingInBlock[blockRow][blockCol] -= 1
                removed += 1
                
                if removed >= count {
                    break
                }
            }
        }
        
        // Son kontrolü yap - hedeflenen ipucu sayısına yaklaştık mı?
        // Eğer çok fazla farklı olursa yeni tahta oluşturmak daha iyi olabilir
        let clues = 81 - removed
        let targetClues = getCluesToShow()
        
        if abs(clues - targetClues) > targetClues / 4 {
            // Eğer ipucu sayısı hedeften çok sapıyorsa yeni tahta oluştur
            generateSolution()
            removeRandomCells(count: 81 - targetClues)
        }
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
                
                print("Yeni format tespit edildi")
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
                print("Eski format tespit edildi")
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
        print("Format anlaşılabilir değil, kaydedilmiş verileri siliyor olabilirsiniz")
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
            if applyPointingPairs(&boardCopy) {
                changed = true
            }
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
    private func applyPointingPairs(_ board: inout [[Int?]]) -> Bool {
        var changed = false
        
        // Her 3x3 blok için
        for blockRow in 0..<3 {
            for blockCol in 0..<3 {
                // Her olası değer için
                for value in 1...9 {
                    // Bu değerin bu blokta hangi satırlarda ve sütunlarda olabileceğini bul
                    var rowOccurrences = [Int: Int]()
                    var colOccurrences = [Int: Int]()
                    
                    for r in 0..<3 {
                        for c in 0..<3 {
                            let row = blockRow * 3 + r
                            let col = blockCol * 3 + c
                            
                            if board[row][col] == nil && possibleValues(for: row, col: col, in: board).contains(value) {
                                rowOccurrences[r, default: 0] += 1
                                colOccurrences[c, default: 0] += 1
                            }
                        }
                    }
                    
                    // Pointing Pair/Triple for Rows
                    let rowsWithValue = rowOccurrences.filter { $0.value > 0 }
                    if rowsWithValue.count == 1, let (blockRowIndex, _) = rowsWithValue.first {
                        let actualRow = blockRow * 3 + blockRowIndex
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
}
