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
        switch self {
        case .home:
            let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "en"
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            let bundle = path != nil ? Bundle(path: path!) : Bundle.main
            return bundle?.localizedString(forKey: "Ana Sayfa", value: "Ana Sayfa", table: "Localizable") ?? "Ana Sayfa"
        case .scoreboard:
            let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "en"
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            let bundle = path != nil ? Bundle(path: path!) : Bundle.main
            return bundle?.localizedString(forKey: "Skor Tablosu", value: "Skor Tablosu", table: "Localizable") ?? "Skor Tablosu"
        case .savedGames:
            let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "en"
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            let bundle = path != nil ? Bundle(path: path!) : Bundle.main
            return bundle?.localizedString(forKey: "Kayıtlı Oyunlar", value: "Kayıtlı Oyunlar", table: "Localizable") ?? "Kayıtlı Oyunlar"
        case .settings:
            let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "en"
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            let bundle = path != nil ? Bundle(path: path!) : Bundle.main
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
    
    // ThemeManager'ı ekle
    @EnvironmentObject var themeManager: ThemeManager
    
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
                
                print("🔊 Ana sayfaya yönlendiriliyor (zaman aşımı sonrası)")
                
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
                .foregroundColor(.primary)
                .overlay(
                    // Metin için altın gölge efekti
                    Text("SUDOKU")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(Color.blue.opacity(0.3))
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
                    print("Son kaydedilmiş oyun yükleniyor... ID: \(lastGame.value(forKey: "id") ?? "ID yok")")
                    
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
                    print("Kaydedilmiş oyun bulunamadı, yeni oyun başlatılıyor")
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
                print("Yükleme hatası: \(error)")
            }
        }) {
            HStack {
                // Daha özel ve modern bir buton tasarımı
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .semibold))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text.localizedSafe("Devam Et")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text.localizedSafe("Kaldığın yerden devam et")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 6)
                
                Spacer()
                
                Image(systemName: "chevron.forward")
                    .foregroundColor(Color.green.opacity(0.8))
                    .font(.subheadline)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                ZStack {
                    // Modern arka plan
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(UIColor.secondarySystemBackground))
                    
                    // Özel kenar vurgusu
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1.5)
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
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Dekoratif öğe - küçük bir zar
                    Image(systemName: "die.face.5")
                        .foregroundColor(Color.blue.opacity(0.7))
                        .font(.headline)
                        .rotationEffect(Angle(degrees: 15))
                }
                .padding(.horizontal)
                
                // Zorluk seviyeleri - 2x2 grid formatında
                VStack(spacing: 16) {
                    // Üst sıra: Kolay ve Orta
                    HStack(spacing: 15) {
                        // Kolay (index 0)
                        Button(action: {
                            SoundManager.shared.playNavigationSound()
                            
                            // Yeni bir oyun başlatmak için önce viewModel'i resetle ve yeni oyun oluştur
                            viewModel.resetGameState()
                            selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[0]
                            viewModel.newGame(difficulty: selectedCustomDifficulty)
                            
                            withAnimation(.spring()) {
                                showGame = true
                            }
                        }) {
                            HStack {
                                // Güzel gradient ikon arka planı
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [
                                                difficultyColor(for: 0),
                                                difficultyColor(for: 0).opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: difficultyColor(for: 0).opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: difficultyIcon(for: 0))
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                Text(SudokuBoard.Difficulty.allCases[0].localizedName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(difficultyColor(for: 0).opacity(0.7))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(
                                ZStack {
                                    // Arka plan
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                    
                                    // Kenar vurgusu
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(difficultyColor(for: 0).opacity(0.2), lineWidth: 1.5)
                                }
                                    .shadow(color: Color.black.opacity(0.07), radius: 7, x: 0, y: 3)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Orta (index 1)
                        Button(action: {
                            SoundManager.shared.playNavigationSound()
                            
                            // Yeni bir oyun başlatmak için önce viewModel'i resetle ve yeni oyun oluştur
                            viewModel.resetGameState()
                            selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[1]
                            viewModel.newGame(difficulty: selectedCustomDifficulty)
                            
                            withAnimation(.spring()) {
                                showGame = true
                            }
                        }) {
                            HStack {
                                // Güzel gradient ikon arka planı
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [
                                                difficultyColor(for: 1),
                                                difficultyColor(for: 1).opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: difficultyColor(for: 1).opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: difficultyIcon(for: 1))
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                Text(SudokuBoard.Difficulty.allCases[1].localizedName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(difficultyColor(for: 1).opacity(0.7))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(
                                ZStack {
                                    // Arka plan
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                    
                                    // Kenar vurgusu
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(difficultyColor(for: 1).opacity(0.2), lineWidth: 1.5)
                                }
                                    .shadow(color: Color.black.opacity(0.07), radius: 7, x: 0, y: 3)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    
                    // Alt sıra: Zor ve Uzman
                    HStack(spacing: 15) {
                        // Zor (index 2)
                        Button(action: {
                            SoundManager.shared.playNavigationSound()
                            
                            // Yeni bir oyun başlatmak için önce viewModel'i resetle ve yeni oyun oluştur
                            viewModel.resetGameState()
                            selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[2]
                            viewModel.newGame(difficulty: selectedCustomDifficulty)
                            
                            withAnimation(.spring()) {
                                showGame = true
                            }
                        }) {
                            HStack {
                                // Güzel gradient ikon arka planı
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [
                                                difficultyColor(for: 2),
                                                difficultyColor(for: 2).opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: difficultyColor(for: 2).opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: difficultyIcon(for: 2))
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                Text(SudokuBoard.Difficulty.allCases[2].localizedName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(difficultyColor(for: 2).opacity(0.7))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(
                                ZStack {
                                    // Arka plan
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                    
                                    // Kenar vurgusu
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(difficultyColor(for: 2).opacity(0.2), lineWidth: 1.5)
                                }
                                    .shadow(color: Color.black.opacity(0.07), radius: 7, x: 0, y: 3)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Uzman (index 3)
                        Button(action: {
                            SoundManager.shared.playNavigationSound()
                            
                            // Yeni bir oyun başlatmak için önce viewModel'i resetle ve yeni oyun oluştur
                            viewModel.resetGameState()
                            selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[3]
                            viewModel.newGame(difficulty: selectedCustomDifficulty)
                            
                            withAnimation(.spring()) {
                                showGame = true
                            }
                        }) {
                            HStack {
                                // Güzel gradient ikon arka planı
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [
                                                difficultyColor(for: 3),
                                                difficultyColor(for: 3).opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: difficultyColor(for: 3).opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: difficultyIcon(for: 3))
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                Text(SudokuBoard.Difficulty.allCases[3].localizedName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(difficultyColor(for: 3).opacity(0.7))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(
                                ZStack {
                                    // Arka plan
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                    
                                    // Kenar vurgusu
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(difficultyColor(for: 3).opacity(0.2), lineWidth: 1.5)
                                }
                                    .shadow(color: Color.black.opacity(0.07), radius: 7, x: 0, y: 3)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
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
            
            // Rehber butonu
            Button(action: {
                SoundManager.shared.playNavigationSound()
                
                if !hasSeenTutorial {
                    // Doğrudan eğitimi göster
                    showTutorial = true
                } else {
                    // Eğitimi daha önce görmüşse, sor
                    showTutorialPrompt = true
                }
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text.localizedSafe("Nasıl Oynanır?")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .offset(y: buttonsOffset)
            .opacity(buttonsOpacity)
        }
    }
    
    // MARK: - Main Content View
    var mainContentView: some View {
        ZStack {
            // Yeni ızgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            // Yükleme/hata durumları veya ana içerik
            if isLoading {
                ProgressView("Yükleniyor...")
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
        TabView(selection: $currentPage) {
            // Tab 1: Ana Sayfa
            homePage
                .tabItem {
                    Label(AppPage.home.title, systemImage: AppPage.home.icon)
                }
                .tag(AppPage.home)
            
            // Tab 2: Skor Tablosu
            ScoreboardView()
                .tabItem {
                    Label(AppPage.scoreboard.title, systemImage: AppPage.scoreboard.icon)
                }
                .tag(AppPage.scoreboard)
            
            // Tab 3: Kayıtlı Oyunlar
            SavedGamesView(viewModel: viewModel, gameSelected: { game in
                // Oyun yüklenirken yükleme ekranını göster
                // isLoadingSelectedGame = true
                
                // Kaydedilmiş oyunu yükle
                viewModel.loadGame(from: game)
                
                // Direkt olarak oyunu göster, yükleme ekranı kullanma
                showGame = true
            })
            .tabItem {
                Label(AppPage.savedGames.title, systemImage: AppPage.savedGames.icon)
            }
            .tag(AppPage.savedGames)
            
            // Tab 4: Ayarlar
            SettingsView()
                .environmentObject(themeManager)
                .tabItem {
                    Label(AppPage.settings.title, systemImage: AppPage.settings.icon)
                }
                .tag(AppPage.settings)
        }
        .animation(nil, value: currentPage) // Tab geçişlerini animasyonsuz yap
        .onChange(of: currentPage) { oldPage, newPage in
            // Her tab değişiminde çalışacak
            if previousPage != newPage {
                previousPage = newPage
                SoundManager.shared.playNavigationSound()
            }
        }
        .onAppear {
            setupSavedGameNotification()
            setupTimeoutNotification()
            checkTutorial()
            startWelcomeAnimations()
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
                    
                    Text("Oyun yükleniyor...")
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
