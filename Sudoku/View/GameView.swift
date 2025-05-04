//  GameView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI
import CoreData
import UIKit
import AudioToolbox
import AVFoundation

// Not: HideNavigationBar ViewModifier'a artık ihtiyaç yok çünkü fullScreenCover kullanıyoruz

struct GameView: View {
    @StateObject var viewModel: SudokuViewModel
    @State private var showDifficultyPicker = false
    @State private var showingGameComplete = false
    @State private var showSettings = false
    // Geri butonu için state'e gerek yok
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.textScale) var textScale
    
    // ThemeManager'a erişim
    @EnvironmentObject var themeManager: ThemeManager
    
    // Önbellekleme ve performans için
    @State private var timeDisplay: String = "00:00"
    @State private var boardKey = UUID().uuidString // Zorla tahtayı yenilemek için
    private let timerUpdateInterval: TimeInterval = 1.0
    
    // Premium ve ipucu ayarları
    @AppStorage("isPremiumUnlocked") private var isPremiumUnlocked: Bool = false
    
    // Titreşim ayarları
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("enableNumberInputHaptic") private var enableNumberInputHaptic: Bool = true
    
    // Hint messages
    @State private var showNoHintsMessage: Bool = false
    
    // Animasyon değişkenleri
    @State private var isHeaderVisible = false
    @State private var isBoardVisible = false
    @State private var isControlsVisible = false
    
    // Rehber butonu
    // if showTutorialButton && !tutorialManager.hasCompletedTutorial {
    //     HStack {
    //         Spacer()
    //         TutorialButton {
    //             tutorialManager.startTutorial()
    //         }
    //         .transition(.scale.combined(with: .opacity))
    //     }
    //     .padding(.horizontal)
    // }
    
    // Arka plan gradient renkleri - önbelleklenmiş
    private var gradientColors: [Color] {
        colorScheme == .dark ?
        [Color(.systemGray6), Color.blue.opacity(0.15)] :
        [Color(.systemBackground), Color.blue.opacity(0.05)]
    }
    
    // Ek çıkarım değişkenleri
    @State private var safeBottomPadding: CGFloat = 0
    
    // Zorluk renkleri önbelleği
    private let difficultyColors: [SudokuBoard.Difficulty: Color] = [
        .easy: .green,
        .medium: .blue,
        .hard: .orange,
        .expert: .red
    ]
    
    // Yeni oyun başlatma
    init(difficulty: SudokuBoard.Difficulty = .easy) {
        _viewModel = StateObject(wrappedValue: SudokuViewModel(difficulty: difficulty))
    }
    
    // Kaydedilmiş oyundan başlatma
    init(savedGame: NSManagedObject) {
        let vm = SudokuViewModel()
        
        // Kaydedilmiş oyunu yükle
        vm.loadGame(from: savedGame)
        
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    // Var olan viewModel ile başlatma
    init(existingViewModel: SudokuViewModel) {
        _viewModel = StateObject(wrappedValue: existingViewModel)
        
        // Navigation bar'ı gizlemek için bildirim gönder
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("HideNavigationBar"), object: nil)
        }
    }
    
    @State private var showCompletionView = false
    
    var body: some View {
        ZStack {
            // Arka plan
            GridBackgroundView()
                .ignoresSafeArea()
            
            // Ana içerik
            VStack(spacing: 0) {
                if isHeaderVisible {
                    headerView
                        .padding(.horizontal)
                        .padding(.top, 15)
                        .padding(.bottom, 5)
                        .transition(.opacity)
                }
                
                // Oyun tahtası
                if isBoardVisible {
                    ZStack {
                        // Yükleme göstergesi
                        if viewModel.isLoading {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                
                                Text(LocalizationManager.shared.localizedString(for: "Oyun hazırlanıyor..."))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            )
                            .padding()
                            .transition(.opacity)
                        }
                        
                        // Sudoku tahtası
                        SudokuBoardView(viewModel: viewModel)
                            .id(boardKey) // Tahtayı zorla yenilemek için id gerek
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.width * 0.95)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                            .disabled(viewModel.gameState == .failed || viewModel.gameState == .completed || showDifficultyPicker || viewModel.isLoading)
                            // Metal ile hızlandırılmış render
                            .drawingGroup()
                            .opacity(viewModel.isLoading ? 0 : 1) // Yükleme sırasında şeffaf
                    }
                }
                
                // Kontroller
                if isControlsVisible {
                    controlsView
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, safeBottomPadding + 10)
                        .transition(.opacity)
                }
            }
            
            // YENİ: Overlay Katmanı (İpucu, Zorluk Seçici, Oyun Sonu vs.)
            .overlay(alignment: .bottom) { // İpucu panelini alttan hizala
                ZStack(alignment: .bottom) { // Overlay içinde ZStack
                    // İpucu Açıklama Paneli
                    if viewModel.showHintExplanation {
                        HintExplanationView(viewModel: viewModel)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Zorluk Seçici (Ortada)
                    if showDifficultyPicker {
                        // Arka plan karartması
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture { showDifficultyPicker = false }
                            .zIndex(5) // Diğer overlay'lerin altında

                        difficultyPickerView
                            .zIndex(10)
                            .alignmentGuide(.bottom) { $0[.bottom] } // Ortalama için
                    }

                    // Tebrikler Ekranı (Ortada)
                    if showingGameComplete {
                        Color.black.opacity(0.7)
                            .edgesIgnoringSafeArea(.all)
                            .zIndex(5)
                        congratulationsView
                            .zIndex(10)
                            .alignmentGuide(.bottom) { $0[.bottom] }
                    }

                    // Oyun Bitti Ekranı (Ortada)
                    if viewModel.gameState == .failed {
                        Color.black.opacity(0.7)
                            .edgesIgnoringSafeArea(.all)
                            .zIndex(5)
                        gameOverView
                            .zIndex(10)
                            .alignmentGuide(.bottom) { $0[.bottom] }
                    }

                    // İpucu Yok Mesajı (Altta)
                    if showNoHintsMessage {
                        VStack {
                            Spacer()
                            Text("Her oyunda yalnızca 3 ipucu kullanabilirsiniz!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.orange.opacity(0.9))
                                )
                                .padding(.bottom, safeBottomPadding + 10) // NumberPad'in üstüne gelmesin
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        .zIndex(100) // En üstte
                    }
                }
                .animation(.easeInOut, value: showNoHintsMessage) // Mesaj animasyonu
                .animation(.easeInOut, value: showingGameComplete) // Tebrik animasyonu
                .animation(.easeInOut, value: viewModel.gameState == .failed) // Oyun Bitti animasyonu
                .animation(.easeInOut, value: showDifficultyPicker) // Zorluk seçici animasyonu
            }
        }
        // SafeArea hesaplaması ekleyerek çalışması sağlandı
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear {
                    // Alt safe area boşluğunu hesapla
                    safeBottomPadding = proxy.safeAreaInsets.bottom
                }
            }
        )
        // Artık HideNavigationBar modifier'a ihtiyaç yok, fullScreenCover kullanıyoruz
        .onAppear {
            setupInitialAnimations()
            setupTimerUpdater()
            
            // Ekranın kapanmasını engelle
            UIApplication.shared.isIdleTimerDisabled = true
            logInfo("🔆 GameView onAppear - Ekran kararması engellendi (ayarlandı: true)")
        }
        .onDisappear {
            // Ekranın kapanması engelini kaldır
            UIApplication.shared.isIdleTimerDisabled = false
            logInfo("🔅 GameView onDisappear - Ekran kararması etkinleştirildi (ayarlandı: false)")
            
            // Zamanlayıcıyı temizle
            viewModel.stopTimer()
        }
        .onChange(of: viewModel.gameState) { oldValue, newValue in
            if newValue == .completed && oldValue != .completed {
                // Oyun tamamlandığında tebrik ekranını göster
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingGameComplete = true
                }
            }
            
            if newValue == .failed && oldValue != .failed {
                // Oyun kaybedildiğinde kaybedildi ekranı otomatik gösterilir
                // GameView.swift viewModel.gameState == .failed koşulunu zaten izliyor
            }
        }
        // Modern navigasyon çubuğu gizleme
        .toolbar(.hidden, for: .navigationBar)
        .toolbarRole(.navigationStack)
        .preferredColorScheme(themeManager.colorScheme)
        .onChange(of: themeManager.darkMode) { _, _ in
            // Tema değiştiğinde tahtayı zorla yenile
            boardKey = UUID().uuidString
        }
        .onChange(of: themeManager.useSystemAppearance) { _, _ in
            // Sistem görünümü değiştiğinde tahtayı zorla yenile
            boardKey = UUID().uuidString
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(themeManager)
        }
        // Onay iletişim kutusuna gerek yok, otomatik kayıt var
    }
    
    // MARK: - Bileşen Özellikleri
    
    // Üst bilgi alanı - performans için önbelleklenmiş
    private var headerView: some View {
        VStack(spacing: 5) {
            HStack {
                // Geri butonu
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(themeManager.bejMode ? ThemeManager.BejThemeColors.text : .primary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(themeManager.bejMode ? ThemeManager.BejThemeColors.cardBackground : 
                                      (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)))
                        )
                }
                
                Spacer()
                
                // Oyun başlığı
                Text("Sudoku")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.bejMode ? ThemeManager.BejThemeColors.text : .primary)
                
                Spacer()
                
                // Ayarlar butonu
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.bejMode ? ThemeManager.BejThemeColors.text : .primary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(themeManager.bejMode ? ThemeManager.BejThemeColors.cardBackground : 
                                      (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)))
                        )
                }
            }
            
            // Oyun istatistikleri
            HStack(spacing: 15) {
                // Zorluk
                statView(
                    icon: "speedometer",
                    text: viewModel.board.difficulty.localizedName,
                    color: difficultyColors[viewModel.board.difficulty] ?? .blue
                )
                
                Spacer()
                
                // Süre
                statView(
                    icon: "clock",
                    text: timeDisplay,
                    color: .blue
                )
                
                Spacer()
                
                // Hatalar
                statView(
                    icon: "xmark.circle.fill",
                    text: "\(viewModel.errorCount)/3",
                    color: viewModel.errorCount >= 3 ? .red : (viewModel.errorCount >= 2 ? .orange : .gray)
                )
                
                Spacer()
                
                // İpuçları
                statView(
                    icon: "lightbulb.fill",
                    text: "\(viewModel.remainingHints)",
                    color: .orange
                )
            }
            .padding(.top, 8)
        }
    }
    
    // Kontrol alanı - performans için önbelleklenmiş
    private var controlsView: some View {
        VStack(spacing: 15) {
            // Oyun durumu çubuğu
            HStack {
                // Oyun durumu bilgisi
                Text(gameStateText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(gameStateColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(gameStateColor.opacity(0.15))
                    )
                
                Spacer()
                
                // İpucu butonu
                Button {
                    if viewModel.remainingHints > 0 {
                        viewModel.requestHint()
                    } else {
                        showNoHintsMessage = true
                        // Otomatik olarak mesajı 2 saniye sonra gizle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showNoHintsMessage = false
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("İpucu (\(viewModel.remainingHints))")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange)
                    )
                }
                .opacity(viewModel.remainingHints <= 0 ? 0.5 : 1.0)
                
                // Düzenleme butonu (Yeni oyun butonu yerine)
                Button {
                    // Düzenleme işlemi (kalem modunu aktif et/deaktif et)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.pencilMode.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.pencilMode ? "pencil.circle.fill" : "pencil")
                        Text(viewModel.pencilMode ? NSLocalizedString("Note Active", comment: "Pencil mode active") : NSLocalizedString("Note Mode", comment: "Pencil mode button"))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(viewModel.pencilMode ? Color.purple : Color.gray)
                    )
                }
            }
            .padding(.vertical, 5)
            
            // Numara tuşları
            NumberPadView(viewModel: viewModel, isEnabled: viewModel.gameState == .playing)
        }
    }
    
    // İstatistik metni görünümü
    private func statView(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14 * textScale))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 14 * textScale, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Yardımcı Metotlar
    
    // Başlangıç animasyonlarını ayarla
    private func setupInitialAnimations() {
        // Sıralı görünürlük animasyonları
        withAnimation(.easeOut(duration: 0.3)) {
            isHeaderVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            isBoardVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            isControlsVisible = true
        }
        
        // İlk kullanımda rehberlik özelliğini otomatik başlat
        // if !tutorialManager.hasCompletedTutorial && viewModel.gameState == .playing {
        //     tutorialManager.startTutorial()
        // }
    }
    
    // Zamanlayıcı güncelleyicisini ayarla
    private func setupTimerUpdater() {
        // İlk değeri hemen ayarla
        updateTimeDisplay()
        
        // Timer'ı düzenli güncelleme için ayarla
        Timer.scheduledTimer(withTimeInterval: timerUpdateInterval, repeats: true) { _ in
            if viewModel.gameState == .playing {
                updateTimeDisplay()
            }
        }
    }
    
    // Zaman gösterimini güncelle
    private func updateTimeDisplay() {
        timeDisplay = timeString(from: viewModel.elapsedTime)
    }
    
    // Zaman dizesini oluştur
    private func timeString(from timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // Oyun durumu metni
    private var gameStateText: String {
        switch viewModel.gameState {
        case .ready:
            return NSLocalizedString("Ready", comment: "Game state: ready")
        case .playing:
            return viewModel.pencilMode ? 
                NSLocalizedString("Note Mode", comment: "Game state: pencil mode") : 
                NSLocalizedString("Playing", comment: "Game state: playing")
        case .paused:
            return NSLocalizedString("Paused", comment: "Game state: paused")
        case .completed:
            return NSLocalizedString("Completed", comment: "Game state: completed")
        case .failed:
            return NSLocalizedString("Failed", comment: "Game state: failed")
        }
    }
    
    // Oyun durumu rengi
    private var gameStateColor: Color {
        switch viewModel.gameState {
        case .ready:
            return .gray
        case .playing:
            return viewModel.pencilMode ? .purple : .green
        case .paused:
            return .orange
        case .completed:
            return .blue
        case .failed:
            return .red
        }
    }
    
    // Zorluk seçme için view
    private var difficultyPickerView: some View {
        VStack(spacing: 20) {
            // Başlık
            VStack(spacing: 10) {
                Text("Zorluk Seviyesi Seçin")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text("Kendinize uygun bir zorluk seviyesi belirleyin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Zorluk seviyeleri
            VStack(spacing: 15) {
                ForEach(SudokuBoard.Difficulty.allCases, id: \.self) { difficulty in
                    DifficultyButton(
                        title: difficulty.localizedName,
                        description: difficulty.description,
                        icon: difficultyIcon(for: difficulty),
                        color: difficultyColors[difficulty] ?? .blue,
                        action: {
                            viewModel.newGame(difficulty: difficulty)
                            showDifficultyPicker = false
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // İptal butonu
            Button {
                showDifficultyPicker = false
            } label: {
                Text("İptal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ColorManager.primaryRed)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .stroke(ColorManager.primaryRed, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
        )
        .frame(maxHeight: 550)
        .padding(.horizontal, 20)
    }
    
    // Zorluk seviyesi için ikon belirle
    private func difficultyIcon(for difficulty: SudokuBoard.Difficulty) -> String {
        switch difficulty {
        case .easy:
            return "leaf"
        case .medium:
            return "flame"
        case .hard:
            return "bolt"
        case .expert:
            return "star"
        }
    }
    
    // Tebrikler ekranı
    private var congratulationsView: some View {
        VStack(spacing: 20) {
            // Başarı ikonu ve animasyonu
            ZStack {
                // Arka plan parıltısı
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.yellow.opacity(0.3), .clear]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                
                // Parlak dış çember
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.yellow.opacity(0.8), .yellow.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 100, height: 100)
                
                // Kupa ikonu
                Image(systemName: "trophy.fill")
                    .font(.system(size: 75))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorManager.primaryGreen, ColorManager.primaryBlue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            
            // Başlık ve açıklama
            VStack(spacing: 8) {
                Text("Tebrikler!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text("Sudoku bulmacasını \(timeString(from: viewModel.elapsedTime)) sürede tamamladınız!")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Performans istatistiği
            HStack(spacing: 20) {
                performanceCard(
                    title: "Zorluk",
                    value: viewModel.board.difficulty.rawValue,
                    systemImage: "speedometer",
                    color: difficultyColors[viewModel.board.difficulty] ?? .blue
                )
                
                performanceCard(
                    title: "Skor",
                    value: calculateScore(),
                    systemImage: "star.fill",
                    color: .yellow
                )
            }
            .padding(.top, 5)
            
            // Detaylı İstatistikler
            GameStatisticsView(viewModel: viewModel)
                .padding(.top, 10)
            
            Button(action: {
                // Tebrikler ekranını kapat
                showingGameComplete = false
                
                // Yeni bir oyun başlat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showDifficultyPicker = true
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Yeni Oyun")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [ColorManager.primaryGreen, ColorManager.primaryBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        // Parlak üst kenar
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .foregroundColor(.white)
                .shadow(color: ColorManager.primaryBlue.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 10)
            
            // Anasayfaya Dön Butonu
            Button(action: {
                // Önce ekranı kapatalım
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "house.fill")
                    Text("Anasayfaya Dön")
                        .fontWeight(.medium)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .foregroundColor(.primary)
            }
            .padding(.top, 5)
        }
        .padding(25)
        .background(
            ZStack {
                // Ana arka plan
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? 
                          Color(.systemGray6).opacity(0.95) : 
                          Color.white.opacity(0.95))
                
                // Üst kısımda hafif gradyan efekti
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                (colorScheme == .dark ? Color(.systemGray5) : .white).opacity(0.5),
                                (colorScheme == .dark ? Color(.systemGray6) : .white).opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                
                // İnce kenarlık
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: colorScheme == .dark ? 0.5 : 0.2
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
        .zIndex(20) // Bildirimlerin görünmesi için yüksek z-index değeri
    }
    
    // Performans istatistik kartı
    private func performanceCard(title: String, value: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 100, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
        )
    }
    
    // Skoru hesapla
    private func calculateScore() -> String {
        let score = viewModel.calculatePerformanceScore()
        return "\(score)"
    }
    
    // Kaybedildi ekranı
    private var gameOverView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 75))
                .foregroundColor(.red)
                .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Oyun Bitti!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Text("3 hata yaptınız ve Sudoku oyununu kaybettiniz.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Süre: \(timeString(from: viewModel.elapsedTime))")
                .font(.subheadline)
                .padding(.top, 5)
            
            Button(action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showDifficultyPicker = true
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("Yeni Oyun")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red)
                )
                .foregroundColor(.white)
            }
            .padding(.top, 20)
            .padding(.horizontal, 40)
            
            // Anasayfaya Dön Butonu
            Button(action: {
                // Önce ekranı kapatalım
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "house.fill")
                    Text("Anasayfaya Dön")
                        .fontWeight(.medium)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .foregroundColor(.primary)
            }
            .padding(.top, 5)
            .padding(.horizontal, 40)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
        )
        .padding(20)
        .transition(.scale.combined(with: .opacity))
        .zIndex(100)
    }
    
    private func isNewHighScore() -> Bool {
        let currentScore = viewModel.calculatePerformanceScore()
        let bestScore = ScoreManager.shared.getBestScore(for: viewModel.board.difficulty)
        return currentScore > bestScore
    }
}

// MARK: - İstatistik Görünümü
struct GameStatisticsView: View {
    let viewModel: SudokuViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Performans İstatistikleri")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)
            
            let stats = viewModel.getGameStatistics()
            
            // İstatistik satırları
            StatRowView(
                title: "Toplam Hamle",
                value: "\(stats.moves)",
                icon: "figure.walk",
                color: ColorManager.primaryBlue
            )
            
            StatRowView(
                title: "Yapılan Hatalar",
                value: "\(stats.errors)",
                icon: "xmark.circle",
                color: ColorManager.errorColor
            )
            
            StatRowView(
                title: "Kullanılan İpuçları",
                value: "\(stats.hints)",
                icon: "lightbulb.fill",
                color: ColorManager.primaryOrange
            )
            
            StatRowView(
                title: "Ortalama Hamle Süresi",
                value: formatAverageMoveTime(stats.moves, stats.time),
                icon: "timer",
                color: ColorManager.primaryPurple
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
        )
    }
    
    // Ortalama hamle süresini formatla
    private func formatAverageMoveTime(_ moves: Int, _ totalTime: TimeInterval) -> String {
        guard moves > 0 else { return "0 sn" }
        
        let avgTime = totalTime / Double(moves)
        
        if avgTime < 1 {
            return String(format: "%.1f sn", avgTime)
        } else if avgTime < 60 {
            return String(format: "%.0f sn", avgTime)
        } else {
            return String(format: "%.1f dk", avgTime / 60)
        }
    }
}

// MARK: - İstatistik Satırı
struct StatRowView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            // İkon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 30)
            
            // Başlık
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Değer
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// Zorluk seviyesi butonu
struct DifficultyButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.textScale) var textScale
    
    // Temel boyutlar
    private var titleBaseSize: CGFloat = 18
    private var descriptionBaseSize: CGFloat = 12
    
    // Açık initializer eklendi
    internal init(title: String, description: String, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // İkon (boyutu sabit)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color)
                    )
                
                // Metin
                VStack(alignment: .leading, spacing: 2) {
                    // Başlık
                    Text(title)
                        .font(.system(size: titleBaseSize * textScale, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    // Açıklama
                    Text(description)
                        .font(.system(size: descriptionBaseSize * textScale))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // İleri ok
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
} 