# Sudoku Tahtası Oluşturma Algoritması

Bu dokümanda, Sudoku oyunumuzda kullanılan tahta oluşturma algoritmasını detaylı olarak inceleyeceğiz. Bu algoritma, her zorluk seviyesi için geçerli ve çözülebilir Sudoku bulmacaları oluşturmak üzere tasarlanmıştır.

## 1. Veri Yapıları ve Temel Bileşenler

### 1.1 Tahta Gösterimi
Sudoku tahtası, 9x9 boyutunda iki boyutlu bir dizi olarak temsil edilir:

```swift
var board: [[Int?]] = Array(repeating: Array(repeating: nil, count: 9), count: 9)
var solution: [[Int?]] = Array(repeating: Array(repeating: nil, count: 9), count: 9)
var originalBoard: [[Int?]] = Array(repeating: Array(repeating: nil, count: 9), count: 9)
var fixed: [[Bool]] = Array(repeating: Array(repeating: false, count: 9), count: 9)
var fixedCells: Set<String> = Set<String>()
var pencilMarks: [String: Set<Int>] = [:]
```

- `board`: Mevcut oyun tahtası (oyuncunun gördüğü ve değiştirebildiği)
- `solution`: Tam çözümü içeren tahta
- `originalBoard`: Başlangıç durumundaki tahta (sıfırlama için)
- `fixed`: Hangi hücrelerin sabit (değiştirilemez) olduğunu gösteren matris
- `fixedCells`: Sabit hücrelerin koordinatlarını tutan küme
- `pencilMarks`: Oyuncunun kalem işaretlerini tutan sözlük

### 1.2 Zorluk Seviyeleri
Zorluk seviyeleri bir enum olarak tanımlanır:

```swift
enum Difficulty {
    case easy
    case medium
    case hard
    case expert
}
```

Her zorluk seviyesi, tahtada kalan ipucu sayısını ve gereken çözüm tekniklerinin karmaşıklığını belirler.

## 2. Tam Çözüm Oluşturma

### 2.1 Latin Kare Temelli Yaklaşım

Hızlı ve güvenilir bir şekilde geçerli bir Sudoku çözümü oluşturmak için Latin kare yaklaşımı kullanılır:

```swift
private func generateSimpleSolution() {
    // Tahtayı temizle
    for row in 0..<9 {
        for col in 0..<9 {
            board[row][col] = nil
            solution[row][col] = nil
        }
    }
    
    // Temel Latin kare deseni oluştur
    var basePattern = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    
    // İlk satırı rastgele oluştur
    var firstRow = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    firstRow.shuffle()
    
    // İlk satırı yerleştir
    for col in 0..<9 {
        basePattern[0][col] = firstRow[col]
    }
    
    // Sonraki satırları kaydırarak oluştur
    for row in 1..<9 {
        // Her satırı bir önceki satıra göre kaydır
        let offset = (row % 3 == 0) ? 1 : 3
        
        for col in 0..<9 {
            let sourceIdx = (col + offset) % 9
            basePattern[row][col] = basePattern[row-1][sourceIdx]
        }
    }
    
    // Deseni tahtaya kopyala
    for row in 0..<9 {
        for col in 0..<9 {
            board[row][col] = basePattern[row][col]
            solution[row][col] = basePattern[row][col]
        }
    }
}
```

Bu yaklaşım, her satır, sütun ve 3x3 bloğun 1-9 arasındaki tüm sayıları içermesini garantiler.

### 2.2 Karıştırma İşlemleri

Oluşturulan temel tahta, rastgeleliği artırmak için kapsamlı bir şekilde karıştırılır:

```swift
private func mixSudokuCompletely() {
    // 50 kez rastgele dönüşüm uygula
    for _ in 0..<50 {
        // Rastgele bir dönüşüm seç
        let transformation = Int.random(in: 0..<6)
        
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
            // Sayı değerlerini değiştir
            let num1 = Int.random(in: 1...9)
            var num2 = Int.random(in: 1...9)
            while num2 == num1 {
                num2 = Int.random(in: 1...9)
            }
            swapValues(num1, num2)
        case 5:
            // Tahtayı döndür
            rotateBoard()
        }
    }
}
```

Uygulanan karıştırma işlemleri:

