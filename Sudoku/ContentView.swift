//  ContentView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI
import CoreData
import Combine

// Navigasyon sayfalarını enum olarak tanımla
enum AppPage: Int, CaseIterable, Identifiable {
    case home = 0
    case scoreboard = 1
    case savedGames = 2
    case settings = 3
    
    var id: Int { self.rawValue }
    
    var title: String {
        // Dili doğrudan UserDefaults'dan al
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        
        // Bundle yoluyla çeviri yap
        let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        
        switch self {
        case .home:
            return bundle?.localizedString(forKey: "Ana Sayfa", value: "Ana Sayfa", table: "Localizable") ?? "Ana Sayfa"
        case .scoreboard:
            return bundle?.localizedString(forKey: "Skor Tablosu", value: "Skor Tablosu", table: "Localizable") ?? "Skor Tablosu"
        case .savedGames:
            return bundle?.localizedString(forKey: "Kayıtlı Oyunlar", value: "Kayıtlı Oyunlar", table: "Localizable") ?? "Kayıtlı Oyunlar"
        case .settings:
            return bundle?.localizedString(forKey: "Ayarlar", value: "Ayarlar", table: "Localizable") ?? "Ayarlar"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .scoreboard: return "trophy.fill"
        case .savedGames: return "square.stack.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// Buton stil tanımı
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

struct ContentView: View {
    // MARK: - Properties
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.textScale) var textScale
    
    // ThemeManager'ı ekle
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    @StateObject private var viewModel = SudokuViewModel()
    @State private var currentPage: AppPage = .home // Tab değişikliklerini takip etmek için
    @State private var previousPage: AppPage = .home
    
    @AppStorage("selectedDifficulty") private var selectedDifficulty = 0
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = true  // true yaparak rehberi devre dışı bırakıyoruz
    @AppStorage("powerSavingMode") private var powerSavingMode = false // Animasyonlar için false (kapalı) olmalı
    
    @State private var showGame = false
    @State private var showTutorial = false
    @State private var showTutorialPrompt = false
    @State private var selectedCustomDifficulty: SudokuBoard.Difficulty = .easy
    
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var isLoadingSelectedGame = false // Seçilen oyun yüklenirken gösterilecek yükleme durumu
    
    // Animasyon değişkenleri
    @State private var titleScale = 0.9
    @State private var titleOpacity = 0.0
    @State private var buttonsOffset: CGFloat = 50
    @State private var buttonsOpacity = 0.0
    @State private var rotationDegree: Double = 0
    @State private var logoNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    @State private var animatingCellIndex = 4 // Merkez hücre
    @State private var cellAnimationProgress: CGFloat = 0
    
    var difficulty: SudokuBoard.Difficulty {
        SudokuBoard.Difficulty.allCases[selectedDifficulty]
    }
    
    // Zorluk seviyesi için ikon secimi
    func difficultyIcon(for index: Int) -> String {
        switch index {
        case 0: return "tortoise.fill" // Kolay
        case 1: return "hare.fill" // Orta
        case 2: return "flame.fill" // Zor
        case 3: return "bolt.fill" // Uzman
        default: return "questionmark"
        }
    }
    
    // Zorluk seviyesi için renk secimi
    func difficultyColor(for index: Int) -> Color {
        switch index {
        case 0: return .blue       // Kolay - Mavi
        case 1: return .green      // Orta - Yeşil
        case 2: return .orange     // Zor - Turuncu
        case 3: return .red        // Uzman - Kırmızı
        default: return .gray
        }
    }
    
    // MARK: - Initialization
    init() {
        // TabBar ayarları
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }
    
    // MARK: - Setup ve bildirim ayarları
    private func setupSavedGameNotification() {
        // Artık oyun bildirimleri sadece showGame ile yapılacağı için
        // eski bildirim dinleyicisine gerek yok
    }
    
    // Ana menüye dönüş bildirimini ayarla
    private func setupReturnToMainMenuNotification() {
        // Önce mevcut gözlemciyi kaldır (tekrarları önlemek için)
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ReturnToMainMenu"),
            object: nil
        )
        
        // Ana menüye dönüş bildirimini dinle
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ReturnToMainMenu"),
            object: nil,
            queue: .main
        ) { _ in
            logInfo("ReturnToMainMenu bildirimi alındı - Ana sayfaya dönülüyor")
            
            // Ana sayfaya dön ve oyun ekranlarını kapat
            DispatchQueue.main.async {
                withAnimation {
                    // Tüm aktif ekranları kapat
                    self.showGame = false
                    self.showTutorial = false
                    
                    // Tab değiştir
                    self.currentPage = .home
                    
                    // Aktif oyunu temizle/sıfırla
                    self.viewModel.resetGameState()
                }
            }
        }
    }
    
