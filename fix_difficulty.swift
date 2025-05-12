import Foundation

func fixDifficulty() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        var lines = content.components(separatedBy: .newlines)
        
        var firstFound = false
        for i in 0..<lines.count {
            if lines[i].contains("let difficulty2Value:") {
                if firstFound {
                    lines[i] = lines[i].replacingOccurrences(of: "let difficulty2Value:", with: "let difficultyValue3:")
                    
                    for j in (i+1)..<min(i+15, lines.count) {
                        if lines[j].contains("difficulty2Value") {
                            lines[j] = lines[j].replacingOccurrences(of: "difficulty2Value", with: "difficultyValue3")
                        }
                    }
                    break
                } else {
                    firstFound = true
                }
            }
        }
        
        let newContent = lines.joined(separator: "\n")
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ difficulty2Value değişkeni başarıyla düzeltildi!")
    } catch {
        print("❌ Hata: \(error)")
    }
}
