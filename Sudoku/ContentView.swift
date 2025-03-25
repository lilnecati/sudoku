//  ContentView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.03.2025.
//

import SwiftUI
import CoreData

// Navigasyon sayfalarını enum olarak tanımla
enum AppPage: Int, CaseIterable, Identifiable {
    case home = 0
    case scoreboard = 1
    case savedGames = 2
    case settings = 3
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .scoreboard: return "Skor Tablosu"
        case .savedGames: return "Kayıtlı Oyunlar"
        case .settings: return "Ayarlar"
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
    
    // Kaydedilmiş oyun açma
    @State private var gameToLoad: NSManagedObject? = nil
    @State private var showSavedGame = false
    
    @StateObject private var viewModel = SudokuViewModel()
    @State private var currentPage: AppPage = .home
    
    @AppStorage("selectedDifficulty") private var selectedDifficulty = 0
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("powerSavingMode") private var powerSavingMode = false
    
    @State private var showGame = false
    @State private var showTutorial = false
    @State private var showTutorialPrompt = false
    @State private var selectedCustomDifficulty: SudokuBoard.Difficulty = .easy
    
    @State private var isLoading = false
    @State private var loadError: Error?
    
    // Animasyon değişkenleri
    @State private var titleScale = 0.9
    @State private var titleOpacity = 0.0
    @State private var buttonsOffset: CGFloat = 50
    @State private var buttonsOpacity = 0.0
    @State private var rotationDegree: Double = 0
    
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
    
