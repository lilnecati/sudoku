import SwiftUI
import CoreData

struct ScoreboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDifficulty: SudokuBoard.Difficulty = .easy
    @State private var statistics: ScoreboardStatistics = ScoreboardStatistics()
    @State private var recentScores: [NSManagedObject] = []
    @State private var showingDetail = false
    @State private var selectedTab = 0
    @State private var selectedScore: NSManagedObject? = nil
    
    var body: some View {
        ZStack {
            // Arka plan
            Color.darkModeBackground(for: colorScheme)
                .ignoresSafeArea()
            
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                if selectedTab == 0 {
                    ScrollView {
                        LazyVStack(spacing: 16) {
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
                            // Zorluk seviyesi karşılaştırma
                            difficultyComparisonView
                        }
                        .padding(.bottom)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let score = selectedScore {
                ScoreDetailView(score: score)
            }
        }
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
    
    private var statisticsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Performans İstatistikleri")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
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
                    color: .yellow
                )
                
                StatCard(
                    title: "Ortalama Skor",
                    value: String(format: "%.0f", statistics.averageScore),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
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
                    .foregroundColor(.blue)
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
                    color: .blue
                )
                
                StatCard(
                    title: "Ortalama Süre",
                    value: formatTime(statistics.averageTime),
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "En Hızlı Oyun",
                    value: formatTime(statistics.bestTime),
                    icon: "bolt.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Başarı Oranı",
                    value: "\(Int(statistics.successRate * 100))%",
                    icon: "percent",
                    color: .teal
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private var recentGamesView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Son Oyunlar")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if recentScores.isEmpty {
                Text("Henüz oyun kaydı yok")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(0..<min(3, recentScores.count), id: \.self) { index in
                    let score = recentScores[index]
                    Button(action: {
                        // Detay görünümünü aç
                        selectedScore = score
                        showingDetail = true
                    }) {
                        RecentGameRow(score: score, rank: index + 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private var difficultyComparisonView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Zorluk Seviyesi Karşılaştırma")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                ForEach(SudokuBoard.Difficulty.allCases) { difficulty in
                    VStack(spacing: 8) {
                        Text(difficulty.localizedName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let bestScore = getBestScoreForDifficulty(difficulty)
                        Text("\(bestScore)")
                            .font(.headline)
                            .foregroundColor(getDifficultyColor(difficulty))
                        
                        Text("puan")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private func loadData() {
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
            
            // Son oyunları kaydet
            recentScores = scores
            
            var totalTime: TimeInterval = 0
            var bestTime = Double.infinity
            
            for score in scores {
                if let time = score.value(forKey: "elapsedTime") as? Double {
                    totalTime += time
                    bestTime = min(bestTime, time)
                }
            }
            
            let averageTime = totalGames > 0 ? totalTime / Double(totalGames) : 0
            let successRate: Double = totalGames > 0 ? 1.0 : 0.0 // Tüm oyunlar tamamlanmış kabul edilir
            
            statistics = ScoreboardStatistics(
                totalGames: totalGames,
                totalScore: 0,
                averageScore: averageScore,
                bestScore: bestScore,
                averageTime: averageTime,
                bestTime: bestTime < Double.infinity ? bestTime : 0,
                successRate: successRate
            )
        } catch {
            print("Oyun istatistikleri alınamadı: \(error.localizedDescription)")
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
    
    // Tab butonu
    private func tabButton(title: String, tag: Int) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedTab = tag
            }
        }) {
            Text(title)
                .fontWeight(selectedTab == tag ? .semibold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if selectedTab == tag {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.2))
                                .padding(2)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(selectedTab == tag ? .blue : .primary)
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
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct RecentGameRow: View {
    let score: NSManagedObject
    let rank: Int
    
    var body: some View {
        HStack {
            // Sıralama
            Text("#\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 40)
            
            // Skor detayları
            VStack(alignment: .leading, spacing: 4) {
                // HighScore entity'sinde elapsedTime kullanılıyor, bunu puana çeviriyoruz
                let elapsedTime = score.value(forKey: "elapsedTime") as? Double ?? 0
                let calculatedScore = Int(10000 / (elapsedTime + 1))
                
                Text("\(calculatedScore) puan")
                    .font(.system(size: 17, weight: .medium))
                
                HStack(spacing: 15) {
                    // HighScore entity'sinde hata ve ipucu sayısı yok, süreyi gösterelim
                    Label(formatTime(elapsedTime), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Tarih
            if let date = score.value(forKey: "date") as? Date {
                Text(formatDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ScoreDetailView: View {
    let score: NSManagedObject
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        let elapsedTime = score.value(forKey: "elapsedTime") as? Double ?? 0
        let calculatedScore = Int(10000 / (elapsedTime + 1))
        let difficulty = score.value(forKey: "difficulty") as? String ?? ""
        let date = score.value(forKey: "date") as? Date
        let playerName = score.value(forKey: "playerName") as? String
        
        // DateFormatter'ı View'da hazırla
        let dateString: String
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .medium
            dateString = formatter.string(from: date)
        } else {
            dateString = ""
        }
        
        return NavigationView {
            List {
                Section(header: Text("Oyun Detayları")) {
                    HStack {
                        Text("Skor")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(calculatedScore) puan")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Tamamlanma Süresi")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(elapsedTime))
                            .fontWeight(.medium)
                    }
                    
                    if !difficulty.isEmpty {
                        HStack {
                            Text("Zorluk Seviyesi")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(difficulty)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if !dateString.isEmpty {
                        HStack {
                            Text("Oyun Tarihi")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(dateString)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let playerName = playerName {
                        HStack {
                            Text("Oyuncu")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(playerName)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Oyun Detayı")
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            })
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