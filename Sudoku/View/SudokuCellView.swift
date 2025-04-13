//  SudokuCellView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 08.12.2024.
//

import SwiftUI
import AudioToolbox
import AVFoundation

struct SudokuCellView: View {
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("enableCellTapHaptic") private var enableCellTapHaptic = true
    let row: Int
    let column: Int
    let value: Int?
    let isFixed: Bool
    let isUserEntered: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    let isMatchingValue: Bool
    let isInvalid: Bool
    let pencilMarks: Set<Int>
    let isHintTarget: Bool // İpucu gösterildiğinde hedef olup olmadığı
    let onCellTapped: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var powerManager = PowerSavingManager.shared
    @State private var animateSelection = false
    @State private var animateValue = false
    
    var body: some View {
        GeometryReader { geometry in
            // Perfomans için değerleri önbelleğe al
            let cellDimension = min(geometry.size.width, geometry.size.height)
            
            Button(action: {
                // Ses efekti çal - artık playNavigationSound titreşim de içeriyor
                SoundManager.shared.playNavigationSound()
                
                // Güç tasarrufu modunda değilse seçim animasyonunu tetikle
                if !powerManager.isPowerSavingEnabled {
                    // Daha etkileyici baskı hissi için pulsamayı kullan
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        animateSelection = true
                    }
                    
                    // Yavaşça normal boyuta dönüş
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            animateSelection = false
                        }
                    }
                }
                
                onCellTapped()
            }) {
                ZStack {
                    // Hücre arka planı - hata veya seçiliyse Metal kullan
                    cellBackground
                        .scaleEffect(animateSelection ? 0.95 : 1.0)
                    
                    // Hatalı hücre göstergesi - sadece hatalı ise çiz
                    if isInvalid {
                        invalidCellOverlay
                    }
                    
                    // Hücre içeriği (sayı veya kalem işaretleri)
                    // Sabit boyutlu konteyner - sadece içerik varsa çiz
                    cellContent(cellDimension: cellDimension)
                }
                // Sadece seçili, hatalı veya vurgulanmış hücrelerde Metal kullan
                .drawingGroup(opaque: true, colorMode: .linear)
            }
            // Animasyonu basitleştirelim - yalnızca seçili durum değiştiğinde ve güç tasarrufunda değilse
            .powerSavingAwareAnimation(isSelected ? .spring(response: 0.25, dampingFraction: 0.7) : .none, value: isSelected)
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    // Hücre arka planı
    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(getCellBackgroundColor())
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isInvalid ? Color.red : getCellBorderColor(), lineWidth: isInvalid ? 2 : (isSelected ? 2 : (isMatchingValue ? 1.5 : 0.5)))
            )
            .powerSavingAwareEffect(isEnabled: isSelected || isMatchingValue || isInvalid)
    }
    
    // Hücre arka plan rengi - Tek renk temali modern tasarım
    private func getCellBackgroundColor() -> Color {
        // Ana tema rengi: Teal (turkuaz) - ipucu için mavi renk
        let themeColor = Color.teal
        let hintColor = Color.blue
        let errorColor = Color.red
        
        // Hatalı giriş için kırmızı arka plan
        if isInvalid {
            return colorScheme == .dark ? errorColor.opacity(0.25) : errorColor.opacity(0.15)
        }
        // İpucu hedefiyse mavi renkle vurgula (görsellerdeki gibi)
        else if isHintTarget {
            return colorScheme == .dark ? hintColor.opacity(0.45) : hintColor.opacity(0.25) 
        }
        else if isSelected {
            // Seçili hücre - en koyu ton
            return colorScheme == .dark ? themeColor.opacity(0.4) : themeColor.opacity(0.25)
        } else if isMatchingValue {
            // Aynı değerli hücreler - DAHA BELİRGİN TON
            // Tüm aynı değerli hücreler için aynı arka plan rengi kullan
            return colorScheme == .dark ? themeColor.opacity(0.4) : themeColor.opacity(0.3)
        } else if isHighlighted {
            // Aynı satır/sütun - orta ton
            return colorScheme == .dark ? themeColor.opacity(0.25) : themeColor.opacity(0.15) 
        } else {
            // Normal hücreler - çok hafif ton veya beyaz
            return colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white
        }
    }
    
    // Hücre kenar rengi - Tek renk temalı kenarlar
    private func getCellBorderColor() -> Color {
        // Ana tema rengi: Teal (turkuaz), ipucu için mavi
        let themeColor = Color.teal
        let hintColor = Color.blue
        let errorColor = Color.red
        
        // Hatalı giriş için kırmızı kenarlık
        if isInvalid {
            return colorScheme == .dark ? errorColor : errorColor
        }
        // İpucu hedefiyse daha koyu mavi kenarlık (görsellerdeki gibi)
        else if isHintTarget {
            return colorScheme == .dark ? hintColor.opacity(1.0) : hintColor.opacity(0.8)
        }
        else if isSelected {
            // Seçili hücre kenarı - tam yoğunluk
            return themeColor
        } else if isMatchingValue {
            // Aynı değerli hücrelerin kenarları - DAHA BELİRGİN
            // Tüm aynı değerli hücreler için aynı kenar rengi kullan
            return colorScheme == .dark ? themeColor.opacity(0.9) : themeColor.opacity(0.7)
        } else if isHighlighted {
            // Aynı satır/sütun kenarı - orta yoğunluk
            return colorScheme == .dark ? themeColor.opacity(0.6) : themeColor.opacity(0.4)
        } else {
            // Normal kenarlar - çok hafif
            return colorScheme == .dark ? themeColor.opacity(0.3) : themeColor.opacity(0.2)
        }
    }
    
    // Metin rengi - Görsel tasarıma uygun modern tema 
    private func getTextColor() -> Color {
        // Ana tema rengi: Teal (turkuaz) - ipucu için mavi renk
        _ = Color.teal
        
        // Hatalı giriş için kırmızı metin
        if isInvalid {
            return colorScheme == .dark ? Color.red : Color.red
        }
        else if isHintTarget {
            // İpucu hedefi - mavi (görseldeki gibi)
            return Color.blue
        } else if isFixed {
            // Sabit sayılar - standart siyah/beyaz (maksimum okunabilirlik)
            return colorScheme == .dark ? Color.white : Color.black
        } else if isUserEntered {
            // Kullanıcı girişleri - daha belirgin tema rengi
            // Daha koyu ve belirgin renkler kullanarak ayrım sağlama
            return colorScheme == .dark ? Color.cyan : Color.blue
        } else {
            // Diğer metinler - gri
            return colorScheme == .dark ? Color.gray : Color.gray
        }
    }
    
    // Hatalı hücre göstergesi - ayrı bir görünüm olarak optimize edildi
    private var invalidCellOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.red, lineWidth: 2.5)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
                
            // Hata animasyonu - güç tasarrufu modunda animasyonu kapat
            if !powerManager.isPowerSavingEnabled {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 2.5)
                    .opacity(animateValue ? 0.2 : 0.7)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true),
                        value: animateValue
                    )
                    .onAppear {
                        animateValue = true
                    }
            }
        }
    }
    
    // Hücre içeriği - sadece gerekli olduğunda çizilir
    private func cellContent(cellDimension: CGFloat) -> some View {
        ZStack {
            // Değer gösterimi
            if let value = value {
                Text("\(value)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(getTextColor())
            }
            
            // Pencil marks - sadece varsa çiz
            else if !pencilMarks.isEmpty {
                PencilMarksViewOptimized(pencilMarks: pencilMarks)
                    .frame(width: cellDimension * 0.85, height: cellDimension * 0.85)
                    .clipped()
            }
            
            // Vurgulama - ipucu için - sadece ipucu hedefiyse çiz
            if isHintTarget {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.green.opacity(0.8), lineWidth: 3)
                    .frame(width: cellDimension * 0.9, height: cellDimension * 0.9)
            }
        }
        // Sabit boyut - bu frame değişmez
        .frame(width: cellDimension, height: cellDimension)
        // Tüm içeriğin kırpılmasını zorunlu kıl
        .clipped()
        // Tüm animasyonları devre dışı bırakalım
        .animation(.none, value: value)
        .animation(.none, value: pencilMarks)
    }
}

