import Foundation

func fixSudoku() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // difficultyEnum -> boardDifficultyEnum değişimini yap
        let newContent = content.replacingOccurrences(
            of: "difficulty: difficultyEnum",
            with: "difficulty: boardDifficultyEnum"
        )
        
        // Değiştirilmiş içeriği geri yaz
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ SudokuViewModel.swift başarıyla düzeltildi!")
    } catch {
        print("❌ Hata: \(error)")
    }
}
