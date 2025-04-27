//  GameCompletionView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 13.09.2024.
//

import SwiftUI

struct GameCompletionView: View {
    let difficulty: SudokuBoard.Difficulty
    let timeElapsed: TimeInterval
    let errorCount: Int
    let hintCount: Int
    let score: Int
    let isNewHighScore: Bool
    let onNewGame: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 25) {
            // Başlık
            VStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Tebrikler!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Sudoku'yu Tamamladınız")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Skor ve istatistikler
            VStack(spacing: 20) {
                // Toplam puan
                VStack(spacing: 5) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(ColorManager.primaryBlue)
                    
                    Text("PUAN")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                if isNewHighScore {
                    Text("🎉 Yeni Rekor! 🎉")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                
                // Detaylar
                VStack(spacing: 15) {
                    StatisticRow(icon: "clock.fill", title: "Süre", value: formatTime(timeElapsed))
                    StatisticRow(icon: "xmark.circle.fill", title: "Hata", value: "\(errorCount)")
                    StatisticRow(icon: "lightbulb.fill", title: "İpucu", value: "\(hintCount)")
                    StatisticRow(icon: "chart.bar.fill", title: "Zorluk", value: difficulty.localizedName)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                )
            }
            .padding(.vertical)
            
            // Butonlar
            VStack(spacing: 15) {
                Button(action: onNewGame) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Yeni Oyun")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorManager.primaryGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: onDismiss) {
                    Text("Anasayfaya Dön")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ColorManager.primaryRed, lineWidth: 1)
                        )
                        .foregroundColor(ColorManager.primaryRed)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemBackground) : .white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .achievementToastSystem() 
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct StatisticRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        GameCompletionView(
            difficulty: .medium,
            timeElapsed: 725,
            errorCount: 2,
            hintCount: 1,
            score: 2850,
            isNewHighScore: true,
            onNewGame: {},
            onDismiss: {}
        )
        .padding()
    }
} 