1. **Satır Bloklarını Karıştırma**: 3x3 blok yapısındaki satır gruplarını değiştirir
2. **Sütun Bloklarını Karıştırma**: 3x3 blok yapısındaki sütun gruplarını değiştirir
3. **Blok İçi Satırları Karıştırma**: Aynı 3x3 blok içindeki satırları değiştirir
4. **Blok İçi Sütunları Karıştırma**: Aynı 3x3 blok içindeki sütunları değiştirir
5. **Sayı Değerlerini Değiştirme**: Tüm tahtada belirli iki sayıyı birbirleriyle değiştirir
6. **Tahtayı Döndürme**: Tahtayı 90 derece döndürür

Bu dönüşümlerin her biri, tahtanın geçerliliğini korurken farklı bir görünüm sağlar. 50 adımlık rastgele dönüşümler, neredeyse her tahtanın benzersiz olmasını sağlar.

## 3. Bulmaca Oluşturma

### 3.1 İpucu Sayısının Belirlenmesi

Her zorluk seviyesi için uygun ipucu sayısı belirlenir:

```swift
private func getCluesToShow() -> Int {
    switch difficulty {
    case .easy:
        return Int.random(in: 42...47)
    case .medium:
        return Int.random(in: 36...40)
    case .hard:
        return Int.random(in: 30...34)
    case .expert:
        return Int.random(in: 26...29)
    }
}
```

### 3.2 Hücre Kaldırma Süreci

Tam çözümden hücreler kaldırılarak bulmaca oluşturulur:

```swift
private func generateEasyPuzzle(cluesToShow: Int) {
    // Kaldırılacak hücre sayısını hesapla
    let cellsToRemove = 81 - cluesToShow
    
    // Tüm hücreleri rastgele sırayla al
    let allCells = getAllCellsInRandomOrder()
    var removedCount = 0
    
    // Rastgele hücreleri kaldırmayı dene
    for (row, col) in allCells {
        if removedCount >= cellsToRemove {
            break
        }
        
        // Hücrenin orijinal değerini sakla
        let originalValue = board[row][col]
        
        // Hücreyi geçici olarak kaldır
        board[row][col] = nil
        
        // Kontroller: Benzersiz çözüm ve dengeli dağılım
        if maintainsSimpleSolving() && hasBalancedDistribution() {
            // Kaldırma başarılı
            removedCount += 1
        } else {
            // Kaldırma başarısız, geri al
            board[row][col] = originalValue
        }
    }
}
```

### 3.3 Zorluk Seviyelerine Göre Kontroller

Her zorluk seviyesi için farklı kontroller uygulanır:

#### Kolay
- Basit tekniklerle çözülebilir olmalı (Hidden Singles, Naked Singles)
- Her satır, sütun ve blokta en az 4-5 ipucu bulunmalı

#### Orta
- Naked Pairs, Hidden Pairs gibi orta seviye teknikler gerektirmeli
- Her satır, sütun ve blokta en az 3-4 ipucu bulunmalı

#### Zor
- Pointing Pairs, Box-Line Reduction gibi gelişmiş teknikler gerektirmeli
- Her satır, sütun ve blokta en az 2-3 ipucu bulunmalı

#### Uzman
- X-Wing, Swordfish gibi çok ileri teknikler gerektirmeli
- Minimum hücre sayısıyla tek çözüme sahip olmalı

### 3.4 Mantıksal Çözülebilirlik Kontrolü

Hücreler kaldırıldıktan sonra, bulmaca mantıksal tekniklerle çözülebilir mi kontrol edilir:

```swift
private func testLogicalSolvability() -> Bool {
    // Tahtanın bir kopyasını al
    let boardCopy = copyBoard(board)
    
    // Constraint Propagation uygula
    if let propagatedBoard = applyConstraintPropagation(boardCopy) {
        // Tamamen çözülebildi mi kontrol et
        if isCompleteSolution(propagatedBoard) {
            return true
        }
        
        // Burada daha ileri seviye mantıksal çözüm teknikleri uygulanabilir
        // (Naked Pairs, Hidden Pairs, Pointing Pairs, X-Wing, vb.)
    }
    
    // Çözülemedi
    return false
}
```

## 4. Sabit Hücrelerin İşaretlenmesi

Bulmaca oluşturulduktan sonra, ipucu olarak kalan hücreler "sabit" olarak işaretlenir:

```swift
private func markFixedCells() {
    fixedCells.removeAll()
    
    for row in 0..<9 {
        for col in 0..<9 {
            if board[row][col] != nil {
                fixed[row][col] = true
                let key = "\(row)_\(col)"
                fixedCells.insert(key)
                originalBoard[row][col] = board[row][col]
            } else {
                fixed[row][col] = false
                originalBoard[row][col] = nil
            }
        }
    }
}
```