    // Bildirim işleme için singleton sınıf
    private class ContentViewTimeoutManager {
        static let shared = ContentViewTimeoutManager()
        var isProcessing = false
        private init() {}
    }
    
    // Zaman aşımı bildirim dinleyicisini ayarla
    private func setupTimeoutNotification() {
        // Önce mevcut gözlemciyi kaldır (tekrarları önlemek için)
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ShowMainMenuAfterTimeout"),
            object: nil
        )
        
        // Zaman aşımı sonrası ana menüyü gösterme bildirimini dinle
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ShowMainMenuAfterTimeout"),
            object: nil,
            queue: .main
        ) { notification in
            // Eğer zaten işleniyorsa, çık
            if ContentViewTimeoutManager.shared.isProcessing {
                return
            }
            
            // Bayrağı ayarla
            ContentViewTimeoutManager.shared.isProcessing = true
            
            // Oyun ekranını kapat ve ana sayfaya yönlendir
            DispatchQueue.main.async {
                // Bildirim gönder
                NotificationCenter.default.post(
                    name: Notification.Name("ContentViewUpdateAfterTimeout"),
                    object: nil
                )
                
                logInfo("Ana sayfaya yönlendiriliyor (zaman aşımı sonrası)")
                
                // İşlem tamamlandı, bayrağı sıfırla
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ContentViewTimeoutManager.shared.isProcessing = false
                }
            }
        }
        
        // ContentView güncelleme bildirimini dinle
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ContentViewUpdateAfterTimeout"),
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                self.showGame = false
                self.showTutorial = false
                // Ana sayfaya dönmeyelim (bu soruna neden olabilir)
                // self.currentPage = .home // Ana sayfaya yönlendir
            }
        }
    }
    
    // MARK: - Timeout Check and Tutorial Setup
    private func checkTutorial() {
        // Rehber kontrolünü kaldırıyoruz
        // if !hasSeenTutorial {
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        //         // NavigationLink için değişken ayarla
        //         showTutorial = true
        //     }
        // }
    }
    
    // Karşılama animasyonlarını başlat
    private func startWelcomeAnimations() {
        // Güç tasarrufu modunda animasyonları atlayalım
        if powerSavingMode { return }
        
        // Ana sayfa animasyonları
        withAnimation(.easeOut(duration: 0.8)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            buttonsOffset = 0
            buttonsOpacity = 1.0
        }
    }
    
    // MARK: - Ana Sayfa
    private var homePage: some View {
        VStack {
            // Ana sayfa içeriği
            mainContentView
                .transition(.opacity)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            // Tutorial görünümü
            TutorialView()
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Title View
    var titleView: some View {
        VStack(spacing: 25) {
            // Logoyu yukarı taşıyorum, boşluğu kaldırıyorum
            
            // 3D Animasyonlu Sudoku logosu
            AnimatedSudokuLogo()
                .frame(width: 140, height: 140)
                .padding(10)
                .scaleEffect(titleScale)
                .opacity(titleOpacity)
                .onAppear {
                    // Logonun görünürlük ayarlarını anında etkinleştir, animasyon olmadan
                    titleScale = 1.0
                    titleOpacity = 1.0
                    
                    // Rotasyon ve animasyon yok
                    rotationDegree = 0
                    cellAnimationProgress = 0.0
                    
                    // Sabit sayılar, değişmeyecek
                    // Timer ve animasyon yok
                }
            
            // İyileştirilmiş başlık
            Text("SUDOKU")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                .overlay(
                    // Metin için altın gölge efekti - bej modunda özel renk
                    Text("SUDOKU")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.3) : Color.blue.opacity(0.3))
                        .offset(x: 2, y: 2)
                        .blur(radius: 2)
                        .mask(Text("SUDOKU")
                            .font(.system(size: 38, weight: .bold, design: .rounded)))
                )
                .padding(.top, 5)
        }
    }
    
    // MARK: - Continue Game Button
    var continueGameButton: some View {
        Button(action: {
            SoundManager.shared.playNavigationSound()
            
            // Son kaydedilen oyunu yükle
            let fetchRequest: NSFetchRequest<SavedGame> = SavedGame.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SavedGame.dateCreated, ascending: false)]
            fetchRequest.fetchLimit = 1
            
            do {
                let result = try viewContext.fetch(fetchRequest)
                if let lastGame = result.first {
                    // Yükleme işlemi başladı
                    isLoading = true
                    logInfo("Son kaydedilmiş oyun yükleniyor... ID: \(lastGame.value(forKey: "id") ?? "ID yok")")
                    
                    // Kaydedilmiş oyunu SudokuViewModel'e yükle
                    viewModel.loadGame(from: lastGame)
                    
                    // Oyun görünümünü göster - daha akıcı geçiş
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isLoading = false
                        withAnimation(.spring()) {
                            // Doğrudan showGame'i aktif et
                            showGame = true
                        }
                    }
                } else {
                    logInfo("Kaydedilmiş oyun bulunamadı, yeni oyun başlatılıyor")
                    // Kaydedilmiş oyun yoksa yeni oyun başlat
                    withAnimation(.spring()) {
                        // GameState'i temizle ve yeni oyun oluştur
                        viewModel.resetGameState()
                        selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[selectedDifficulty]
                        viewModel.newGame(difficulty: selectedCustomDifficulty)
                        showGame = true
                    }
                }
            } catch {
                // Hata durumunda
                isLoading = false
                loadError = error
                logError("Yükleme hatası: \(error)")
            }
        }) {
            HStack {
                // Daha özel ve modern bir buton tasarımı
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: isBejMode ? 
                                             [ThemeManager.BejThemeColors.accent, ThemeManager.BejThemeColors.accent.opacity(0.7)] : 
                                             [Color.green, Color.green.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                        .shadow(color: isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.3) : Color.green.opacity(0.3), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .semibold))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text.localizedSafe("Devam Et")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Text.localizedSafe("Kaldığın yerden devam et")
                        .font(.caption)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                }
                .padding(.leading, 6)
                
                Spacer()
                
                Image(systemName: "chevron.forward")
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.8) : Color.green.opacity(0.8))
                    .font(.subheadline)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                ZStack {
                    // Arka plan - bej mod veya normal mod
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isBejMode ? ThemeManager.BejThemeColors.cardBackground : Color(UIColor.secondarySystemBackground))
                    
                    // Kenar vurgusu - bej mod veya normal mod
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 1.5)
                }
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        // Ekstra hoş bir giriş animasyonu
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
            removal: .opacity.animation(.easeOut(duration: 0.2))
        ))
    }
    
    // MARK: - Game Modes Section
    var gameModesSection: some View {
        VStack(spacing: 25) {
            // Yeni Oyun bölümü - görsel iyileştirmeler
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text.localizedSafe("Yeni Oyun")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Spacer()
                    
                    // Dekoratif öğe - küçük bir zar
                    Image(systemName: "die.face.5")
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.7) : Color.blue.opacity(0.7))
                        .font(.headline)
                        .rotationEffect(Angle(degrees: 15))
                }
                .padding(.horizontal)
                
                // Zorluk seviyeleri - 2x2 grid formatında
                VStack(spacing: 16) {
                    // Üst sıra: Kolay ve Orta
                    HStack(spacing: 15) {
                        ForEach(0..<2) { index in
                            difficultyButton(for: index)
                        }
                    }
                    
                    // Alt sıra: Zor ve Uzman
                    HStack(spacing: 15) {
                        ForEach(2..<4) { index in
                            difficultyButton(for: index)
                        }
                    }
                }
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)
                .onAppear {
                    if powerSavingMode {
                        buttonsOffset = 0
                        buttonsOpacity = 1.0
                    } else {
                        // Daha akıcı görünüm için animasyonları kademeli olarak göster
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                            buttonsOffset = 0
                            buttonsOpacity = 1.0
                        }
                    }
                }
            }
            
            // Rehber butonu - bej moduna uyarlandı
            Button(action: {
                SoundManager.shared.playNavigationSound()
                
                // Doğrudan eğitimi göster, onay almadan
                showTutorial = true
                
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue)
                        .clipShape(Circle())
                    
                    Text.localizedSafe("Nasıl Oynanır?")
                        .font(.system(size: 16 * textScale, weight: .medium))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .gray)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isBejMode ? ThemeManager.BejThemeColors.cardBackground : Color(UIColor.secondarySystemBackground))
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .offset(y: buttonsOffset)
            .opacity(buttonsOpacity)
        }
    }
    
    // Zorluk düzeyi butonu için yardımcı fonksiyon - kodu temiz tutmak için
    private func difficultyButton(for index: Int) -> some View {
        Button(action: {
            SoundManager.shared.playNavigationSound()
            
            // Yeni bir oyun başlatmak için önce viewModel'i resetle ve yeni oyun oluştur
            viewModel.resetGameState()
            selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[index]
            viewModel.newGame(difficulty: selectedCustomDifficulty)
            
            withAnimation(.spring()) {
                showGame = true
            }
        }) {
            HStack {
                // Güzel gradient ikon arka planı - bej mod uyumlu
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: isBejMode ? 
                                             [ThemeManager.BejThemeColors.accent, ThemeManager.BejThemeColors.accent.opacity(0.7)] : 
                                             [difficultyColor(for: index), difficultyColor(for: index).opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                        .shadow(color: isBejMode ? 
                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                               difficultyColor(for: index).opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: difficultyIcon(for: index))
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(SudokuBoard.Difficulty.allCases[index].localizedName)
                    .font(.headline)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "chevron.forward")
                    .foregroundColor(isBejMode ? 
                                   ThemeManager.BejThemeColors.accent.opacity(0.7) : 
                                   difficultyColor(for: index).opacity(0.7))
                    .font(.subheadline)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                ZStack {
                    // Arka plan - bej mod uyumlu
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isBejMode ? ThemeManager.BejThemeColors.cardBackground : Color(UIColor.secondarySystemBackground))
                    
                    // Kenar vurgusu - bej mod uyumlu
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isBejMode ? 
                               ThemeManager.BejThemeColors.accent.opacity(0.2) : 
                               difficultyColor(for: index).opacity(0.2), lineWidth: 1.5)
                }
                    .shadow(color: Color.black.opacity(0.07), radius: 7, x: 0, y: 3)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Main Content View
    var mainContentView: some View {
        ZStack {
            // Bej mod için özel arka plan, normal mod için ızgara arka planı
            if isBejMode {
                ThemeManager.BejThemeColors.background
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        // Bej mod için hafif desen
                        VStack(spacing: 20) {
                            ForEach(0..<20) { i in
                                HStack(spacing: 20) {
                                    ForEach(0..<10) { j in
                                        Circle()
                                            .fill(ThemeManager.BejThemeColors.accent.opacity(0.03))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .offset(x: i % 2 == 0 ? 10 : 0)
                            }
                        }
                    )
            } else {
                // Normal mod için ızgara arka planı
                GridBackgroundView()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Yükleme/hata durumları veya ana içerik
            if isLoading {
                ProgressView(LocalizationManager.shared.localizedString(for: "Yükleniyor..."))
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                ScrollView {
                    VStack(spacing: 30) {
                        titleView
                            .rotation3DEffect(
                                .degrees(rotationDegree),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .onAppear {
                                // 3D dönme efekti
                                if !powerSavingMode {
                                    withAnimation(.easeInOut(duration: 1.5)) {
                                        rotationDegree = 360
                                    }
                                }
                            }
                        
                        gameModesSection
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                // Ana sayfa
                homePage
                    .tabItem {
                        Label(AppPage.home.title, systemImage: AppPage.home.icon)
                    }
                    .environmentObject(themeManager)
                    .tag(AppPage.home)
                
                // Skor tablosu
                ScoreboardView()
                    .tabItem {
                        Label(AppPage.scoreboard.title, systemImage: AppPage.scoreboard.icon)
                    }
                    .tag(AppPage.scoreboard)
                
                // Kayıtlı oyunlar
                SavedGamesView(viewModel: viewModel,
                             gameSelected: { game in
                                 // Seçilen oyunu yükle
                                 viewModel.loadGame(from: game as! SavedGame)
                                 // Oyun görünümünü göster
                                 showGame = true
                             })
                    .tabItem {
                        Label(AppPage.savedGames.title, systemImage: AppPage.savedGames.icon)
                    }
                    .tag(AppPage.savedGames)
                
                // Ayarlar
                SettingsView()
                    .tabItem {
                        Label(AppPage.settings.title, systemImage: AppPage.settings.icon)
                    }
                    .tag(AppPage.settings)
            }
            .blur(radius: showGame || showTutorial ? 20 : 0)
            .animation(.easeInOut(duration: 0.3), value: showGame)
            .animation(.easeInOut(duration: 0.3), value: showTutorial)
            
            // Oyun ekranı
            if showGame {
                GameView(existingViewModel: viewModel)
                    .environmentObject(themeManager)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: showGame)
                    .zIndex(1)
            }
            
            // Rehber
            if showTutorial {
                TutorialView()
                    .environmentObject(themeManager)
                    .transition(.opacity)
                    .animation(.easeInOut, value: showTutorial)
                    .zIndex(2)
            }
            
            // Başarı bildirimi
            if AchievementManager.shared.showAchievementAlert, 
               let achievement = AchievementManager.shared.lastUnlockedAchievement {
                AchievementNotification(achievement: achievement) {
                    AchievementManager.shared.showAchievementAlert = false
                }
                .zIndex(4) // En üstte göster
            }
            
            // Genel yükleniyor göstergesi
            if isLoading {
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text.localizedSafe("Yükleniyor...")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }
                .zIndex(3)
            }
        }
        .onAppear {
            // Bildirim işleyicilerini ayarla
            setupTimeoutNotification()
            setupReturnToMainMenuNotification()
            
            // PowerSaving Manager'ı başlat
            _ = PowerSavingManager.shared
            
            // Ekran kararmasını açıkça ETKİNLEŞTİR (GameView dışındaki tüm ekranlar için)
            logInfo("ContentView onAppear - Ekran kararması durumu SudokuApp tarafından yönetiliyor.")
            
            // Cihaz bilgilerini göster
            logInfo("ContentView onAppear - Device: \(UIDevice.current.model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))) { _ in
            // Dil değiştiğinde tüm görünümü yenile
            logInfo("Dil değişikliği algılandı - ContentView yenileniyor")
            
            // Görünümü zorla yenileme
            withAnimation {
                // currentPage'i geçici olarak değiştirip geri getirerek zorla yenileme
                let temp = currentPage
                currentPage = .home
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    currentPage = temp
                }
            }
        }
        .fullScreenCover(isPresented: $isLoadingSelectedGame) {
            // Oyun yüklenirken gösterilecek yükleme ekranı
            ZStack {
                // Arka plan
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text(LocalizationManager.shared.localizedString(for: "Oyun yükleniyor..."))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            GameView(existingViewModel: viewModel)
                .environmentObject(themeManager)
                .localizationAware()
        }
        .localizationAware()
    }
    
    
    // MARK: - GroupBox stil tanımı
    struct CardGroupBoxStyle: GroupBoxStyle {
        @Environment(\.colorScheme) var colorScheme
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
        }
    }
    
    // UIKit'ten guncel API kullanarak safe area bottom degerini alma
    func getSafeAreaBottom() -> CGFloat {
        // iOS 15+ icin guncel API
        if #available(iOS 15.0, *) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            return scene?.keyWindow?.safeAreaInsets.bottom ?? 0
        } else {
            // iOS 15 oncesi icin eski yontem (artik deprecated)
            return UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        }
    }
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
