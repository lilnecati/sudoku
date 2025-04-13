//  ScoreboardView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 20.01.2025.
//

import SwiftUI
import CoreData

struct ScoreboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDifficulty: SudokuBoard.Difficulty = .easy
    @State private var statistics: ScoreboardStatistics = ScoreboardStatistics()
    @State private var recentScores: [NSManagedObject] = []
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Başlık
                Text("Skor Tablosu")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textColor(for: colorScheme))
                    .padding(.top)
                
                // Sekme kontrolü - Picker yerine butonlar kullanalım
                HStack(spacing: 0) {
                    tabButton(title: "Genel", tag: 0)
                    tabButton(title: "Zorluk", tag: 1)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                if selectedTab == 0 {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Zorluk seviyesi seçici
                            difficultySelector
                            
                            // İstatistik kartları
                            statisticsView
                            
                            // Oyun istatistik kartları
                            gameStatsView
                            
                            // Son oyunlar
                            recentGamesView
                        }
                        .padding(.bottom)
                    }
                    .padding(.top, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Zorluk seviyesi seçici
                            difficultySelector
                            
                            // Zorluk seviyesi karşılaştırma
                            difficultyComparisonView
                        }
                        .padding(.bottom)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .animation(nil, value: selectedTab) // Tab içeriği değişimini animasyonsuz yap
        .onChange(of: selectedDifficulty) { oldValue, newValue in
            loadData()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Tab değiştirildiğinde verileri güncelle
            loadData()
        }
        .onAppear {
            loadData()
        }
    }
    
    // Zorluk seviyesi seçici
    private var difficultySelector: some View {
        HStack(spacing: 8) {
            ForEach(SudokuBoard.Difficulty.allCases) { difficulty in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDifficulty = difficulty
                    }
                }) {
                    VStack(spacing: 2) {
                        // Zorluk seviyesi ikonu
                        Image(systemName: getDifficultyIcon(difficulty))
                            .font(.system(size: 16))
                            .padding(.top, 2)
                        
                        // Kısaltılmış yazı
                        Text(difficulty.localizedName)
                            .font(.system(size: 10, weight: .medium))
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
                                    .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
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
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDifficulty)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
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

    private var statisticsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Performans İstatistikleri")
                    .font(.headline)
                    .foregroundColor(.primary)
                
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
                    colorScheme: colorScheme
                )
                
                StatCard(
                    title: "Ortalama Skor",
                    value: String(format: "%.0f", statistics.averageScore),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [getDifficultyColor(selectedDifficulty).opacity(0.7), getDifficultyColor(selectedDifficulty).opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
        )
        .padding(.horizontal)
    }
    
    private var gameStatsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Oyun İstatistikleri")
                    .font(.headline)
                    .foregroundColor(.primary)
                
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
                    title: "Tamamlanan Oyunlar",
                    value: "\(statistics.totalGames)",
                    icon: "checkmark.circle.fill",
                    color: getDifficultyColor(selectedDifficulty),
                    colorScheme: colorScheme
                )
                
                StatCard(
                    title: "Ortalama Süre",
                    value: formatTime(statistics.averageTime),
                    icon: "clock.fill",
                    color: .orange,
                    colorScheme: colorScheme
                )
                
                StatCard(
                    title: "En Hızlı Oyun",
                    value: formatTime(statistics.bestTime),
                    icon: "bolt.fill",
                    color: .purple,
                    colorScheme: colorScheme
                )
                
                StatCard(
                    title: "Başarı Oranı",
                    value: "\(Int(statistics.successRate * 100))%",
                    icon: "percent",
                    color: .teal,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [getDifficultyColor(selectedDifficulty).opacity(0.7), getDifficultyColor(selectedDifficulty).opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
        )
        .padding(.horizontal)
    }
    
    private var recentGamesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Son Oyunlar")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "clock.arrow.circlepath")
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
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [getDifficultyColor(selectedDifficulty).opacity(0.7), getDifficultyColor(selectedDifficulty).opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
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
                    
                    Text("puan")
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
                                
                                Text(difficultyString)
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
        
        switch difficulty {
        case .easy:
            return .green
        case .medium:
            return .blue
        case .hard:
            return .orange
        case .expert:
            return .red
        }
    }
    
    private var difficultyComparisonView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Zorluk Seviyesi Karşılaştırma")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(getDifficultyColor(selectedDifficulty))
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                ForEach(SudokuBoard.Difficulty.allCases) { difficulty in
                    VStack(spacing: 8) {
                        // Zorluk seviyesi ikonu
                        Image(systemName: getDifficultyIcon(difficulty))
                            .font(.system(size: 20))
                            .foregroundColor(getDifficultyColor(difficulty))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(getDifficultyColor(difficulty).opacity(0.15))
                            )
                        
                        Text(difficulty.localizedName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let bestScore = getBestScoreForDifficulty(difficulty)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [getDifficultyColor(difficulty).opacity(0.15), getDifficultyColor(difficulty).opacity(0.05)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [getDifficultyColor(difficulty).opacity(0.4), getDifficultyColor(difficulty).opacity(0.2)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            
                            Text("\(bestScore)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(getDifficultyColor(difficulty))
                        }
                        
                        Text("puan")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }
            }
            .padding()
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [getDifficultyColor(selectedDifficulty).opacity(0.7), getDifficultyColor(selectedDifficulty).opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
        )
        .padding(.horizontal)
    }
    
    private func loadData() {
        print("📊 Skor tablosu yükleniyor - Zorluk seviyesi: \(selectedDifficulty.rawValue)")
        
        let bestScore = ScoreManager.shared.getBestScore(for: selectedDifficulty)
        let averageScore = ScoreManager.shared.getAverageScore(for: selectedDifficulty)
        
        // Oyun sayısını ve ortalama süreyi hesapla
        let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
        request.predicate = NSPredicate(format: "difficulty == %@", selectedDifficulty.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let scores = try context.fetch(request)
            let totalGames = scores.count
            
            print("📝 \(selectedDifficulty.rawValue) zorluk seviyesi için \(totalGames) skor bulundu")
            
            // Son oyunları kaydet
            recentScores = scores
            
            if !scores.isEmpty {
                // İlk skorun detaylarını göster
                if let firstScore = scores.first {
                    let id = firstScore.value(forKey: "id") as? UUID
                    let date = firstScore.value(forKey: "date") as? Date
                    let totalScore = firstScore.value(forKey: "totalScore") as? Int ?? 0
                    let elapsedTime = firstScore.value(forKey: "elapsedTime") as? Double ?? 0
                    print("📋 İlk skor - ID: \(id?.uuidString ?? "ID yok"), Tarih: \(date?.description ?? "Tarih yok"), Puan: \(totalScore), Süre: \(elapsedTime)")
                }
            } else {
                print("⚠️ Bu zorluk seviyesi için kayıtlı skor bulunamadı")
            }
            
            var totalTime: TimeInterval = 0
            var bestTime = Double.infinity
            var totalScore = 0
            var bestTotalScore = 0
            
            for score in scores {
                if let time = score.value(forKey: "elapsedTime") as? Double {
                    totalTime += time
                    bestTime = min(bestTime, time)
                }
                
                // Yeni skor alanını kullan (yoksa eski hesaplama yöntemi)
                if let scoreValue = score.value(forKey: "totalScore") as? Int, scoreValue > 0 {
                    totalScore += scoreValue
                    bestTotalScore = max(bestTotalScore, scoreValue)
                } else {
                    // Eski hesaplama yöntemi
                    if let time = score.value(forKey: "elapsedTime") as? Double {
                        let calculatedScore = Int(10000 / (time + 1))
                        totalScore += calculatedScore
                        bestTotalScore = max(bestTotalScore, calculatedScore)
                    }
                }
            }
            
            let averageTime = totalGames > 0 ? totalTime / Double(totalGames) : 0
            let calculatedAverageScore = totalGames > 0 ? Double(totalScore) / Double(totalGames) : 0
            let successRate: Double = totalGames > 0 ? 1.0 : 0.0 // Tüm oyunlar tamamlanmış kabul edilir
            
            statistics = ScoreboardStatistics(
                totalGames: totalGames,
                totalScore: totalScore,
                averageScore: calculatedAverageScore,
                bestScore: bestTotalScore > 0 ? bestTotalScore : bestScore, // Yeni en yüksek skoru kullan
                averageTime: averageTime,
                bestTime: bestTime < Double.infinity ? bestTime : 0,
                successRate: successRate
            )
        } catch {
            print("❌ Oyun istatistikleri alınamadı: \(error.localizedDescription)")
            statistics = ScoreboardStatistics(
                totalGames: 0,
                totalScore: 0,
                averageScore: averageScore,
                bestScore: bestScore,
                averageTime: 0,
                bestTime: 0,
                successRate: 0
            )
        }
    }
    
    private func getBestScoreForDifficulty(_ difficulty: SudokuBoard.Difficulty) -> Int {
        return ScoreManager.shared.getBestScore(for: difficulty)
    }
    
    private func getDifficultyColor(_ difficulty: SudokuBoard.Difficulty) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .medium:
            return .blue
        case .hard:
            return .orange
        case .expert:
            return .red
        }
    }
    
    // Tab butonları
    private func tabButton(title: String, tag: Int) -> some View {
        Button(action: {
            // Animasyonu kaldır
            selectedTab = tag
        }) {
            Text(title)
                .font(.system(size: 16, weight: selectedTab == tag ? .semibold : .medium))
                .foregroundColor(selectedTab == tag ? .blue : .primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    ZStack {
                        if selectedTab == tag {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.12))
                        }
                    }
                )
        }
        .foregroundColor(selectedTab == tag ? .blue : .primary)
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
    
    var body: some View {
        VStack(spacing: 10) {
            // Başlık ve ikon
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.5), color.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct RecentGameRow: View {
    let score: NSManagedObject
    let rank: Int
    @Environment(\.colorScheme) var colorScheme
    
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
                        
                        Text("puan")
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
                                
                                Text(difficultyString)
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
    
    // Zorluk seviyesine göre renk - ScoreboardView'dakinin aynısı
    private func getDifficultyColor() -> Color {
        guard let difficultyString = score.value(forKey: "difficulty") as? String,
              let difficulty = SudokuBoard.Difficulty(rawValue: difficultyString) else {
            return .blue
        }
        
        switch difficulty {
        case .easy:
            return .green
        case .medium:
            return .blue
        case .hard:
            return .orange
        case .expert:
            return .red
        }
    }
    
    // Zorluk seviyesi metin stringinden ikonu döndürür - ScoreboardView'dakinin aynısı
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
    var totalScore: Int = 0
    var averageScore: Double = 0
    var bestScore: Int = 0
    var averageTime: TimeInterval = 0
    var bestTime: TimeInterval = 0
    var successRate: Double = 0
}