// Preview Provider
struct SudokuCellView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HStack {
                SudokuCellView(row: 0, column: 0, value: 5, isFixed: true, isUserEntered: false, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [], isHintTarget: false, onCellTapped: {})
                SudokuCellView(row: 0, column: 1, value: 3, isFixed: false, isUserEntered: true, isSelected: true, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [], isHintTarget: false, onCellTapped: {})
                SudokuCellView(row: 0, column: 2, value: 8, isFixed: false, isUserEntered: true, isSelected: false, isHighlighted: true, isMatchingValue: false, isInvalid: false, pencilMarks: [], isHintTarget: false, onCellTapped: {})
            }
            HStack {
                SudokuCellView(row: 1, column: 0, value: 5, isFixed: false, isUserEntered: true, isSelected: false, isHighlighted: false, isMatchingValue: true, isInvalid: false, pencilMarks: [], isHintTarget: false, onCellTapped: {})
                SudokuCellView(row: 1, column: 1, value: 4, isFixed: false, isUserEntered: true, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: true, pencilMarks: [], isHintTarget: false, onCellTapped: {})
                SudokuCellView(row: 1, column: 2, value: nil, isFixed: false, isUserEntered: false, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [1, 2, 5], isHintTarget: false, onCellTapped: {})
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

// Optimize edilmiş pencil marks görünümü
struct PencilMarksViewOptimized: View {
    let pencilMarks: Set<Int>
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 3
            let cellHeight = geometry.size.height / 3
            
            // Tek bir ZStack içinde tüm rakamları çiz
            ZStack(alignment: .topLeading) {
                ForEach(Array(pencilMarks), id: \.self) { mark in
                    // Hücre içinde doğru konumlandırmak için indeks hesapla
                    let index = mark - 1
                    let row = index / 3
                    let col = index % 3
                    
                    Text("\(mark)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: cellWidth, height: cellHeight)
                        .position(
                            x: cellWidth * CGFloat(col) + cellWidth / 2,
                            y: cellHeight * CGFloat(row) + cellHeight / 2
                        )
                }
            }
            // Metal hızlandırması
            .drawingGroup(opaque: true, colorMode: .linear)
        }
    }
}