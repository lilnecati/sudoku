//  NumberPadView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//


import SwiftUI
import AudioToolbox
import AVFoundation

struct NumberPadView: View {
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("enableNumberInputHaptic") private var enableNumberInputHaptic = true
    @ObservedObject var viewModel: SudokuViewModel
    var isEnabled: Bool
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Sabit değerler
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Önbelleğe alınmış renkler
    private let disabledOpacity: Double = 0.5
    
    // Sayı butonları için renk alıcı fonksiyon - bej mod desteği için
    private func getButtonColor(for number: Int) -> Color {
        if isBejMode {
            // Bej mod renkleri - daha yumuşak, toprak tonları
            switch number {
            case 1: return Color(red: 0.5, green: 0.3, blue: 0.1) // Kahverengi-turuncu
            case 2: return Color(red: 0.6, green: 0.4, blue: 0.2) // Açık kahve
            case 3: return Color(red: 0.7, green: 0.5, blue: 0.3) // Toprak rengi
            case 4: return Color(red: 0.4, green: 0.5, blue: 0.2) // Yeşilimsi kahve
            case 5: return Color(red: 0.6, green: 0.5, blue: 0.3) // Bej
            case 6: return Color(red: 0.7, green: 0.4, blue: 0.1) // Turuncu-kahve
            case 7: return Color(red: 0.6, green: 0.3, blue: 0.2) // Kiremit
            case 8: return Color(red: 0.5, green: 0.2, blue: 0.1) // Kızıl kahve
            case 9: return Color(red: 0.4, green: 0.4, blue: 0.3) // Koyu bej
            default: return ThemeManager.BejThemeColors.accent
            }
        } else {
            // Normal mod için standart renkler
            switch number {
            case 1: return .blue
            case 2: return .indigo
            case 3: return .purple
            case 4: return .green
            case 5: return .mint
            case 6: return .orange
            case 7: return .pink
            case 8: return .red
            case 9: return .cyan
            default: return .blue
            }
        }
    }
    
