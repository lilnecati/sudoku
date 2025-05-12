import Foundation

func fixAllErrors() {
    let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"
    
    do {
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
        let newContents = fileContents.replacingOccurrences(
            of: "difficulty: boardDifficultyEnum)",
            with: "difficulty: boardDifficultyEnum2)"
        )
        
        try newContents.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("✅ boardDifficultyEnum referansları düzeltildi")
    } catch {
        print("❌ Hata: \(error)")
    }
}
