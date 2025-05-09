//  ScoreboardView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 20.01.2025.
//

import SwiftUI
import CoreData

struct ScoreboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.textScale) var textScale
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedDifficulty: SudokuBoard.Difficulty = .easy
    @State private var statistics: ScoreboardStatistics = ScoreboardStatistics()
    @State private var recentScores: [NSManagedObject] = []
    
    // Bej mod için kısa bir hesaplama ekleyelim
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Detaylı istatistik sayfasına geçiş için state
    @State private var showDetailedStatistics = false
    
    // Yükleniyor durumu için state
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Başlık
                HStack {
                    Text.localizedSafe("Skor Tablosu")
                        .font(.system(size: 28 * textScale, weight: .bold, design: .rounded))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : Color.textColor(for: colorScheme))
                    
                    Spacer()
                    
                    // Detaylı istatistik butonu
                    Button {
                        showDetailedStatistics = true
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20))
                            .foregroundColor(getDifficultyColor(selectedDifficulty))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(isBejMode ? 
                                         ThemeManager.BejThemeColors.cardBackground : 
                                         (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                    }
                }
                .padding(.top)
                .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Zorluk seviyesi seçici
                        difficultySelector(textScale: textScale)
                            .drawingGroup() // Metal hızlandırma ekleyelim
                        
                        // İstatistik kartları
                        statisticsView(textScale: textScale)
                            .drawingGroup() // Metal hızlandırma ekleyelim
                        
                        // Oyun istatistik kartları
                        gameStatsView(textScale: textScale)
                        
                        // Son oyunlar
                        recentGamesView(textScale: textScale)
                    }
                    .padding(.bottom)
                }
                .padding(.top, 8)
            }
            
            // <<< YENİ: Yükleme göstergesi >>>
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding()
                    .background(isBejMode ? 
                               ThemeManager.BejThemeColors.background.opacity(0.3) : 
                               Color.black.opacity(0.3))
                    .cornerRadius(10)
            }
        }
        .animation(nil, value: selectedDifficulty) // Zorluk seçimi değişimini animasyonsuz yap
        .onChange(of: selectedDifficulty) { oldValue, newValue in
            // <<< DEĞİŞİKLİK: Gecikmeyi kaldır >>>
            loadData()
        }
        .onAppear {
            // Ekran kararması yönetimi SudokuApp'a devredildi
            isLoading = true // Yükleme göstergesini başlat
            logInfo("ScoreboardView onAppear - Veri yükleniyor...")
            PersistenceController.shared.refreshHighScores()
            isLoading = false
            loadData()
            setupLanguageChangeListener()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStatistics"))) { _ in
            logInfo("ScoreboardView: İstatistikler yenileme bildirimi alındı")
            loadData()
        }
        // Detaylı istatistik sayfasına geçiş
        .fullScreenCover(isPresented: $showDetailedStatistics) {
            DetailedStatisticsView()
                .environmentObject(LocalizationManager.shared)
                .environmentObject(themeManager)
        }
    }
    
    // Zorluk seviyesi seçici
    private func difficultySelector(textScale: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(SudokuBoard.Difficulty.allCases) { difficulty in
                Button(action: {
                    // Daha performanslı bir geçiş için animasyonu kaldıralım
                        selectedDifficulty = difficulty
                }) {
                    VStack(spacing: 2) {
                        // Zorluk seviyesi ikonu
                        Image(systemName: getDifficultyIcon(difficulty))
                            .font(.system(size: 16))
                            .padding(.top, 2)
                        
                        // Kısaltılmış yazı
                        Text(difficulty.localizedName)
                            .font(.system(size: 10 * textScale, weight: .medium))
                            .lineLimit(1)
                            .padding(.bottom, 2)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            if selectedDifficulty == difficulty {
                                Capsule()
                                    .fill(getDifficultyColor(difficulty))
                                    .shadow(color: getDifficultyColor(difficulty).opacity(0.4), radius: 4, x: 0, y: 2)
                            } else {
                                Capsule()
                                    .fill(isBejMode ? 
                                         ThemeManager.BejThemeColors.cardBackground.opacity(0.2) : 
                                         (colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    )
                    .foregroundColor(selectedDifficulty == difficulty ? .white : Color.primary.opacity(0.8))
                    .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                // Animasyonu kaldırdık
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    // Zorluk seviyesi ikonu
    private func getDifficultyIcon(_ difficulty: SudokuBoard.Difficulty) -> String {
        switch difficulty {
        case .easy:
            return "leaf.fill"
        case .medium:
            return "flame.fill"
        case .hard:
            return "bolt.fill"
        case .expert:
            return "star.fill"
        }
    }

    private func statisticsView(textScale: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text.localizedSafe("Performans İstatistikleri")
                    .font(.system(size: Font.TextStyle.headline.defaultSize * textScale))
                    .foregroundColor(isBejMode ? 
                                    ThemeManager.BejThemeColors.text : 
                                    .primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(getDifficultyColor(selectedDifficulty))
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "En Yüksek Skor",
                    value: "\(statistics.bestScore)",
                    icon: "star.fill",
                    color: .yellow,
                    colorScheme: colorScheme,
                    textScale: textScale
                )
                
                StatCard(
                    title: "Ortalama Skor",
                    value: String(format: "%.0f", statistics.averageScore),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    colorScheme: colorScheme,
                    textScale: textScale
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    private func gameStatsView(textScale: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text.localizedSafe("Oyun İstatistikleri")
                    .font(.system(size: Font.TextStyle.headline.defaultSize * textScale))
                    .foregroundColor(isBejMode ? 
                                    ThemeManager.BejThemeColors.text : 
                                    .primary)
                
                Spacer()
                
                Image(systemName: "gamecontroller.fill")
                    .foregroundColor(getDifficultyColor(selectedDifficulty))
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Toplam Oyunlar",
                    value: "\(statistics.totalGames)",
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    colorScheme: colorScheme,
                    textScale: textScale
                )
                
                StatCard(
                    title: getLocalizedDifficultyGamesText(selectedDifficulty),
                    value: "\(statistics.difficultyGames)",
                    icon: getDifficultyIcon(selectedDifficulty),
                    color: getDifficultyColor(selectedDifficulty),
                    colorScheme: colorScheme,
                    textScale: textScale
                )
                
                StatCard(
                    title: "Ortalama Süre",
                    value: formatTime(statistics.averageTime),
                    icon: "clock.fill",
                    color: .orange,
                    colorScheme: colorScheme,
                    textScale: textScale
                )
                
                StatCard(
                    title: "En Hızlı Oyun",
                    value: formatTime(statistics.bestTime),
                    icon: "bolt.fill",
                    color: .purple,
                    colorScheme: colorScheme,
                    textScale: textScale
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    private func recentGamesView(textScale: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text.localizedSafe("Son Oyunlar")
                    .font(.system(size: Font.TextStyle.headline.defaultSize * textScale))
                    .foregroundColor(isBejMode ? 
                                    ThemeManager.BejThemeColors.text : 
                                    .primary)
                
                Spacer()
                
                Image(systemName: "clock.fill")
                    .foregroundColor(getDifficultyColor(selectedDifficulty))
            }
            .padding(.horizontal)
            
            if recentScores.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Text("Henüz tamamlanmış oyun yok")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack {
                    ForEach(0..<min(recentScores.count, 5), id: \.self) { index in
                        let currentScore = recentScores[index]
                        
                        VStack {
                            scoreCard(for: currentScore)
                                .drawingGroup()
                            
                            if index < min(recentScores.count, 5) - 1 {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func scoreCard(for score: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                // Puan
                VStack(alignment: .leading, spacing: 2) {
                    // Skor
                    let scoreValue = calculateScore(for: score)
                    
                    Text("\(scoreValue)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(getDifficultyColor(for: score))
                        .minimumScaleFactor(0.7)
                    
                    Text.localizedSafe("puan")
                        .font(.caption)
                        .foregroundColor(getDifficultyColor(for: score).opacity(0.7))
                }
                .frame(width: 110, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Zorluk
                        if let difficultyString = score.value(forKey: "difficulty") as? String {
                            HStack(spacing: 4) {
                                Image(systemName: getDifficultyIconFromString(difficultyString))
                                    .font(.system(size: 12))
                                
                                Text.localizedSafe(difficultyString)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [getDifficultyColor(for: score).opacity(0.15), getDifficultyColor(for: score).opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [getDifficultyColor(for: score).opacity(0.4), getDifficultyColor(for: score).opacity(0.2)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .foregroundColor(getDifficultyColor(for: score))
                        }
                        
                        Spacer()
                        
                        // Tarih - geliştirilmiş
                        if let date = score.value(forKey: "date") as? Date {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                
                                Text(formatDate(date))
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // İstatistikler - SavedGamesView tarzında geliştirilmiş
                    statsSection(for: score)
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 12)
        .frame(height: 120)
    }
    
    // Geliştirilmiş istatistik öğesi
    private func statsSection(for score: NSManagedObject) -> some View {
        HStack(spacing: 12) {
            // Süre - geliştirilmiş görselleştirme
            let elapsedTime = score.value(forKey: "elapsedTime") as? Double ?? 0
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
                    )
                
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .padding(.trailing, 2)
                    
                    Text("\(minutes):\(String(format: "%02d", seconds))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            // Hata sayısı - geliştirilmiş görselleştirme
            if let errorCount = score.value(forKey: "errorCount") as? Int {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.12), Color.red.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        
                        Text("\(errorCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // İpucu sayısı - geliştirilmiş görselleştirme
            if let hintCount = score.value(forKey: "hintCount") as? Int {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow.opacity(0.12), Color.yellow.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    HStack(spacing: 2) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text("\(hintCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // Skor hesaplama
    private func calculateScore(for score: NSManagedObject) -> Int {
        if let totalScore = score.value(forKey: "totalScore") as? Int, totalScore > 0 {
            return totalScore
        } else {
            // Geliştirilmiş skor hesaplama formülü
            let elapsedTime = score.value(forKey: "elapsedTime") as? Double ?? 0
            let errorCount = score.value(forKey: "errorCount") as? Int ?? 0
            let hintCount = score.value(forKey: "hintCount") as? Int ?? 0
            
            // Temel puan: süreye göre hesaplama
            let baseScore = Int(10000 / (elapsedTime + 1))
            
            // Hata ve ipucu için düzeltme faktörü (her hata %5, her ipucu %10 puan azaltır)
            let penaltyFactor = max(0.0, 1.0 - (Double(errorCount) * 0.05 + Double(hintCount) * 0.1))
            
            // Zorluk seviyesi katsayısı (opsiyonel)
            var difficultyMultiplier = 1.0
            if let difficultyString = score.value(forKey: "difficulty") as? String,
               let difficulty = SudokuBoard.Difficulty(rawValue: difficultyString) {
                switch difficulty {
                case .easy: difficultyMultiplier = 1.0
                case .medium: difficultyMultiplier = 1.2
                case .hard: difficultyMultiplier = 1.5
                case .expert: difficultyMultiplier = 2.0
                }
            }
            
            // Final skor hesaplama
            return Int(Double(baseScore) * penaltyFactor * difficultyMultiplier)
        }
    }
    
    // Zorluk seviyesine göre renk
    private func getDifficultyColor(for score: NSManagedObject) -> Color {
        guard let difficultyString = score.value(forKey: "difficulty") as? String,
              let difficulty = SudokuBoard.Difficulty(rawValue: difficultyString) else {
            return .blue
        }
        
        return getDifficultyColor(difficulty)
    }
    
    private func getDifficultyColor(_ difficulty: SudokuBoard.Difficulty) -> Color {
        if themeManager.bejMode {
            switch difficulty {
            case .easy:
                return Color(red: 0.4, green: 0.6, blue: 0.3) // Bej uyumlu yeşil
            case .medium:
                return Color(red: 0.7, green: 0.5, blue: 0.2) // Bej uyumlu turuncu
            case .hard:
                return Color(red: 0.7, green: 0.3, blue: 0.2) // Bej uyumlu kırmızı
            case .expert:
                return Color(red: 0.5, green: 0.3, blue: 0.5) // Bej uyumlu mor
            }
        } else {
            switch difficulty {
            case .easy:
                return .green
            case .medium:
                return .orange
            case .hard:
                return .red
            case .expert:
                return .purple
            }
        }
    }
    
    private func loadData() {
        logInfo("Skor tablosu yükleniyor - Zorluk seviyesi: \(selectedDifficulty.rawValue)")
        // <<< YENİ: Yükleme durumunu başlat >>>
        isLoading = true
        
        // <<< YENİ: Arka plan iş parçacığına taşı >>>
        DispatchQueue.global(qos: .userInitiated).async {
            // Arka planda yapılacaklar:
            let context = PersistenceController.shared.container.viewContext
            var loadedStatistics = ScoreboardStatistics() // Geçici istatistik nesnesi
            var loadedRecentScores: [NSManagedObject] = [] // Geçici skor listesi
            
            // Verileri CoreData'dan çek ve hesapla
            do {
                // Seçili zorluk seviyesi için skorları hesapla
                let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
                request.predicate = NSPredicate(format: "difficulty == %@", selectedDifficulty.rawValue)
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                
                // <<< DEĞİŞİKLİK: Fetch yerine count kullan >>>
                let totalGamesRequest = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
                // Count için predicate veya sort descriptor gerekmez, ama istersen ekleyebilirsin.
                
                // Fetch işlemlerini context.performAndWait içinde yapmak daha güvenli olabilir
                // ancak burada doğrudan fetch yapıyoruz, context'in doğru thread'de olduğundan emin olmalıyız.
                // Bu global queue'da yapıldığı için sorun olmamalı.
                let scores = try context.fetch(request)
                // <<< DEĞİŞİKLİK: Fetch yerine count kullan >>>
                let totalGamesCount = try context.count(for: totalGamesRequest)
                
                loadedStatistics.difficultyGames = scores.count
                // <<< DEĞİŞİKLİK: Fetch edilen array yerine count sonucunu kullan >>>
                loadedStatistics.totalGames = totalGamesCount 
                loadedRecentScores = scores // Son oyunları geçici listeye al
                
                logInfo("\(selectedDifficulty.rawValue) zorluk seviyesi için \(loadedStatistics.difficultyGames) skor bulundu")
                // <<< DEĞİŞİKLİK: Doğru değişkeni logla >>>
                logInfo("Tüm zorluk seviyeleri için toplam \(loadedStatistics.totalGames) skor bulundu (count ile)")
                
                var totalTime: TimeInterval = 0
                var bestTime = Double.infinity
                var totalScoreValue = 0 // Int olarak başlatalım
                var bestScoreValue = 0 // Int olarak başlatalım
                
                for score in scores {
                    if let time = score.value(forKey: "elapsedTime") as? Double {
                        totalTime += time
                        bestTime = min(bestTime, time)
                    }
                    let currentScoreValue = calculateScore(for: score) // Skoru burada hesapla
                    totalScoreValue += currentScoreValue
                    bestScoreValue = max(bestScoreValue, currentScoreValue)
                }
                
                if !scores.isEmpty {
                    loadedStatistics.averageTime = totalTime / Double(scores.count)
                    loadedStatistics.bestTime = bestTime == Double.infinity ? 0 : bestTime // Eğer hiç skor yoksa 0 yap
                    loadedStatistics.averageScore = Double(totalScoreValue) / Double(scores.count) // Double'a çevirerek böl
                    loadedStatistics.bestScore = bestScoreValue
                } else {
                    // Skor yoksa varsayılan değerler
                    loadedStatistics.averageTime = 0
                    loadedStatistics.bestTime = 0
                    loadedStatistics.averageScore = 0
                    loadedStatistics.bestScore = 0
                }
                
            } catch {
                logError("Skor verileri yüklenirken hata: \(error.localizedDescription)")
                // Hata durumunda istatistikleri sıfırla veya uygun bir değer ata
                loadedStatistics = ScoreboardStatistics() // Varsayılana dön
                loadedRecentScores = []
            }
            
            // <<< YENİ: Ana iş parçacığına dön ve state'leri güncelle >>>
            DispatchQueue.main.async {
                self.statistics = loadedStatistics
                self.recentScores = loadedRecentScores
                self.isLoading = false // Yükleme durumunu bitir
                logInfo("Skor tablosu verileri başarıyla yüklendi ve UI güncellendi.")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    // Zorluk seviyesi metin stringinden ikonu döndürür
    private func getDifficultyIconFromString(_ difficultyString: String) -> String {
        switch difficultyString {
        case "Kolay":
            return "leaf.fill"
        case "Orta":
            return "flame.fill"
        case "Zor":
            return "bolt.fill"
        case "Uzman":
            return "star.fill"
        default:
            return "questionmark"
        }
    }
    
    // Zorluk seviyesine özel oyunlar metni için yardımcı fonksiyon
    private func getLocalizedDifficultyGamesText(_ difficulty: SudokuBoard.Difficulty) -> String {
        // Zorluk seviyesi + "Oyunları" birleşimini yerelleştirmek için
        switch difficulty {
        case .easy:
            return "Kolay Oyunları"
        case .medium:
            return "Orta Oyunları"
        case .hard:
            return "Zor Oyunları"
        case .expert:
            return "Uzman Oyunları"
        }
    }
    
    private func setupLanguageChangeListener() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("LanguageChanged"), object: nil, queue: .main) { _ in
            // Dil değiştiğinde verileri yeniden yükle
            self.loadData()
        }
    }
}

// Yardımcı fonksiyonlar
func formatTime(_ timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

// Yardımcı görünüm
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    let textScale: CGFloat
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama ekleyelim
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Temel font boyutları
    private var titleBaseSize: CGFloat = 13
    private var valueBaseSize: CGFloat = 24
    private var iconBaseSize: CGFloat = 12
    
    // Add explicit internal initializer
    internal init(title: String, value: String, icon: String, color: Color, colorScheme: ColorScheme, textScale: CGFloat) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.colorScheme = colorScheme
        self.textScale = textScale
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Başlık ve ikon
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: iconBaseSize * textScale))
                    .foregroundColor(.gray)
                Text.localizedSafe(title)
                    .font(.system(size: titleBaseSize * textScale))
                    .foregroundColor(isBejMode ? 
                                    ThemeManager.BejThemeColors.text : 
                                    .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            
            // Değer - geliştirilmiş görünüm
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.12), color.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 40)
                
                Text(value)
                    .font(.system(size: valueBaseSize * textScale, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .padding(12)
    }
}

struct RecentGameRow: View {
    let score: NSManagedObject
    let rank: Int
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        ZStack {
            // Kart arka planı - SavedGamesView stiline benzer şekilde geliştirildi
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95),
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.9) : getDifficultyColor().opacity(0.03)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    // Zorluk seviyesine göre renkli kenar çizgisi
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [getDifficultyColor().opacity(0.7), getDifficultyColor().opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
            
            HStack(spacing: 16) {
                // Sıralama ve puan bölümü (sol)
                VStack(spacing: 8) {
                    // Sıralama rozeti - geliştirilmiş
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [
                                            getDifficultyColor().opacity(0.9),
                                            getDifficultyColor().opacity(0.5)
                                        ]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: getDifficultyColor().opacity(0.4), radius: 5, x: 0, y: 3)
                            .frame(width: 50, height: 50)
                        
                        Text("#\(rank)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Skor - geliştirilmiş
                    VStack(spacing: 0) {
                        Text("\(calculateScore())")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text.localizedSafe("puan")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80)
                .padding(.leading, 8)
                
                // Orta ayırıcı çizgi - zarif gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [.clear, getDifficultyColor().opacity(0.3), .clear]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)
                    .padding(.vertical, 12)
                
                // Bilgiler bölümü (sağ)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Zorluk seviyesi - geliştirilmiş rozet
                        if let difficultyString = score.value(forKey: "difficulty") as? String {
                            HStack(spacing: 4) {
                                Image(systemName: getDifficultyIconFromString(difficultyString))
                                    .font(.system(size: 12))
                                
                                Text.localizedSafe(difficultyString)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [getDifficultyColor().opacity(0.15), getDifficultyColor().opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [getDifficultyColor().opacity(0.4), getDifficultyColor().opacity(0.2)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .foregroundColor(getDifficultyColor())
                        }
                        
                        Spacer()
                        
                        // Tarih - geliştirilmiş
                        if let date = score.value(forKey: "date") as? Date {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                
                                Text(formatDate(date))
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // İstatistikler - SavedGamesView tarzında geliştirilmiş
                    statsSection()
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
        }
        .frame(height: 120)
    }
    
    // Geliştirilmiş istatistik öğesi
    private func statsSection() -> some View {
        HStack(spacing: 12) {
            // Süre - geliştirilmiş görselleştirme
            let elapsedTime = score.value(forKey: "elapsedTime") as? Double ?? 0
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
                    )
                
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .padding(.trailing, 2)
                    
                    Text("\(minutes):\(String(format: "%02d", seconds))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            // Hata sayısı - geliştirilmiş görselleştirme
            if let errorCount = score.value(forKey: "errorCount") as? Int {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.12), Color.red.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        
                        Text("\(errorCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // İpucu sayısı - geliştirilmiş görselleştirme
            if let hintCount = score.value(forKey: "hintCount") as? Int {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow.opacity(0.12), Color.yellow.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    HStack(spacing: 2) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text("\(hintCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // Skor hesaplama
    private func calculateScore() -> Int {
        if let totalScore = score.value(forKey: "totalScore") as? Int, totalScore > 0 {
            return totalScore
        } else {
            // Geliştirilmiş skor hesaplama formülü
            let elapsedTime = score.value(forKey: "elapsedTime") as? Double ?? 0
            let errorCount = score.value(forKey: "errorCount") as? Int ?? 0
            let hintCount = score.value(forKey: "hintCount") as? Int ?? 0
            
            // Temel puan: süreye göre hesaplama
            let baseScore = Int(10000 / (elapsedTime + 1))
            
            // Hata ve ipucu için düzeltme faktörü (her hata %5, her ipucu %10 puan azaltır)
            let penaltyFactor = max(0.0, 1.0 - (Double(errorCount) * 0.05 + Double(hintCount) * 0.1))
            
            // Zorluk seviyesi katsayısı (opsiyonel)
            var difficultyMultiplier = 1.0
            if let difficultyString = score.value(forKey: "difficulty") as? String,
               let difficulty = SudokuBoard.Difficulty(rawValue: difficultyString) {
                switch difficulty {
                case .easy: difficultyMultiplier = 1.0
                case .medium: difficultyMultiplier = 1.2
                case .hard: difficultyMultiplier = 1.5
                case .expert: difficultyMultiplier = 2.0
                }
            }
            
            // Final skor hesaplama
            return Int(Double(baseScore) * penaltyFactor * difficultyMultiplier)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    // Zorluk seviyesine göre renk
    private func getDifficultyColor() -> Color {
        guard let difficultyString = score.value(forKey: "difficulty") as? String,
              let difficulty = SudokuBoard.Difficulty(rawValue: difficultyString) else {
            return .blue
        }
        
        return getDifficultyColor(difficulty)
    }
    
    private func getDifficultyColor(_ difficulty: SudokuBoard.Difficulty) -> Color {
        if themeManager.bejMode {
            switch difficulty {
            case .easy:
                return Color(red: 0.4, green: 0.6, blue: 0.3) // Bej uyumlu yeşil
            case .medium:
                return Color(red: 0.7, green: 0.5, blue: 0.2) // Bej uyumlu turuncu
            case .hard:
                return Color(red: 0.7, green: 0.3, blue: 0.2) // Bej uyumlu kırmızı
            case .expert:
                return Color(red: 0.5, green: 0.3, blue: 0.5) // Bej uyumlu mor
            }
        } else {
            switch difficulty {
            case .easy:
                return .green
            case .medium:
                return .orange
            case .hard:
                return .red
            case .expert:
                return .purple
            }
        }
    }
    
    // Zorluk seviyesi metin stringinden ikonu döndürür
    private func getDifficultyIconFromString(_ difficultyString: String) -> String {
        switch difficultyString {
        case "Kolay":
            return "leaf.fill"
        case "Orta":
            return "flame.fill"
        case "Zor":
            return "bolt.fill"
        case "Uzman":
            return "star.fill"
        default:
            return "questionmark"
        }
    }
}

// İstatistik modeli
struct ScoreboardStatistics {
    var totalGames: Int = 0
    var difficultyGames: Int = 0
    var totalScore: Int = 0
    var averageScore: Double = 0
    var bestScore: Int = 0
    var averageTime: TimeInterval = 0
    var bestTime: TimeInterval = 0
    var successRate: Double = 0
}

// Son kalan colorScheme kontrollerini güncelleyelim
// ScoreboardStatCard yapısı içindeki tüm renk kullanımlarını güncelleyelim
struct ScoreboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    let textScale: CGFloat
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Sol icon kısmı
            ZStack {
                Circle()
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            // Sağ text kısmı
            VStack(alignment: .leading, spacing: 4) {
                // Başlık
                Text.localizedSafe(title)
                    .font(.system(size: 14 * textScale))
                    .foregroundColor(isBejMode ? 
                                    ThemeManager.BejThemeColors.secondaryText : 
                                    .secondary)
                
                // Değer
                Text(value)
                    .font(.system(size: 20 * textScale, weight: .bold))
                    .foregroundColor(isBejMode ? 
                                    ThemeManager.BejThemeColors.text : 
                                    .primary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}
