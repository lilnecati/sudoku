import Foundation

func fixDifficulty() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

    do {
        // Dosya içeriğini oku
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // İçeriği satırlara böl
        var lines = content.components(separatedBy: .newlines)
        
        // İlk difficulty2Value tanımını işaretle ve ikinciyi değiştir
        var firstFound = false
        for i in 0..<lines.count {
            if lines[i].contains("let difficulty2Value:") {
                if firstFound {
                    // İkinci bulunan tanımı değiştir
                    lines[i] = lines[i].replacingOccurrences(of: "let difficulty2Value:", with: "let difficultyValue3:")
                    
                    // Sonraki 15 satırda difficulty2Value referanslarını değiştir
                    for j in (i+1)..<min(i+15, lines.count) {
                        if lines[j].contains("difficulty2Value") {
                            lines[j] = lines[j].replacingOccurrences(of: "difficulty2Value", with: "difficultyValue3")
                        }
                    }
                    break
                } else {
                    // İlk bulunan tanımı işaretle
                    firstFound = true
                }
            }
        }
        
        // Değiştirilmiş içeriği geri yaz
        let newContent = lines.joined(separator: "\n")
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ difficulty2Value değişkeni başarıyla düzeltildi!")
    } catch {
        print("❌ Hata: \(error)")
    }
}