    var body: some View {
        // Sabit boyutlu tuş takımı konteynerı
        GeometryReader { geometry in
            // Kesin boyutlarla çalış
            let containerWidth = geometry.size.width
            
            VStack(spacing: 10) {
                // Numara tuşları - sabit boyutlu grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...9, id: \.self) { number in
                        // Numaralı tuşlar - sabit boyutlu
                        numberButton(for: number)
                            .equatable(by: number) // Sadece değer değiştiğinde yeniden render et
                            // Boyut stabilitesi için
                            .contentShape(Rectangle())
                            // Kalem moduna geçişlerde boyut değişimini önle
                            .id("numBtn_\(number)")
                    }
                    
                    // Silme tuşu (Kalem modu yerine taşındı)
                    eraseButton
                        .equatable(by: true) // Sabit tutum için her zaman aynı
                        // Boyut stabilitesi için
                        .contentShape(Rectangle())
                        
                    // Kullanıcı görünmeyecek boş bir öğe (düzen korunması için)
                    // Not: Pencil modu kaldırıldı
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: 10)
                        .opacity(0)
                }
                .padding(.vertical, 5)
            }
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5)))
            )
            // Sabit maksimum genişlik
            .frame(width: containerWidth)
            // Ek stabilite önlemleri
            .fixedSize(horizontal: false, vertical: true)
            // Boyut değişikliği yok
            .drawingGroup() // GPU hızlandırma ile render
        }
        .opacity(isEnabled ? 1.0 : disabledOpacity)
        // Sadece opaklık için animasyon - boyut animasyonu olmasın
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
    
    // Rakam tuşu - optimize edilmiş
    private func numberButton(for number: Int) -> some View {
        // Sadece gerekli değerleri hesapla - görünüm optimizasyonu için
        let remaining = 9 - (viewModel.usedNumbers[number] ?? 0)
        let isDisabled = (remaining <= 0 && !viewModel.pencilMode) || !isEnabled
        let buttonColor = getButtonColor(for: number)
        @State var isPressed = false
        
        return Button(action: {
            // 1. ÖNCE SAYIYI GİR (en önemli işlem)
            viewModel.setValueAtSelectedCell(number)
            
            // 2. HIZLI ANİMASYON EFEKT
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            
            // 3. EN SON SES EFEKT (arka planda)
            DispatchQueue.global(qos: .userInitiated).async {
                SoundManager.shared.playNumberInputSoundOptimized()
            }
            
            // Tuş etkisini geri çek
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            // Sabit boyutlu dış konteyner
            ZStack {
                // Boş sabit arka plan - boyut stabilizasyonu için
                RoundedRectangle(cornerRadius: 10)
                    .fill(buttonColor.opacity(isDisabled ? 0.05 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(buttonColor.opacity(isDisabled ? 0.15 : 0.3), lineWidth: 1)
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .shadow(color: buttonColor.opacity(isDisabled ? 0 : 0.3), radius: isPressed ? 1 : 3, x: 0, y: isPressed ? 1 : 2)
                
                // İçerik alanı - sabit ayarlanmış
                VStack(spacing: 2) {
                    // Ana numara - her zaman görünür
                    Text("\(number)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(isDisabled ? buttonColor.opacity(0.3) : buttonColor)
                        .dynamicTypeSize(.medium)
                    
                    // İkinci satır için SABIT BOYUTLU placeholder - her zaman aynı boyutta
                    ZStack {
                        // Sayı/kalem ikonu için görünmez yer tutucu - her zaman yer kaplar
                        Text("0")
                            .font(.system(size: 12))
                            .foregroundColor(.clear)
                            .dynamicTypeSize(.medium)
                        
                        // İçerik - sadece kalan sayı gösterilecek, kalem modu ipucu kaldırıldı
                        if remaining < 9 {
                            Text("\(remaining)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(buttonColor.opacity(0.6))
                                .transition(.opacity.combined(with: .scale))
                                .id("remaining_\(number)_\(remaining)")
                                .dynamicTypeSize(.medium)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Ana içerik için sabit boyut
                .padding(.vertical, 8)
            }
            // Kesin görünüm boyutları - değişmeyen
            .aspectRatio(0.75, contentMode: .fill)
            // Taşma olmasın
            .clipped()
            // Görünüm stabilitesi için sabit boyutlu konteyner
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
        // Sabit ID - pencilMode durumunu ID'den çıkardım, böylece layout kimliği değişmiyor
        .id("numberBtn_\(number)")
        // Kalem modu değişikliğinde hafif animasyon
        .animation(.easeInOut(duration: 0.2), value: viewModel.pencilMode)
    }
    
    // Kalem modu tuşu - sabit boyutla optimize edilmiş
    private var pencilModeButton: some View {
        let buttonColor: Color = viewModel.pencilMode ? .purple : .gray
        @State var isPressed = false
        
        return Button(action: {
            // 1. ÖNCE KALEM MODUNU DEĞİŞTİR
            viewModel.pencilMode.toggle()
            
            // 2. HIZLI ANİMASYON EFEKT
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            
            // 3. EN SON SES EFEKT (arka planda)
            DispatchQueue.global(qos: .userInitiated).async {
                SoundManager.shared.playNavigationSoundOptimized()
            }
            
            // Tuş etkisini geri çek
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            // Sabit boyutlu dış konteyner
            ZStack {
                // Sabit boyutlu arka plan
                RoundedRectangle(cornerRadius: 10)
                    .fill(buttonColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(buttonColor.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                // İçerik alanı
                VStack(spacing: 2) {
                    // Ana ikon - her zaman görünür
                    Image(systemName: viewModel.pencilMode ? "pencil.circle.fill" : "pencil")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(buttonColor)
                    
                    // Sabit boyutlu metin - her zaman aynı boyutta
                    ZStack {
                        // Yer tutucu - görünmeyen ama yer kaplayan
                        Text("Not Modu")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.clear)
                        
                        // Gerçek metin
                        Text(viewModel.pencilMode ? 
                             NSLocalizedString("Not Aktif", comment: "Pencil mode active") : 
                             NSLocalizedString("Not Modu", comment: "Pencil mode button"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(buttonColor.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 8)
            }
            // Kesin görünüm boyutları - değişmeyen
            .aspectRatio(0.75, contentMode: .fill)
            // Taşma olmasın
            .clipped()
            // Görünüm stabilitesi
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : disabledOpacity)
        // Her durumda aynı ID
        .id("pencilBtn")
        // Boyut animasyonu yok
        .animation(nil, value: viewModel.pencilMode)
    }
    
    // Silme tuşu - sabit boyutla optimize edilmiş
    private var eraseButton: some View {
        // Bej mod renkleri için
        let buttonColor: Color = isBejMode ? ThemeManager.BejThemeColors.accent : .red
        let isDisabled = !isEnabled || viewModel.selectedCell == nil
        @State var isPressed = false
        
        return Button(action: {
            // 1. ÖNCE SİLME İŞLEMİNİ YAP
            viewModel.setValueAtSelectedCell(nil)
            
            // 2. HIZLI ANİMASYON EFEKT
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            
            // 3. EN SON SES EFEKT (arka planda)
            DispatchQueue.global(qos: .userInitiated).async {
                SoundManager.shared.playEraseSoundOptimized()
            }
            
            // Tuş etkisini geri çek
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            // Sabit boyutlu dış konteyner
            ZStack {
                // Sabit boyutlu arka plan
                RoundedRectangle(cornerRadius: 10)
                    .fill(buttonColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(buttonColor.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                // İçerik alanı
                VStack(spacing: 2) {
                    // Ana ikon - her zaman görünür
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isDisabled ? buttonColor.opacity(0.3) : buttonColor)
                        .dynamicTypeSize(.medium)
                    
                    // Sabit boyutlu metin - her zaman aynı boyutta
                    Text("Sil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDisabled ? buttonColor.opacity(0.3) : buttonColor.opacity(0.8))
                        .dynamicTypeSize(.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 8)
            }
            // Kesin görünüm boyutları - değişmeyen
            .aspectRatio(0.75, contentMode: .fill)
            // Taşma olmasın
            .clipped()
            // Görünüm stabilitesi
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
        // Kalem modu değişimlerinde boyutu korumak için sabit ID
        .id("eraseBtn")
        // Boyut animasyonu yok
        .animation(nil, value: viewModel.pencilMode)
    }
}

// Performans optimizasyonu için Equatable protokolü genişletmesi
extension View {
    func equatable<Value>(by value: Value) -> some View where Value: Equatable & Hashable {
        self.equatable()
            .id(value)
            .animation(nil, value: value)
    }
}

// MARK: - Equatable
struct ButtonID: Hashable {}

extension View {
    func equatable() -> some View {
        EquatableView(content: self)
    }
}

// Eşitlik kontrolü için helper yapı
struct EquatableView<Content: View>: View {
    let content: Content
    
    var body: some View {
        content
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return true
    }
} 