## 5. Çözüm Doğrulama

Bulmaca oluşturulduğunda, çözümün benzersiz olduğunu doğrulamak için recursive backtracking algoritması kullanılır:

```swift
private func hasUniqueSolution(_ board: [[Int?]]) -> Bool {
    var solutionCount = 0
    let boardCopy = copyBoard(board)
    
    // Recursive olarak çözüm sayısını bul
    countSolutions(boardCopy, &solutionCount)
    
    // Sadece bir çözüm varsa true döndür
    return solutionCount == 1
}

private func countSolutions(_ board: [[Int?]], _ count: inout Int) {
    // Maksimum çözüm sayısına ulaşıldı mı kontrol et
    if count > 1 {
        return
    }
    
    // Boş bir hücre bul
    if let emptyCell = findEmptyCell(board) {
        let (row, col) = emptyCell
        
        // Tüm olası değerleri dene
        for value in 1...9 {
            if isValid(board, row, col, value) {
                var newBoard = copyBoard(board)
                newBoard[row][col] = value
                
                // Recursive olarak devam et
                countSolutions(newBoard, &count)
                
                // İkiden fazla çözüm bulunduysa erken çık
                if count > 1 {
                    return
                }
            }
        }
    } else {
        // Tüm hücreler dolu, bir çözüm bulundu
        count += 1
    }
}
```

## 6. Optimizasyon ve Performans Yöntemleri

### 6.1 Önbellekleme
Sık kullanılan kontrol sonuçları önbelleğe alınarak performans artırılır:

```swift
var validPlacementCache: [String: Bool] = [:]
var emptyCellCountCache: Int?
var nakedSingleCountCache: Int?
var hiddenSingleCountCache: Int?
```

### 6.2 Hızlı Başlangıç Yaklaşımı
Tamamen rastgele bulmaca oluşturmak yerine, Latin kare temelli bir yaklaşım kullanılarak hızlı bir şekilde geçerli bir çözüm elde edilir.

### 6.3 Zorluk Seviyesi İyileştirmeleri
Her zorluk seviyesi için özel olarak tasarlanmış hücre kaldırma algoritmaları, oyuncu deneyimini optimize eder ve bulmacaların ilgili zorluk seviyesine uygun olmasını sağlar.

## 7. Örnek Kullanım

```swift
// Kolay zorlukta bir tahta oluştur
let easyBoard = SudokuBoard(difficulty: .easy)

// Orta zorlukta bir tahta oluştur
let mediumBoard = SudokuBoard(difficulty: .medium)

// Bir hücreye değer yerleştirmeyi dene
if easyBoard.isValidMove(row: 4, column: 5, value: 7) {
    easyBoard.setValue(row: 4, column: 5, value: 7)
}

// Tahtayı sıfırla
easyBoard.resetToOriginal()
```

## 8. Çözüm Teknikleri Kontrolü

Bulmacaların karmaşıklığını kontrol etmek için kullanılan bazı teknikler:

### 8.1 Naked Singles
Bir hücrenin sadece bir olası değeri olduğunda kullanılır.

### 8.2 Hidden Singles
Bir satır, sütun veya bloktaki bir sayı sadece bir hücreye yerleştirilebiliyorsa kullanılır.

### 8.3 Naked Pairs/Triples
İki/üç hücre aynı iki/üç olası değeri içeriyorsa, bu değerler diğer hücrelerden elenebilir.

### 8.4 Pointing Pairs/Triples
Bir blokta belirli bir sayı için olası hücreler aynı satır veya sütundaysa, o satır veya sütundaki diğer bloklardaki hücrelerden bu sayı elenebilir.

### 8.5 X-Wing
İki satırda aynı sayı için olası hücreler aynı iki sütundaysa, diğer satırlardaki bu sütunlardaki hücrelerden bu sayı elenebilir.

## 9. Sonuç

Bu algoritma, her zorluk seviyesi için tutarlı, çözülebilir ve benzersiz Sudoku bulmacaları oluşturmak için tasarlanmıştır. Algoritma, Latin kare yaklaşımıyla hızlı bir şekilde geçerli çözümler oluşturur, kapsamlı karıştırma işlemleriyle rastgelelik sağlar ve zorluk seviyesine göre uyarlanmış hücre kaldırma teknikleriyle oyuncu deneyimini optimize eder. 