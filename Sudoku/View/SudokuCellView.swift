//  SudokuCellView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 08.12.2024.
//

import SwiftUI

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
            Button(action: {
                // Hücre seçildiğinde titreşim geri bildirimi - ayarlara bağlı
                if enableHapticFeedback && enableCellTapHaptic {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                }
                
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
                    // Hücre arka planı
                    cellBackground
                        .scaleEffect(animateSelection ? 0.95 : 1.0)
                        .drawingGroup() // Metal hızlandırması
                    
                    // Hatalı hücre göstergesi
                    if isInvalid {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red, lineWidth: 2)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(4)
                            .drawingGroup() // Metal hızlandırması
                    }
                    
                    // Hücre içeriği (sayı veya kalem işaretleri)
                    // Sabit boyutlu konteyner - bütün içerik için sabit çerçeve
                    ZStack {
                        // İçerik bölgesini sabit tutacak temel çerçeve
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: min(geometry.size.width, geometry.size.height),
                                   height: min(geometry.size.width, geometry.size.height))
                        
                        if let value = value {
                            // Ana değer - sabit boyuta sahip bir ZStack içinde
                            ZStack {
                                Text("\(value)")
                                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.6))
                                    .fontWeight(isFixed ? .bold : (isUserEntered ? .bold : .medium))
                                    .foregroundColor(getTextColor())
                                    .scaleEffect(animateValue ? 1.3 : 1.0)
                                    .opacity(animateValue ? 0.7 : 1.0)
                                    .shadow(color: animateValue && !isFixed ? Color.blue.opacity(0.4) : Color.clear, radius: animateValue ? 4 : 0)
                                    .id("cell_\(row)_\(column)_\(value)")
                                    .onChange(of: value) { oldValue, newValue in
                                        // Güç tasarrufu modunda değilse ve değer değiştiyse animasyon göster
                                        if !isFixed && !powerManager.isPowerSavingEnabled && oldValue != newValue {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                animateValue = true
                                            }
                                            
                                            // Animasyonu sıfırla
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                withAnimation {
                                                    animateValue = false
                                                }
                                            }
                                        }
                                    }
                            }
                            // Sayı için sabit boyut konteynerı
                            .frame(width: min(geometry.size.width, geometry.size.height),
                                   height: min(geometry.size.width, geometry.size.height))
                            // Kesin boyut için kırpılma
                            .clipped()
                            // Geçiş animasyonu yerine sabit kal
                            .transition(.identity)
                        } else if !pencilMarks.isEmpty {
                            // Kalem işaretleri (küçük notlar) - sabit boyutta
                            PencilMarksView(
                                pencilMarks: pencilMarks,
                                cellSize: min(geometry.size.width, geometry.size.height)
                            )
                            // Kalem notu konteynerı - sabit boyutta ve kırpılmış
                            .frame(width: min(geometry.size.width, geometry.size.height),
                                   height: min(geometry.size.width, geometry.size.height))
                            .clipped() // Taşmaları önle
                            // Geçiş animasyonu yerine sabit kal
                            .transition(.identity)
                            .onChange(of: pencilMarks) { oldMarks, newMarks in
                                if !powerManager.isPowerSavingEnabled && oldMarks != newMarks {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        animateValue = true
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation {
                                            animateValue = false
                                        }
                                    }
                                }
                            }
                        } else {
                            // Boş durumda da aynı boyutu koruyacak görünmez placeholder
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: min(geometry.size.width, geometry.size.height),
                                       height: min(geometry.size.width, geometry.size.height))
                        }
                    }
                    // Sabit boyut - bu frame değişmez
                    .frame(width: min(geometry.size.width, geometry.size.height),
                           height: min(geometry.size.width, geometry.size.height))
                    // Tüm içeriğin kırpılmasını zorunlu kıl
                    .clipped()
                    // Düz bir geçiş kullan
                    .animation(.none, value: value)
                    .animation(.none, value: pencilMarks)
                }
                .drawingGroup() // Metal hızlandırması
            }
            .powerSavingAwareAnimation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    // Hücre arka planı
    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(getCellBackgroundColor())
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(getCellBorderColor(), lineWidth: isSelected ? 2 : (isMatchingValue ? 1.5 : 0.5))
            )
            .powerSavingAwareEffect(isEnabled: isSelected || isMatchingValue)
    }
    
    // Hücre arka plan rengi - Tek renk temali modern tasarım
    private func getCellBackgroundColor() -> Color {
        // Ana tema rengi: Teal (turkuaz) - ipucu için mavi renk
        let themeColor = Color.teal
        let hintColor = Color.blue
        
        // İpucu hedefiyse mavi renkle vurgula (görsellerdeki gibi)
        if isHintTarget {
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
        
        // İpucu hedefiyse daha koyu mavi kenarlık (görsellerdeki gibi)
        if isHintTarget {
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
        let themeColor = Color.teal
        
        if isHintTarget {
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
