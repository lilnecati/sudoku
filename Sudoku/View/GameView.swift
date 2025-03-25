import SwiftUI
import CoreData

struct GameView: View {
    @StateObject var viewModel: SudokuViewModel
    @State private var showDifficultyPicker = false
    @State private var showingGameComplete = false
    @State private var showSettings = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // Önbellekleme ve performans için
    @State private var timeDisplay: String = "00:00"
    @State private var boardKey = UUID().uuidString // Zorla tahtayı yenilemek için
    private let timerUpdateInterval: TimeInterval = 1.0
    
    // Premium ve ipucu ayarları
    @AppStorage("isPremiumUnlocked") private var isPremiumUnlocked: Bool = false
    
    // Hint messages
    @State private var showNoHintsMessage: Bool = false
    
    // Animasyon değişkenleri
    @State private var isHeaderVisible = false
    @State private var isBoardVisible = false
    @State private var isControlsVisible = false
    
    // Rehberlik yöneticisi
    @StateObject private var tutorialManager = TutorialManager()
    @State private var showTutorialButton = true
    
    // Arka plan gradient renkleri - önbelleklenmiş
    private var gradientColors: [Color] {
        colorScheme == .dark ?
        [Color(.systemGray6), Color.blue.opacity(0.15)] :
        [Color(.systemBackground), Color.blue.opacity(0.05)]
    }
    
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
    }
    
    @State private var showCompletionView = false
    
    var body: some View {
        ZStack {
            // Aktif olmadığında gizlenecek boş alan (sayfa geçişleri için)
            // Arka plan
            LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            // Ana içerik
            VStack(spacing: 10) {
                // Rehber butonu
                if showTutorialButton && !tutorialManager.hasCompletedTutorial {
                    HStack {
                        Spacer()
                        TutorialButton {
                            tutorialManager.startTutorial()
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.horizontal)
                }
                Spacer()
                
                // Üst bilgi alanı
                headerView
                    .padding(.horizontal)
                    .padding(.bottom, 5) // Tablo ile üst bilgi arasında ufak boşluk
                    .opacity(isHeaderVisible ? 1 : 0)
                    .offset(y: isHeaderVisible ? 0 : -20)
                
                // Sudoku tahtası - sabit boyutlu konteyner içinde
                ZStack {
                    // Sabit görünmez arka plan - boyutları korumak için
                    Rectangle()
                        .foregroundColor(.clear)
                        .aspectRatio(1, contentMode: .fit)
                    
                    // Sudoku tahtası
                    SudokuBoardView(viewModel: viewModel)
                        .id(boardKey)
                        .aspectRatio(1, contentMode: .fit)
                }
                .padding(.horizontal, 5)
                .opacity(isBoardVisible ? 1 : 0)
                .scaleEffect(isBoardVisible ? 1 : 0.95)
                // Boyut sabitleme
                .fixedSize(horizontal: false, vertical: true)
                // Tahta boyutunun değişmemesi için
                .drawingGroup()
                
                Spacer()
                
                // Oyun kontrolleri - sabit boyutlu konteyner
                // Boyut değişimi olmayacak şekilde sabitlenmiş
                ZStack {
                    // Sabit boyut garantisi için boş konteyner
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: 250) // Sabit yükseklik
                    
                    // Asıl kontroller
                    controlsView
                        .padding(.horizontal)
                        .clipped() // Taşmaları engelle
                }
                .padding(.bottom, 70) // Tab bar için ekstra boşluk ekledim
                .opacity(isControlsVisible ? 1 : 0)
                .offset(y: isControlsVisible ? 0 : 20)
                // Sabit boyutlar
                .fixedSize(horizontal: false, vertical: true)
                // Görünüm stabilitesi için
                .drawingGroup()
            }
            .padding(.top, 10)
            
            // Uyarı ve bilgi ekranları
            overlayViews
            
            // Rehber katmanı
            if tutorialManager.isActive {
                TutorialOverlayView(tutorialManager: tutorialManager) {
                    withAnimation {
                        tutorialManager.stopTutorial()
                        showTutorialButton = false
                    }
                }
                .transition(.opacity)
            }
            
            // Zorluk seçici
            if showDifficultyPicker {
                difficultyPickerView
            }
            
            // Oyun tamamlama ekranı
            if showCompletionView {
                GameCompletionView(
                    difficulty: viewModel.board.difficulty,
                    timeElapsed: viewModel.elapsedTime,
                    errorCount: viewModel.errorCount,
                    hintCount: 3 - viewModel.remainingHints,
                    score: viewModel.calculatePerformanceScore(),
                    isNewHighScore: isNewHighScore(),
                    onNewGame: {
                        showCompletionView = false
                        showDifficultyPicker = true
                    },
                    onDismiss: {
                        showCompletionView = false
                    }
                )
                .padding()
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: viewModel.pencilMode) { oldValue, newValue in
            // Hafif titreşim
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
        }
        .onChange(of: viewModel.gameState) { oldValue, newValue in
            if newValue == .completed && oldValue != .completed {
                withAnimation {
                    showCompletionView = true
                }
            }
        }
        .onAppear {
            setupInitialAnimations()
            setupTimerUpdater()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDifficultyPicker) {
            difficultyPickerView
        }
        .alert("Tebrikler!", isPresented: $showingGameComplete) {
            Button("Tamam", role: .cancel) {}
            Button("Yeni Oyun") {
                showDifficultyPicker = true
            }
        } message: {
            Text("Sudoku bulmacasını \(timeString(from: viewModel.elapsedTime)) sürede tamamladınız!")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        )
                }
                
                Spacer()
                
                // Oyun başlığı
                Text("Sudoku")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Ayarlar butonu
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
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
                        Text(viewModel.pencilMode ? "Not Aktif" : "Not Modu")
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
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    // Uyarı ve bilgi ekranları
    private var overlayViews: some View {
        Group {
            if showDifficultyPicker {
                difficultyPickerView
            }
            
            if showingGameComplete {
                congratulationsView
            }
            
            if viewModel.gameState == .failed {
                gameOverView
            }
            
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
                        .padding(.bottom, 100)
                        .transition(.opacity)
                }
                .zIndex(100)
                .transition(.opacity)
                .animation(.easeInOut, value: showNoHintsMessage)
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !tutorialManager.hasCompletedTutorial && viewModel.gameState == .playing {
                tutorialManager.startTutorial()
            }
        }
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
            return "Hazır"
        case .playing:
            return viewModel.pencilMode ? "Kalem Modu" : "Oynanıyor"
        case .paused:
            return "Duraklatıldı"
        case .completed:
            return "Tamamlandı"
        case .failed:
            return "Kaybedildi"
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
                            .strokeBorder(ColorManager.primaryRed, lineWidth: 1)
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
            Image(systemName: "trophy.fill")
                .font(.system(size: 75))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorManager.primaryGreen, ColorManager.primaryBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .yellow.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Tebrikler!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Text("Sudoku bulmacasını \(timeString(from: viewModel.elapsedTime)) sürede tamamladınız!")
                .font(.headline)
                .multilineTextAlignment(.center)
            
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
                showDifficultyPicker = true
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [ColorManager.primaryGreen, ColorManager.primaryBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(.white)
                .shadow(color: ColorManager.primaryBlue.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 10)
        }
        .padding(25)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.95) : Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: colorScheme == .dark ? 0.5 : 0
                )
        )
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
                showDifficultyPicker = true
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

// View uzantısı
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// RoundedCorner uzantısı
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // İkon
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    // Açıklama
                    Text(description)
                        .font(.system(size: 12))
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