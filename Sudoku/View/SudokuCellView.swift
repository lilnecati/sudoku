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
    
    // Yeni animasyon durumları
    @State private var shakeAmount = 0.0
    @State private var lastInvalidState = false
    @State private var highlightOpacity = 0.0  // Renk vurgu animasyonu için
    
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
                
                // Hatalı giriş renk vurgusu (pulse)
                if isInvalid {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(isBejMode ? ThemeManager.BejThemeColors.boardColors.red : Color.red)
                        .opacity(highlightOpacity)
                }
                
                // Sayı veya Notlar (cellDimension geçirildi)
                cellContentView(cellDimension: cellDimension)
            }
            .aspectRatio(1, contentMode: .fit)
            .modifier(ShakeEffect(animatableData: shakeAmount))
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
            .onAppear(perform: checkInvalid)
            .onChange(of: isInvalid) { _, newValue in
                if newValue && !lastInvalidState {
                    lastInvalidState = true
                    triggerShakeAnimation()
                } else if !newValue {
                    lastInvalidState = false
                }
            }
        }
    }
    
    private func triggerShakeAnimation() {
        if enableHapticFeedback {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
            highlightOpacity = 0.5
        }
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.2, blendDuration: 0.2)) {
            shakeAmount = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) {
                shakeAmount = 0.0
                highlightOpacity = 0.0
            }
        }
    }
    
    private func checkInvalid() {
        if isInvalid {
            lastInvalidState = true
            triggerShakeAnimation()
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
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)

            // Vurgulama arka planı (varsa)
            if let bgColor = highlightBackgroundColor {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(bgColor)
            }

            // Kenarlık
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    highlightBorderColor ?? standardBorderColor, 
                    lineWidth: highlightBorderColor != nil ? 
                               (interactionType == .highlight || isMatchingValue ? 3.0 : 2.0) : 1.0,
                    antialiased: true
                )

            // Hedef Hücre Parlama Animasyonu
            if interactionType == .target {
                TargetHighlightGlow(color: getHighlightBorderColor(for: .target) ?? .orange)
                    .cornerRadius(cornerRadius)
            }
        }
    }
    
    // Hücre içeriği - sadece gerekli olduğunda çizilir
    private func cellContentView(cellDimension: CGFloat) -> some View {
        ZStack {
            // Değer gösterimi
            if let value = value {
                Text("\(value)")
                    .font(.system(
                        size: isUserEntered ? 28 : (isInvalid ? 30 : 26), // Kullanıcı girişlerini biraz küçülttük
                        weight: isUserEntered ? .bold : (isInvalid ? .heavy : .semibold), // Kullanıcı girişlerinin kalınlığını azalttık
                        design: .default
                    ))
                    .foregroundColor(getTextColor())
                    .shadow(
                        color: isInvalid ? Color.black.opacity(0.2) : (isUserEntered ? Color.black.opacity(0.15) : Color.black.opacity(0.08)), 
                        radius: isInvalid ? 1.2 : (isUserEntered ? 1.0 : 0.8),
                        x: 0, 
                        y: isInvalid ? 1.0 : (isUserEntered ? 0.8 : 0.5)
                    )
            }
            
            // Pencil marks - sadece varsa çiz
            else if !pencilMarks.isEmpty {
                PencilMarksViewOptimized(pencilMarks: pencilMarks)
                    .frame(width: cellDimension * 0.9, height: cellDimension * 0.9)
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
            // Koyu mod için de renkleri açık hale getir
            opacity = isBejMode ? (type == .highlight ? 0.30 : 0.18) : (effectiveColorScheme == .dark ? (type == .highlight ? 0.25 : 0.15) : (type == .highlight ? 0.30 : 0.18))
        case .conflict:
            colorName = "red" // Kırmızı
            // Yanlış girişi daha belirgin yap
            opacity = isBejMode ? 0.35 : (effectiveColorScheme == .dark ? 0.50 : 0.35)
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
        // related ve highlight için themeManager.sudokuBoardColor kullanılıordu,
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
            return themeManager.getBoardColor().opacity(opacity * 0.9)
        case .highlight:
            return themeManager.getBoardColor().opacity(opacity)
        case .conflict:
            // Hata durumunda daha parlak ve belirgin bir kenarlık
            return (isBejMode ? ThemeManager.BejThemeColors.boardColors.red : Color.red).opacity(1.0)
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
                return ThemeManager.BejThemeColors.boardColors.red.opacity(1.0) // Tam opak, daha parlak
            }
            
            // Sabit değer (tahta tarafından üretilen)
            if isFixed {
                return ThemeManager.BejThemeColors.text
            }
            
            // Kullanıcı tarafından girilen değer
            if isUserEntered {
                // İpucu olarak girilen değer için özel renk
                if isHintEntered {
                    return ThemeManager.BejThemeColors.boardColors.green
                }
                return themeColor
            }
            
            // Herhangi bir durum belirtilmemiş
            return ThemeManager.BejThemeColors.text
        } else {
            // Normal tema:
            // Hatalı giriş için kırmızı metin
            if isInvalid {
                return Color.red.opacity(1.0) // Tam opak, daha parlak
            }
            
            // Sabit değer (tahta tarafından üretilen)
            if isFixed {
                return effectiveColorScheme == .dark ? .white : .black
            }
            
            // Kullanıcı tarafından girilen değer
            if isUserEntered {
                // İpucu olarak girilen değer için özel renk
                if isHintEntered {
                    return Color.green
                }
                return themeColor
            }
            
            // Herhangi bir durum belirtilmemiş
            return effectiveColorScheme == .dark ? .white : .black
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

// Sallama efekti için yapı
struct ShakeEffect: GeometryEffect {
    var animatableData: Double
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        // Eğer animasyon verisi 0 ise, herhangi bir efekt uygulamayalım
        guard animatableData > 0 else { 
            return ProjectionTransform(.identity)
        }
        
        // Daha doğal ve yumuşak bir sallanma eğrisi
        let wiggleX = sin(animatableData * .pi * 2.5) * max(0, (1 - animatableData))
        
        // Şiddet - akıcı hissi için daha küçük bir değer
        let magnitude: CGFloat = 7
        
        // Yatay sallamayı hesapla
        let translation = CGAffineTransform(translationX: wiggleX * magnitude, y: 0)
        
        return ProjectionTransform(translation)
    }
}

// Yeni: Hedef hücre parlama animasyonu - ayrı dosyada tanımlandı
// struct TargetHighlightGlow: View {
//    let color: Color
//    @State private var isAnimating = false
//    @State private var pulse = false
//    @StateObject private var powerManager = PowerSavingManager.shared // PowerManager eklendi
//
//    var body: some View {
//        ZStack {
//            // Ana parlama efekti
//            RoundedRectangle(cornerRadius: 16) // Ana ZStack'teki ile aynı cornerRadius olmalı
//                .stroke(color, lineWidth: 3.5)
//                .scaleEffect(isAnimating ? 1.2 : 1.0)
//                .opacity(isAnimating ? 0.0 : 0.7)
//                .blur(radius: isAnimating ? 6 : 0)
//                .animation(
//                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
//                    value: isAnimating
//                )
//            
//            // İkincil nabız efekti
//            RoundedRectangle(cornerRadius: 16)
//                .stroke(color, lineWidth: 2.5)
//                .scaleEffect(pulse ? 1.1 : 0.97)
//                .opacity(pulse ? 0.4 : 0.8)
//                .blur(radius: pulse ? 3 : 0)
//                .animation(
//                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
//                    value: pulse
//                )
//        }
//        .onAppear {
//            // Güç tasarrufu modu kontrolü
//            if !powerManager.isPowerSavingEnabled {
//                 isAnimating = true
//                 pulse = true
//            }
//        }
//        // Güç tasarrufu modu değiştiğinde animasyonu durdur/başlat
//        .onChange(of: powerManager.isPowerSavingEnabled) { _, newValue in
//             if newValue {
//                 isAnimating = false // Durdur
//                 pulse = false
//             } else {
//                 isAnimating = true // Başlat
//                 pulse = true
//             }
//        }
//    }
//}
