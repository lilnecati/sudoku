import Foundation

func fixDuplicate() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // İçeriği satırlara böl
        var lines = content.components(separatedBy: .newlines)
        
        // İkinci difficultyValue3 tanımını değiştir
        var found = 0
        for i in 0..<lines.count {
            if lines[i].contains("let difficultyValue3: SudokuBoard.Difficulty") {
                found += 1
                if found == 2 {
                    // İkinci bulduğumuz tanımı değiştir
                    lines[i] = lines[i].replacingOccurrences(of: "difficultyValue3", with: "difficultyValue4")
                    
                    // Sonraki 10 satırda difficultyValue3 referanslarını da değiştir
                    var j = i + 1
                    while j < lines.count && j < i + 15 {
                        if lines[j].contains("difficultyValue3") {
                            lines[j] = lines[j].replacingOccurrences(of: "difficultyValue3", with: "difficultyValue4")
                        }
                        j += 1
                    }
                    break
                }
            }
        }
        
        // Değiştirilmiş içeriği geri yaz
        let newContent = lines.joined(separator: "\n")
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ İkinci difficultyValue3 değişkeni difficultyValue4 olarak değiştirildi!")
    } catch {
        print("❌ Hata: \(error)")
    }
}
