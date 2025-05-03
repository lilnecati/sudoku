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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showLeaderboard = false
    
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        VStack(spacing: 25) {
            // Başlık
            VStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .yellow)
                
                Text("Tebrikler!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                
                Text("Sudoku'yu Tamamladınız")
                    .font(.title3)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
            }
            
            // Skor ve istatistikler
            VStack(spacing: 20) {
                // Toplam puan
                VStack(spacing: 5) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : ColorManager.primaryBlue)
                    
                    Text("PUAN")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                }
                
                if isNewHighScore {
                    Text("🎉 Yeni Rekor! 🎉")
                        .font(.headline)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .orange)
                }
                
                // Detaylar
                VStack(spacing: 15) {
                    StatisticRow(icon: "clock.fill", title: "Süre", value: formatTime(timeElapsed), isBejMode: isBejMode)
                    StatisticRow(icon: "xmark.circle.fill", title: "Hata", value: "\(errorCount)", isBejMode: isBejMode)
                    StatisticRow(icon: "lightbulb.fill", title: "İpucu", value: "\(hintCount)", isBejMode: isBejMode)
                    StatisticRow(icon: "chart.bar.fill", title: "Zorluk", value: difficulty.localizedName, isBejMode: isBejMode)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.cardBackground : 
                             (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)))
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
                    .background(isBejMode ? ThemeManager.BejThemeColors.accent : ColorManager.primaryGreen)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.cardBackground : .white)
                    .cornerRadius(12)
                }
                
                Button(action: onDismiss) {
                    Text("Anasayfaya Dön")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isBejMode ? ThemeManager.BejThemeColors.accent : ColorManager.primaryRed, lineWidth: 1)
                        )
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : ColorManager.primaryRed)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(isBejMode ? 
                   ThemeManager.BejThemeColors.background : 
                   (colorScheme == .dark ? Color(.systemBackground) : .white))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .fullScreenCover(isPresented: $showLeaderboard) {
            ScoreboardView()
        }
        .onAppear {
            // Ekran kararması yönetimi SudokuApp'a devredildi
            logInfo("GameCompletionView onAppear - Ekran kararması ETKİNLEŞTİRİLDİ (ekran kararabilir)")
        }
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
    let isBejMode: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
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
