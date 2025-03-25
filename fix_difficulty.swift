#!/usr/bin/env swift

import Foundation

// Bu script ikinci difficulty2Value tanımını difficultyValue3 olarak değiştirir

let filePath = "/Users/necati/Desktop/Sudoku/Sudoku/ViewModel/SudokuViewModel.swift"

do {
    let content = try String(contentsOfFile: filePath, encoding: .utf8)
    
    // İçeriği satırlara böl
    var lines = content.components(separatedBy: .newlines)
    
    // İlk difficulty2Value tanımını bulalım
    var firstFound = false
    
    for i in 0..<lines.count {
        if lines[i].contains("let difficulty2Value:") {
            if !firstFound {
                // İlk bulunan tanımı işaretleyelim
                firstFound = true
            } else {
                // İkinci bulunan tanımı değiştirelim
                lines[i] = lines[i].replacingOccurrences(of: "let difficulty2Value:", with: "let difficultyValue3:")
                // Ayrıca aşağıdaki satırlarda difficulty2Value referanslarını değiştirelim
                for j in (i+1)..<min(i+15, lines.count) {
                    lines[j] = lines[j].replacingOccurrences(of: "difficulty2Value", with: "difficultyValue3")
                }
                break
            }
        }
    }
    
    // Değiştirilmiş içeriği geri yazalım
    let newContent = lines.joined(separator: "\n")
    
    try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    print("✅ difficulty2Value değişkeni başarıyla düzeltildi!")
} catch {
    print("❌ Hata: \(error)")
}