    // Bildirim dinleyicilerini ayarla
    private func setupSavedGameNotification() {
        // "Ana sayfaya geç" bildirimini dinle
        NotificationCenter.default.addObserver(forName: Notification.Name("NavigateToHome"),
                                               object: nil, queue: .main) { _ in
            withAnimation {
                self.currentPage = .home
            }
        }
        
        // Kaydedilmiş oyun yükleme bildirimini dinle
        NotificationCenter.default.addObserver(forName: Notification.Name("LoadSavedGame"),
                                               object: nil, queue: .main) { notification in
            // Kaydedilmiş oyunu bildirimden al
            if let savedGame = notification.userInfo?["savedGame"] as? SavedGame {
                // Önce ana sayfaya geç
                withAnimation {
                    self.currentPage = .home
                }
                
                // Kaydedilmiş oyunu yükle
                // Önemli: Seçili zorluk ayarını değiştirmeden mevcut viewModel'e yüklüyoruz
                self.viewModel.loadGame(from: savedGame)
                
                // Oyun durumunu oynamaya ayarla
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Oyunu göster
                    withAnimation(.spring()) {
                        self.showGame = true
                    }
                }
            }
        }
    }
    
    // MARK: - Title View
    var titleView: some View {
        VStack(spacing: 15) {
            // Logo ve başlık bölümü
            ZStack {
                // Arka plan etkisi - iki halka
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Dış parlama efekti
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 105, height: 105)
                    .blur(radius: 3)
                
                // Sudoku simgesi - gelişmiş 3x3 grid
                VStack(spacing: 3) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<3) { column in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                    // Dönüş animasyonu - belirli hücreler için
                                    .rotationEffect(Angle(degrees: (row == 1 && column == 1) ? rotationDegree : 0))
                            }
                        }
                    }
                }
            }
            .scaleEffect(titleScale)
            .opacity(titleOpacity)
            .onAppear {
                if !powerSavingMode {
                    // Logo gelişmiş animasyonu
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.5)) {
                        titleScale = 1.0
                        titleOpacity = 1.0
                    }
                    
                    // Merkez hücrenin hafif döndürme animasyonu
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        rotationDegree = 180
                    }
                } else {
                    titleScale = 1.0
                    titleOpacity = 1.0
                }
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
                    Text("Devam Et")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Kaldığın yerden devam et")
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
                    Text("Yeni Oyun")
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
                
                // Zorluk seviyeleri - modernizeştirilmiş tasarım
                VStack(spacing: 16) {
                    ForEach(0..<SudokuBoard.Difficulty.allCases.count, id: \.self) { index in
                        Button(action: {
                            selectedCustomDifficulty = SudokuBoard.Difficulty.allCases[index]
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
                                                difficultyColor(for: index),
                                                difficultyColor(for: index).opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: difficultyColor(for: index).opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: difficultyIcon(for: index))
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                Text(SudokuBoard.Difficulty.allCases[index].localizedName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(difficultyColor(for: index).opacity(0.7))
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
                                        .stroke(difficultyColor(for: index).opacity(0.2), lineWidth: 1.5)
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
                if !hasSeenTutorial {
                    showTutorial = true
                } else {
                    showTutorialPrompt = true
                }
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text("Nasıl Oynanır?")
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
            // Arka plan tasarımı - güç tasarrufu ve visual appeal arasında denge
            if powerSavingMode {
                // Güç tasarrufu modu açıkken basit arka plan
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Gelişmiş ve modern arka plan tasarımı
                ZStack {
                    // Yumuşak gradient
                    LinearGradient(gradient: Gradient(colors: [
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.12),
                        Color(UIColor.systemBackground)
                    ]), startPoint: .topLeading, endPoint: .bottom)
                    
                    // Arka planda dekoratif sudoku şablonu - daha yumuşak
                    VStack(spacing: 0) {
                        ForEach(0..<9) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<9) { column in
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
                                        .background(((row/3 + column/3) % 2 == 0) ?
                                                    Color.gray.opacity(0.02) : Color.clear)
                                        .frame(width: 22, height: 22)
                                }
                            }
                        }
                    }
                    .rotationEffect(.degrees(8))
                    .scaleEffect(2.2)
                    .offset(x: 60, y: -180)
                    .opacity(0.3)
                    
                    // Dekoratif parlama efektleri
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 80)
                        .offset(x: -120, y: -200)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 70)
                        .offset(x: 150, y: 250)
                }
                .edgesIgnoringSafeArea(.all)
            }
            
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
        VStack(spacing: 0) {
            ZStack {
                Group {
                    if case .home = currentPage {
                        if showSavedGame {
                            // Sadece kaydedilmiş oyunlar için oyun görünümünü doğrudan göster
                            GameView(existingViewModel: viewModel)
                        } else {
                            mainContentView
                                .transition(.opacity)
                        }
                    } else if case .scoreboard = currentPage {
                        ScoreboardView()
                            .environment(\.managedObjectContext, viewContext)
                            .transition(.opacity)
                    } else if case .savedGames = currentPage {
                        // SavedGamesView'u güvenli bir şekilde yükle
                        ZStack {
                            Color(UIColor.systemBackground)
                                .edgesIgnoringSafeArea(.all)
                            
                            SavedGamesView(viewModel: viewModel, gameSelected: { game in
                                // Seçilen oyunu ayarla
                                gameToLoad = game
                                // Oyun görünümünü aktifleştir
                                withAnimation {
                                    currentPage = .home
                                    showSavedGame = true
                                }
                            })
                        }
                        .transition(.opacity)
                        .environment(\.managedObjectContext, viewContext)
                    } else if case .settings = currentPage {
                        SettingsView()
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Tab bar
                VStack {
                    Spacer()
                    
                    HStack(spacing: 0) {
                        ForEach(AppPage.allCases) { page in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPage = page
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: page.icon)
                                        .font(.system(size: 20))
                                    
                                    Text(page.title)
                                        .font(.caption2)
                                }
                                .foregroundColor(currentPage == page ? .accentColor : .gray)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                            radius: 15, x: 0, y: -5)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .fullScreenCover(isPresented: $showGame) {
                // Yeni oyun için seçilen zorluk seviyesinde oyun başlat
                GameView(difficulty: selectedCustomDifficulty)
            }
            .fullScreenCover(isPresented: $showTutorial) {
                // Tutorial görünümü
                TutorialView()
            }
            .alert(isPresented: $showTutorialPrompt) {
                Alert(
                    title: Text("Rehberi Göster"),
                    message: Text("Rehberi tekrar görmek istiyor musunuz?"),
                    primaryButton: .default(Text("Evet")) {
                        showTutorial = true
                    },
                    secondaryButton: .cancel(Text("Hayır"))
                )
            }
        }
        .onAppear {
            setupSavedGameNotification()
        }
    }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
