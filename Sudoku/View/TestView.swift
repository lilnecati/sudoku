//  TestView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 15.11.2024.
//

import SwiftUI

struct TestView: View {
    @State private var selectedDifficulty: String = "Kolay"
    @State private var toggleValue: Bool = false
    let difficulties = ["Kolay", "Orta", "Zor", "Uzman"]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Neon ızgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Başlık
                Text("SUDOKU")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .shadow(color: .blue.opacity(0.8), radius: 10, x: 0, y: 0)
                    .padding(.top, 40)
                
                // Alttaki görsel içeriği kapsayan Sudoku görünümü
                sudokuGamePreview
                
                // Zorluk seçici
                difficultySelector
                
                // Buton örneği
                actionButtons
                
                Spacer()
            }
            .padding()
        }
    }
    
    // Sudoku oyun tahtası önizlemesi
    private var sudokuGamePreview: some View {
        SudokuPreview(colorScheme: colorScheme)
    }
    
    // Sudoku önizleme bileşeni
    private struct SudokuPreview: View {
        let colorScheme: ColorScheme
        
        var body: some View {
            ZStack {
                previewBackground
                sudokuGrid
            }
        }
        
        // Arka plan kapsülü
        private var previewBackground: some View {
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.7))
                .frame(width: 300, height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .purple.opacity(colorScheme == .dark ? 0.8 : 0.3), 
                                    .blue.opacity(colorScheme == .dark ? 0.4 : 0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: colorScheme == .dark ? 2 : 1
                        )
                )
                .shadow(
                    color: .purple.opacity(colorScheme == .dark ? 0.5 : 0.2), 
                    radius: 15, 
                    x: 0, 
                    y: 0
                )
        }
        
        // Sudoku ızgara çizgileri
        private var sudokuGrid: some View {
            VStack(spacing: 0) {
                ForEach(0..<3) { blockRow in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { blockCol in
                            SudokuBlock(
                                blockRow: blockRow,
                                blockCol: blockCol,
                                colorScheme: colorScheme
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Sudoku 3x3 blok bileşeni
    private struct SudokuBlock: View {
        let blockRow: Int
        let blockCol: Int
        let colorScheme: ColorScheme
        
        var body: some View {
            VStack(spacing: 1) {
                ForEach(0..<3) { cellRow in
                    HStack(spacing: 1) {
                        ForEach(0..<3) { cellCol in
                            let r = blockRow * 3 + cellRow
                            let c = blockCol * 3 + cellCol
                            
                            SudokuCell(row: r, col: c, colorScheme: colorScheme)
                        }
                    }
                }
            }
            .padding(1)
            .background(Color.purple.opacity(colorScheme == .dark ? 0.3 : 0.1))
        }
    }
    
    // Sudoku hücre bileşeni
    private struct SudokuCell: View {
        let row: Int
        let col: Int
        let colorScheme: ColorScheme
        
        // Rastgele bazı hücrelerde değer göster
        private var shouldShowValue: Bool {
            return (row + col) % 5 == 0
        }
        
        var body: some View {
            ZStack {
                Rectangle()
                    .fill(colorScheme == .dark ? 
                         Color.black.opacity(0.3) : 
                         Color.black.opacity(0.05))
                    .frame(width: 28, height: 28)
                
                if shouldShowValue {
                    Text("\((row + col) % 9 + 1)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
        }
    }
    
    // Zorluk seviye seçici
    private var difficultySelector: some View {
        VStack(spacing: 10) {
            Text("Zorluk Seviyesi")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            HStack(spacing: 8) {
                ForEach(difficulties, id: \.self) { difficulty in
                    DifficultyButton(
                        difficulty: difficulty,
                        isSelected: selectedDifficulty == difficulty,
                        colorScheme: colorScheme,
                        action: {
                            withAnimation {
                                selectedDifficulty = difficulty
                            }
                        }
                    )
                }
            }
        }
    }
    
    // Zorluk seviyesi butonu - karmaşık ifadeyi daha yönetilebilir parçalara ayırmak için
    private struct DifficultyButton: View {
        let difficulty: String
        let isSelected: Bool
        let colorScheme: ColorScheme
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(difficulty)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundColor(foregroundColor)
                    .background(backgroundView)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        
        // Önplan rengi
        private var foregroundColor: Color {
            if colorScheme == .dark {
                return .white
            } else {
                return isSelected ? .white : .black
            }
        }
        
        // Arka plan görünümü
        private var backgroundView: some View {
            ZStack {
                if isSelected {
                    selectedBackground
                } else {
                    unselectedBackground
                }
            }
        }
        
        // Seçili durumda arka plan
        private var selectedBackground: some View {
            Capsule()
                .fill(getDifficultyColor().opacity(colorScheme == .dark ? 0.3 : 0.7))
                .overlay(
                    Capsule()
                        .stroke(getDifficultyColor(), lineWidth: 1.5)
                )
                .shadow(
                    color: getDifficultyColor().opacity(colorScheme == .dark ? 0.8 : 0.3), 
                    radius: 8, 
                    x: 0, 
                    y: 0
                )
        }
        
        // Seçili olmayan durumda arka plan
        private var unselectedBackground: some View {
            Capsule()
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2), 
                    lineWidth: 1
                )
        }
        
        // Zorluk seviyesine göre renk
        private func getDifficultyColor() -> Color {
            switch difficulty {
            case "Kolay":
                return .green
            case "Orta":
                return .blue
            case "Zor":
                return .orange
            case "Uzman":
                return .red
            default:
                return .gray
            }
        }
    }
    
    // Aksiyon butonları
    private var actionButtons: some View {
        VStack(spacing: 20) {
            // Başlat butonu
            StartGameButton(colorScheme: colorScheme)
            
            // Toggle butonu
            SoundToggleControl(
                isOn: $toggleValue,
                colorScheme: colorScheme
            )
        }
    }
    
    // Başlat butonu bileşeni
    private struct StartGameButton: View {
        let colorScheme: ColorScheme
        
        var body: some View {
            Button(action: {}) {
                Text("Oyunu Başlat")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 250)
                    .background(backgroundView)
            }
        }
        
        private var backgroundView: some View {
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .green.opacity(colorScheme == .dark ? 0.6 : 0.8), 
                                .green.opacity(colorScheme == .dark ? 0.3 : 0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Capsule()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .green, 
                                .green.opacity(colorScheme == .dark ? 0.5 : 0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), 
                        lineWidth: 1.5
                    )
            }
            .shadow(
                color: .green.opacity(colorScheme == .dark ? 0.6 : 0.3), 
                radius: 10, 
                x: 0, 
                y: 0
            )
        }
    }
    
    // Ses ayarları toggle buton bileşeni
    private struct SoundToggleControl: View {
        @Binding var isOn: Bool
        let colorScheme: ColorScheme
        
        var body: some View {
            HStack {
                Text("Ses Efektleri")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                // Neon toggle
                ToggleButton(isOn: $isOn, colorScheme: colorScheme)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), 
                                lineWidth: 1
                            )
                    )
            )
        }
    }
    
    // Toggle button bileşeni
    private struct ToggleButton: View {
        @Binding var isOn: Bool
        let colorScheme: ColorScheme
        
        var body: some View {
            ZStack {
                // Arka plan
                Capsule()
                    .fill(
                        isOn ? 
                        Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.5) : 
                        Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2)
                    )
                    .frame(width: 55, height: 30)
                    .overlay(
                        Capsule()
                            .stroke(
                                isOn ? 
                                Color.blue.opacity(colorScheme == .dark ? 1.0 : 0.7) : 
                                Color.gray.opacity(colorScheme == .dark ? 0.5 : 0.3), 
                                lineWidth: 1.5
                            )
                    )
                
                // Sürgü
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: isOn ? 12 : -12)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
        }
    }
}

#Preview {
    TestView()
} 