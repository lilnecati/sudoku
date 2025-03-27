import Foundation

func fixAllErrors() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"
    
    do {
        // Dosya içeriğini oku
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Değişiklikler
        let newContents = fileContents.replacingOccurrences(
            of: "difficulty: boardDifficultyEnum)",
            with: "difficulty: boardDifficultyEnum2)"
        )
        
        // Yeni içeriği yaz
        try newContents.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ boardDifficultyEnum referansları düzeltildi")
    } catch {
        print("❌ Hata: \(error)")
    }
}
