import Foundation

func fixDuplicate() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        var lines = content.components(separatedBy: .newlines)
        
        var found = 0
        for i in 0..<lines.count {
            if lines[i].contains("let difficultyValue3: SudokuBoard.Difficulty") {
                found += 1
                if found == 2 {
                    lines[i] = lines[i].replacingOccurrences(of: "difficultyValue3", with: "difficultyValue4")
                    
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
        
        let newContent = lines.joined(separator: "\n")
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ İkinci difficultyValue3 değişkeni difficultyValue4 olarak değiştirildi!")
    } catch {
        print("❌ Hata: \(error)")
    }
}
