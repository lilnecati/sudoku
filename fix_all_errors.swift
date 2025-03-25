#!/usr/bin/env swift

import Foundation

// Dosya içeriğini oku
let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"
let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)

// Değişiklikler
let newContents = fileContents.replacingOccurrences(
    of: "difficulty: boardDifficultyEnum)",
    with: "difficulty: boardDifficultyEnum2)"
)

// Yeni içeriği yaz
try newContents.write(toFile: filePath, atomically: true, encoding: .utf8)
print("✅ boardDifficultyEnum referansları düzeltildi")
