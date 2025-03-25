#!/usr/bin/env swift

import Foundation

// Bu script, SudokuViewModel.swift dosyasındaki difficultyEnum duplicated declaration hatasını düzeltir
// ve diğer hatalı referansları düzeltir

let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

do {
    let content = try String(contentsOfFile: filePath, encoding: .utf8)
    
    // 1. difficultyEnum -> boardDifficultyEnum değişimini yap
    var newContent = content.replacingOccurrences(
        of: "difficulty: difficultyEnum", 
        with: "difficulty: boardDifficultyEnum"
    )
    
    try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    print("✅ SudokuViewModel.swift başarıyla düzeltildi!")
} catch {
    print("❌ Hata: \(error)")
}
