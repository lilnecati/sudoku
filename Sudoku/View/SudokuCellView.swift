//  SudokuCellView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 08.12.2024.
//

import SwiftUI
import AudioToolbox
import AVFoundation

struct SudokuCellView: View {
    @EnvironmentObject var viewModel: SudokuViewModel
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
    let onCellTapped: () -> Void
    let isHintEntered: Bool
    let isHintTargetCell: Bool
    
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var powerManager = PowerSavingManager.shared
    @State private var animateSelection = false
    @State private var animateValue = false
    @State private var refreshID = UUID() // Yenileme için benzersiz ID
    
    // Bej mod kontrolü eklendi
    private var isBejMode: Bool {
        themeManager.bejMode
    }
    
    private var effectiveColorScheme: ColorScheme {
        return themeManager.colorScheme ?? .light
    }
    
    var body: some View {
        // GeometryReader eklendi
        GeometryReader { geometry in
            let cellDimension = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // Arka Plan ve Kenarlık (Yeni sistem)
                backgroundAndBorderView
                
                // Sayı veya Notlar (cellDimension geçirildi)
                cellContentView(cellDimension: cellDimension)
            }
            .aspectRatio(1, contentMode: .fit)
            .onTapGesture {
                onCellTapped()
                
                // Titreşim geri bildirimi
                if enableHapticFeedback && enableCellTapHaptic {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }
    
    // MARK: - Alt Görünümler
    
    // Yeni: Arka Plan ve Kenarlık Yönetimi
    @ViewBuilder
    private var backgroundAndBorderView: some View {
        let interactionType = getInteractionType() // İpucu etkileşim türünü al
        let baseBackgroundColor = getBaseBackgroundColor()
        let highlightBackgroundColor = getHighlightBackgroundColor(for: interactionType)
        let highlightBorderColor = getHighlightBorderColor(for: interactionType)
        let standardBorderColor = getStandardBorderColor()

        ZStack {
            // Temel arka plan rengi
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(baseBackgroundColor)

            // Vurgulama arka planı (varsa)
            if let bgColor = highlightBackgroundColor {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(bgColor)
            }

            // Kenarlık
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(highlightBorderColor ?? standardBorderColor, lineWidth: highlightBorderColor != nil ? 2.5 : 1.5) // Vurguluysa daha kalın

            // Hedef Hücre Parlama Animasyonu
            if interactionType == .target {
                TargetHighlightGlow(color: getHighlightBorderColor(for: .target) ?? .orange)
                    .cornerRadius(cornerRadius) // Köşeleri yuvarlat
            }
        }
    }
    
    // Hücre içeriği - sadece gerekli olduğunda çizilir
    private func cellContentView(cellDimension: CGFloat) -> some View {
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
        }
        // Sabit boyut - bu frame değişmez
        .frame(width: cellDimension, height: cellDimension)
        // Tüm içeriğin kırpılmasını zorunlu kıl
        .clipped()
        // Tüm animasyonları devre dışı bırakalım
        .animation(.none, value: value)
        .animation(.none, value: pencilMarks)
    }
    
    // MARK: - Yardımcı Fonksiyonlar (Yeni Renk Mantığı)

    // Hücrenin temel arka plan rengi (seçili veya vurgulu değilken)
    private func getBaseBackgroundColor() -> Color {
        if isBejMode {
            return ThemeManager.BejThemeColors.cardBackground
        } else {
            return effectiveColorScheme == .dark ? Color(.systemGray6) : Color.white
        }
    }

    // Mevcut etkileşim türünü belirle
    private func getInteractionType() -> SudokuViewModel.CellInteractionType? {
        // Not: Bu fonksiyonun SudokuViewModel'den gelen ipucu verisindeki
        // highlightedCells ile karşılaştırma yapması gerekecek. Şimdilik
        // mevcut isHighlighted gibi bool değerlere göre basitleştirildi.
        // Bu kısmın ViewModel entegrasyonu ile güncellenmesi gerekiyor.
        
        // ÖNCELİK: Eğer bu hücre ipucu hedefiyse, onu vurgula (seçili gibi)
        if isHintTargetCell {
            return .highlight // Veya .target istiyorsan değiştir
        }
        
        // İpucu aktif değilse veya bu hücre hedef değilse, normal kontroller
        // ViewModel'den ipucu verisi kontrolü (board view'da da yapılabilir)
        // guard viewModel.hintExplanationData == nil else { return nil } // Seçenek
        
        // Eski mantık (ipucu paneli kapalıysa veya ipucu verisi yoksa)
        if isSelected { return .highlight }
        if isMatchingValue { return .related }
        if isHighlighted { return .related } // Satır/Sütun highlight
        if isInvalid { return .conflict }
        
        return nil
    }
    
    // Etkileşim türüne göre vurgu arka plan rengi
    private func getHighlightBackgroundColor(for type: SudokuViewModel.CellInteractionType?) -> Color? {
        guard let type = type else { return nil }

        let colorName: String // Renk adı String olarak
        let opacity: Double

        switch type {
        case .target:
            colorName = "orange" // Turuncu
            opacity = isBejMode ? 0.25 : (effectiveColorScheme == .dark ? 0.45 : 0.25)
        case .related, .highlight: // related ve highlight için aynı renk
            colorName = themeManager.sudokuBoardColor // Ana tahta rengini kullan (String olarak)
            opacity = isBejMode ? (type == .highlight ? 0.20 : 0.15) : (effectiveColorScheme == .dark ? (type == .highlight ? 0.40 : 0.30) : (type == .highlight ? 0.20 : 0.15))
        case .conflict:
            colorName = "red" // Kırmızı
            opacity = isBejMode ? 0.25 : (effectiveColorScheme == .dark ? 0.40 : 0.25)
        case .candidate:
            colorName = "green" // Yeşil
             opacity = isBejMode ? 0.15 : (effectiveColorScheme == .dark ? 0.30 : 0.15)
        case .elimination:
             return nil
        }
        
        // colorName değişkenine göre doğru Color nesnesini al ve döndür
        let color: Color
        switch colorName {
        case "orange": color = isBejMode ? ThemeManager.BejThemeColors.boardColors.orange : Color.orange
        case "red": color = isBejMode ? ThemeManager.BejThemeColors.boardColors.red : Color.red
        case "green": color = isBejMode ? ThemeManager.BejThemeColors.boardColors.green : Color.green
        // related ve highlight için themeManager.sudokuBoardColor kullanılıyordu,
        // bu yüzden getBoardColor() çağrısını kullanıyoruz.
        default: color = themeManager.getBoardColor() 
        }
        return color.opacity(opacity)
    }

    // Etkileşim türüne göre vurgu kenarlık rengi
    private func getHighlightBorderColor(for type: SudokuViewModel.CellInteractionType?) -> Color? {
         guard let type = type else { return nil }

        let opacity: Double = isBejMode ? 1.0 : (effectiveColorScheme == .dark ? 1.0 : 0.8)

        switch type {
        case .target:
            return (isBejMode ? ThemeManager.BejThemeColors.boardColors.orange : Color.orange).opacity(opacity)
        case .related:
            return themeManager.getBoardColor().opacity(opacity)
        case .highlight:
            return themeManager.getBoardColor().opacity(opacity)
        case .conflict:
            return (isBejMode ? ThemeManager.BejThemeColors.boardColors.red : Color.red).opacity(opacity)
        case .candidate:
            return (isBejMode ? ThemeManager.BejThemeColors.boardColors.green : Color.green).opacity(opacity)
        case .elimination:
            return nil
        }
    }
    
    // Standart kenarlık rengi (vurgu olmadığında)
    private func getStandardBorderColor() -> Color {
        if isBejMode {
            return ThemeManager.BejThemeColors.text.opacity(0.3)
        } else {
            return effectiveColorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)
        }
    }

