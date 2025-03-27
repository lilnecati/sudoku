//  AnimatedSudokuLogo.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI

struct AnimatedSudokuLogo: View {
    // Giriş ekranı modu
    var isStartupScreen: Bool = false
    var continuousRotation: Bool = false
    
    // Animasyon durumları
    @State private var glowIntensity: CGFloat = 0.5
    @State private var highlightedCell: Int? = nil
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var continuousRotationAngle: Double = 0
    @State private var selectedPattern: Int = 0
    @State private var colorOffset: Int = 0
    @State private var borderColorIndex: Int = 0
    
    // Zamanlayıcılar
    let highlightTimer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    let patternTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()
    let colorTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    // Renk ve boyut
    private let gridSize: CGFloat = 90
    private let cellSize: CGFloat = 30
    
    // Renk paleti - 15 farklı renk
    private let colors: [Color] = [
        .white,
        .yellow,
        .green,
        .cyan,
        .pink,
        .orange,
        .purple,
        .red,
        .blue,
        Color(red: 0.0, green: 1.0, blue: 0.5),  // Turkuaz
        Color(red: 1.0, green: 0.5, blue: 0.0),  // Turuncu-kırmızı
        Color(red: 0.5, green: 0.0, blue: 1.0),  // Mor-mavi
        Color(red: 0.0, green: 0.8, blue: 0.8),  // Açık mavi
        Color(red: 1.0, green: 0.8, blue: 0.0),  // Altın sarısı
        Color(red: 0.8, green: 0.0, blue: 0.5)   // Fuşya
    ]
    
    // Sayılar
    private let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    
    // Vurgulama desenleri
    private let patterns: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8],           // Tüm hücreler
        [0, 4, 8],                              // Çapraz
        [2, 4, 6],                              // Ters çapraz
        [1, 3, 5, 7],                           // Orta hücreler
        [0, 2, 6, 8],                           // Köşeler
        [0, 1, 2],                              // Üst satır
        [6, 7, 8],                              // Alt satır
        [0, 3, 6],                              // Sol sütun
        [2, 5, 8]                               // Sağ sütun
    ]
    
    // Sayı için renk alma
    private func colorForNumber(at index: Int) -> Color {
        let colorIndex = (index + colorOffset) % colors.count
        return colors[colorIndex]
    }
    
    // Border için renk alma
    private func borderColor() -> Color {
        return colors[borderColorIndex]
    }
    
    var body: some View {
        let logoContent = ZStack {
            // Ana grid
            VStack(spacing: 0) {
                ForEach(0..<3) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { col in
                            let index = row * 3 + col
                            
                            SudokuCell(
                                number: numbers[index],
                                size: cellSize,
                                isHighlighted: patterns[selectedPattern].contains(index) && highlightedCell != nil,
                                isSpecialHighlighted: highlightedCell == index,
                                mainColor: borderColor(),
                                textColor: colorForNumber(at: index)
                            )
                            .animation(.easeInOut(duration: 0.3), value: highlightedCell == index)
                            .animation(.easeInOut(duration: 0.5), value: patterns[selectedPattern].contains(index))
                        }
                    }
                }
            }
            .overlay(
                // Dış çerçeve
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor(), lineWidth: 3)
            )
            .overlay(
                // İç çerçeve
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor().opacity(0.5), lineWidth: 1)
                    .padding(4)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.9))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.5), value: borderColorIndex)
            
            // Parlama efekti
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(), lineWidth: 2)
                .blur(radius: 6)
                .opacity(glowIntensity)
                .frame(width: gridSize + 10, height: gridSize + 10)
            
            // Dış parlama efekti
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor(), lineWidth: 1)
                .blur(radius: 8)
                .opacity(glowIntensity * 0.7)
                .frame(width: gridSize + 20, height: gridSize + 20)
        }
        .frame(width: gridSize, height: gridSize)
        .scaleEffect(scale)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 0, z: 1))
        
        // Sürekli döndürme için
        return Group {
            if continuousRotation {
                logoContent
                    .rotationEffect(.degrees(continuousRotationAngle))
            } else {
                logoContent
            }
        }
        .onAppear {
            // Başlangıç animasyonu - giriş ekranında değilse
            if !isStartupScreen {
                withAnimation(.easeInOut(duration: 2.0)) {
                    rotation = 360
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        rotation = 0
                    }
                }
            }
            
            // Sürekli nefes alma animasyonu
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.05
            }
            
            // Sürekli döndürme animasyonu
            if continuousRotation {
                withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                    continuousRotationAngle = 360
                }
            }
            
            // İlk desen seçimi
            selectedPattern = Int.random(in: 0..<patterns.count)
        }
        .onReceive(highlightTimer) { _ in
            // Rastgele bir hücreyi vurgula
            withAnimation {
                if highlightedCell == nil {
                    highlightedCell = patterns[selectedPattern].randomElement()
                } else {
                    highlightedCell = nil
                }
                
                // Parlama efekti
                withAnimation(.easeInOut(duration: 0.8)) {
                    glowIntensity = 1.0
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            glowIntensity = 0.5
                        }
                    }
                }
            }
        }
        .onReceive(patternTimer) { _ in
            // Desen değiştir
            withAnimation(.easeInOut(duration: 1.0)) {
                let newPattern = Int.random(in: 0..<patterns.count)
                if newPattern != selectedPattern {
                    selectedPattern = newPattern
                } else {
                    selectedPattern = (selectedPattern + 1) % patterns.count
                }
                
                // Küçük bir dönüş animasyonu
                withAnimation(.easeInOut(duration: 1.0)) {
                    rotation = 5
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            rotation = 0
                        }
                    }
                }
            }
        }
        .onReceive(colorTimer) { _ in
            // Renk değiştir - her sayı için farklı renk
            withAnimation(.easeInOut(duration: 0.5)) {
                colorOffset = (colorOffset + 1) % colors.count
                borderColorIndex = (borderColorIndex + 1) % colors.count
            }
        }
    }
}

// Sudoku hücresi
struct SudokuCell: View {
    let number: Int
    let size: CGFloat
    let isHighlighted: Bool
    let isSpecialHighlighted: Bool
    let mainColor: Color
    let textColor: Color
    
    var body: some View {
        ZStack {
            // Arka plan
            Rectangle()
                .fill(
                    isSpecialHighlighted ? mainColor.opacity(0.5) :
                    isHighlighted ? mainColor.opacity(0.3) : Color.clear
                )
                .frame(width: size, height: size)
            
            // Sayı
            Text("\(number)")
                .font(.system(size: isSpecialHighlighted ? 20 : 18, weight: .bold))
                .foregroundColor(
                    isSpecialHighlighted ? .white :
                    isHighlighted ? .white : textColor
                )
                .frame(width: size, height: size)
                .scaleEffect(isSpecialHighlighted ? 1.2 : isHighlighted ? 1.1 : 1.0)
                .shadow(color: textColor.opacity(0.7), radius: 2)
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.5), value: textColor)
    }
}