    // Metin rengi - Görsel tasarıma uygun modern tema 
    private func getTextColor() -> Color {
        // Bej mod kontrolü (Zaten yukarıda tanımlı)
        // let isBejMode = themeManager.bejMode 
        
        // ThemeManager'dan rengimizi alalım (Doğrudan ana rengi al)
        let themeColor = themeManager.getBoardColor() // String parametresiz versiyon ana rengi verir
        
        if isBejMode {
            // Hatalı giriş için kırmızı metin (bej uyumlu)
            if isInvalid {
                return Color(red: 0.75, green: 0.30, blue: 0.20) // Bej uyumlu kırmızı
            } else if isFixed {
                // Sabit sayılar
                return ThemeManager.BejThemeColors.text
            } else if isUserEntered {
                // İpucu ile girilmişse farklı renk
                if isHintEntered {
                    // Ana tema renginin daha parlak veya farklı bir tonu
                    return themeColor.opacity(1.0) // Tam opaklık veya Color.cyan gibi farklı bir renk
                } else {
                    // Normal kullanıcı girişi
                    return themeColor
                }
            } else {
                // Diğer metinler
                return ThemeManager.BejThemeColors.secondaryText
            }
        } else {
            // Normal tema renkleri (mevcut kod)
            // Hatalı giriş için kırmızı metin
            if isInvalid {
                return effectiveColorScheme == .dark ? Color.red : Color.red
            }
            else if isFixed {
                // Sabit sayılar - standart siyah/beyaz (maksimum okunabilirlik)
                return effectiveColorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.85) // Biraz daha soluk
            } else if isUserEntered {
                // Kullanıcı girişleri - daha belirgin tema rengi
                return effectiveColorScheme == .dark ? themeColor.opacity(0.95) : themeColor.opacity(0.90)
            } else {
                // Diğer metinler - gri (Boş hücreler için varsayılan)
                return effectiveColorScheme == .dark ? Color.gray.opacity(0.6) : Color.gray.opacity(0.6)
            }
        }
    }

    // Köşe yarıçapı (Mevcut kod korunuyor)
    private var cornerRadius: CGFloat {
        return 4
    }

    // Erişilebilirlik etiketi (Mevcut kod korunuyor)
    private var accessibilityLabel: String {
        var label = ""
        if let value = value {
            label += "\(value)"
        }
        if isFixed {
            label += " (Sabit)"
        }
        if isUserEntered {
            label += " (Kullanıcı Girişi)"
        }
        if isSelected {
            label += " (Seçili)"
        }
        if isHighlighted {
            label += " (Vurgulanmış)"
        }
        if isMatchingValue {
            label += " (Aynı Değerli)"
        }
        if isInvalid {
            label += " (Hatalı)"
        }
        return label
    }
}

// Preview Provider
struct SudokuCellView_Previews: PreviewProvider {
    // Preview için gerekli environment nesnelerini ekleyelim
    static let themeManager = ThemeManager()
    
    // ViewModel'i önceden yapılandır
    static var configuredViewModel: SudokuViewModel = {
        let viewModel = SudokuViewModel()
        let hintData = SudokuViewModel.HintData(row: 0, column: 2, value: 8, reason: "Test")
        // Preview için ipucu ile girilmiş hücre
        viewModel.setValueAtSelectedCell(5, at: 1, col: 0) // Önce normal değer gir
        viewModel.userEnteredValues[1][0] = false // Hint için userEntered false olmalı
        // Preview'da hint etkisini göstermek için doğrudan değeri yerleştirip userEntered'ı false yapalım
        viewModel.setValueAtSelectedCell(5, at: 1, col: 0) // Değeri tekrar yerleştir (öncesinde userEntered false yapıldı)
        
        // Diğer hint highlight'ları
        hintData.highlightCell(row: 0, column: 2, type: .target) 
        hintData.highlightCell(row: 0, column: 0, type: .related) // İlişkili
        hintData.highlightCell(row: 1, column: 1, type: .conflict) // Çakışma
        viewModel.hintExplanationData = hintData
        return viewModel
    }()
    
    // ViewModel artık state object değil, önceden yapılandırılmışı kullan
    static let viewModel = SudokuViewModel()
    
    static var previews: some View {
        // ViewModel'e basit bir ipucu verisi ekleyelim (Bu satırlar yukarı taşındı)
        // let hintData = SudokuViewModel.HintData(row: 0, column: 2, value: 8, reason: "Test")
        // ... hintData yapılandırması ...
        // viewModel.hintExplanationData = hintData
        
        VStack {
            HStack {
                // isHintTarget kaldırıldı, interactionType kullanılacak
                SudokuCellView(row: 0, column: 0, value: 5, isFixed: true, isUserEntered: false, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [], onCellTapped: {}, isHintEntered: false, isHintTargetCell: false)
                SudokuCellView(row: 0, column: 1, value: 3, isFixed: false, isUserEntered: true, isSelected: true, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [], onCellTapped: {}, isHintEntered: false, isHintTargetCell: false)
                SudokuCellView(row: 0, column: 2, value: 8, isFixed: false, isUserEntered: true, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [], onCellTapped: {}, isHintEntered: false, isHintTargetCell: false) // Hedef preview için
            }
            HStack {
                // Bu hücrenin hint ile girildiğini belirtelim (Preview için)
                SudokuCellView(row: 1, column: 0, value: 5, isFixed: false, isUserEntered: false, isSelected: false, isHighlighted: false, isMatchingValue: true, isInvalid: false, pencilMarks: [], onCellTapped: {}, isHintEntered: true, isHintTargetCell: false)
                SudokuCellView(row: 1, column: 1, value: 4, isFixed: false, isUserEntered: true, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: true, pencilMarks: [], onCellTapped: {}, isHintEntered: false, isHintTargetCell: false) // Çakışma preview için
                SudokuCellView(row: 1, column: 2, value: nil, isFixed: false, isUserEntered: false, isSelected: false, isHighlighted: false, isMatchingValue: false, isInvalid: false, pencilMarks: [1, 2, 5], onCellTapped: {}, isHintEntered: false, isHintTargetCell: false)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .environmentObject(themeManager) // ThemeManager'ı ekle
        .environmentObject(configuredViewModel) // Önceden yapılandırılmış ViewModel'i ekle
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
                // Arka plan çerçevesi - pencil marks olduğunu belirtmek için
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(4)
                
                ForEach(Array(pencilMarks).sorted(), id: \.self) { mark in
                    // Hücre içinde doğru konumlandırmak için indeks hesapla
                    let index = mark - 1
                    let row = index / 3
                    let col = index % 3
                    
                    Text("\(mark)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: cellWidth, height: cellHeight)
                        .background(Color.clear)
                        .position(
                            x: cellWidth * CGFloat(col) + cellWidth / 2,
                            y: cellHeight * CGFloat(row) + cellHeight / 2
                        )
                }
            }
            // Metal hızlandırması (canlılık için opaque false)
            .drawingGroup(opaque: false, colorMode: .linear)
        }
    }
}

// Yeni: Hedef hücre parlama animasyonu
struct TargetHighlightGlow: View {
    let color: Color
    @State private var isAnimating = false
    @StateObject private var powerManager = PowerSavingManager.shared // PowerManager eklendi

    var body: some View {
        RoundedRectangle(cornerRadius: 8) // Ana ZStack'teki ile aynı cornerRadius olmalı
            .stroke(color, lineWidth: 3)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.0 : 0.6)
            .animation(
                Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                // Güç tasarrufu modu kontrolü
                if !powerManager.isPowerSavingEnabled {
                     isAnimating = true
                }
            }
            // Güç tasarrufu modu değiştiğinde animasyonu durdur/başlat
            .onChange(of: powerManager.isPowerSavingEnabled) { _, newValue in
                 if newValue {
                     isAnimating = false // Durdur
                 } else {
                     isAnimating = true // Başlat
                 }
            }
    }
}
