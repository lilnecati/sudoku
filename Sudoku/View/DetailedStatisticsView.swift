import SwiftUI
import CoreData
import Combine
import FirebaseAuth
import FirebaseFirestore

struct DetailedStatisticsView: View {
    // MARK: - Çeviri Desteği
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var localizationManager: LocalizationManager
    @AppStorage("app_language") private var appLanguage: String = "tr"
    
    // Görünümü kapatmak için
    @Environment(\.dismiss) private var dismiss
    
    // Değişiklikleri izlemek için
    @State private var refreshTrigger = UUID()
    @State private var cancellables = [AnyCancellable]()
    
    // Veri değişkenleri
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedDifficulty: SudokuBoard.Difficulty = .easy
    @State private var statistics: StatisticsData = StatisticsData.placeholder
    
    // Grafik verileri
    @State private var completionData: [CompletionDataPoint] = []
    @State private var performanceData: [PerformanceDataPoint] = []
    
    // Sayfa içeriği için yerelleştirilmiş metinler
    @State private var pageTitle: String = ""
    @State private var rangeSelectTitle: String = ""
    @State private var difficultySelectTitle: String = ""
    @State private var summaryTitle: String = ""
    @State private var completionRateTitle: String = ""
    @State private var accuracyTitle: String = ""
    @State private var avgTimeTitle: String = ""
    @State private var trendTitle: String = ""
    @State private var gamesPlayedTitle: String = ""
    @State private var noDataMessage: String = ""
    
    // Zaman aralığı seçenekleri
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "week"
        case month = "month"
        case year = "year"
        case allTime = "all_time"
        
        var id: String { self.rawValue }
        
        @MainActor
        var localizedName: String {
            switch self {
            case .week:
                return LocalizationManager.shared.localizedString(for: "Son Hafta")
            case .month:
                return LocalizationManager.shared.localizedString(for: "Son Ay")
            case .year:
                return LocalizationManager.shared.localizedString(for: "Son Yıl")
            case .allTime:
                return LocalizationManager.shared.localizedString(for: "Tüm Zamanlar")
            }
        }
    }
    
    // Veri yapıları
    struct StatisticsData {
        var totalGames: Int
        var completedGames: Int
        var averageTime: TimeInterval
        var bestTime: TimeInterval
        var averageErrors: Double
        var successRate: Double
        var trendDirection: TrendDirection
        
        enum TrendDirection {
            case up, down, stable
            
            var localizedDescription: String {
                switch self {
                case .up:
                    return "İyileşiyor"
                case .down:
                    return "Geriliyor"
                case .stable:
                    return "Sabit"
                }
            }
        }
        
        static var placeholder: StatisticsData {
            StatisticsData(
                totalGames: 0,
                completedGames: 0,
                averageTime: 0,
                bestTime: 0,
                averageErrors: 0,
                successRate: 0,
                trendDirection: .stable
            )
        }
    }
    
    struct CompletionDataPoint: Identifiable {
        var id = UUID()
        var date: Date
        var completed: Bool
    }
    
    struct PerformanceDataPoint: Identifiable {
        var id = UUID()
        var date: Date
        var time: TimeInterval
        var errors: Int
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Arka plan
                GridBackgroundView()
                    .edgesIgnoringSafeArea(.all)
                
                // Ana içerik
                ScrollView {
                    VStack(spacing: 16) {
                        // Başlık ve Kapat Butonu
                        HStack {
                            Text(pageTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Kapat butonu
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Filtreler - Zaman ve zorluk yan yana olacak
                        HStack(alignment: .top, spacing: 12) {
                            // Zaman aralığı seçici
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizationManager.shared.localizedString(for: "Time Range"))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 0) {
                                    timeRangePicker
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.8) : Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                                )
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Zorluk seviyesi seçici
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizationManager.shared.localizedString(for: "Difficulty Level"))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 0) {
                                    difficultyPicker
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.8) : Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(colorScheme == .dark ? Color(.systemGray5).opacity(0.9) : Color.white.opacity(0.95))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Özet kart
                        statisticsSummaryCard
                        
                        // Tamamlama oranı grafiği
                        completionRateChart
                        
                        // Performans grafiği
                        performanceChart
                        
                        // Tümünü Sil butonu
                        Button(action: {
                            logInfo("SIL BUTONUNA BASILDI")
                            deleteAllCompletedGames()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Text(LocalizationManager.shared.localizedString(for: "Tüm İstatistikleri Sil"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(color: Color.red.opacity(0.5), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(StatScaleButtonStyle()) // Özel buton stilini kullanalım
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.bottom, 30)
                    .id(refreshTrigger) // Dil değiştiğinde içeriği zorla güncelle
                }
            }
            .navigationTitle(pageTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // @MainActor içinde async olmayan kodu çağıralım
            Task { @MainActor in
                // await kullanmadan düz çağrı
                setupLocalization()
            }
            logInfo("DetailedStatisticsView görünümü açıldı")
            // Gerçek veri yükle
            loadData()
            setupLanguageChangeListener()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStatistics"))) { _ in
            logInfo("DetailedStatisticsView: İstatistikler yenileme bildirimi alındı")
            loadData()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            logInfo("Zaman aralığı değişti: \(selectedTimeRange.rawValue)")
            loadData()
        }
        .onChange(of: selectedDifficulty) { _, _ in
            logInfo("Zorluk seviyesi değişti: \(selectedDifficulty.rawValue)")
            loadData()
        }
    }
    
    // MARK: - Bileşenler
    
    // Zaman aralığı seçici
    private var timeRangePicker: some View {
        VStack(spacing: 8) {
            ForEach(TimeRange.allCases) { range in
                let isSelected = selectedTimeRange == range
                let title: String = {
                    switch range {
                    case .week:
                        return LocalizationManager.shared.localizedString(for: "Hafta")
                    case .month:
                        return LocalizationManager.shared.localizedString(for: "Ay")
                    case .year:
                        return LocalizationManager.shared.localizedString(for: "Yıl")
                    case .allTime:
                        return LocalizationManager.shared.localizedString(for: "Tümü")
                    }
                }()
                
                Button {
                    logInfo("Zaman aralığı seçildi: \(range.rawValue)")
                    selectedTimeRange = range
                } label: {
                    HStack(spacing: 8) {
                        // Zaman ikonu
                        Image(systemName: timeRangeIcon(for: range))
                            .font(.system(size: isSelected ? 16 : 14))
                            .foregroundColor(isSelected ? .white : Color.primary.opacity(0.6))
                        
                        Text(title)
                            .font(.system(size: isSelected ? 15 : 14, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : Color.primary.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        ZStack {
                            if isSelected {
                                // Seçili arkaplan
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.blue.opacity(0.4), radius: 3, x: 0, y: 2)
                            } else {
                                // Seçili olmayan durum için görünür arka plan
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.clear : Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .contentShape(Rectangle()) // Tüm alanı tıklanabilir yap
                }
                .buttonStyle(EasyTapButtonStyle()) // Özel butonu stili ile tıklamayı kolaylaştır
            }
        }
        .padding(6)
    }
    
    // Zorluk seviyesi seçici
    private var difficultyPicker: some View {
        VStack(spacing: 8) {
            ForEach(SudokuBoard.Difficulty.allCases) { difficulty in
                let isSelected = selectedDifficulty == difficulty
                let title = difficulty.localizedName
                let difficultyColor = getDifficultyColor(difficulty)
                
                Button {
                    logInfo("Zorluk seçildi: \(difficulty.rawValue)")
                    selectedDifficulty = difficulty
                } label: {
                    HStack(spacing: 8) {
                        // Zorluk ikonu
                        Image(systemName: difficultyIcon(for: difficulty))
                            .font(.system(size: isSelected ? 16 : 14))
                            .foregroundColor(isSelected ? .white : difficultyColor.opacity(0.8))
                        
                        Text(title)
                            .font(.system(size: isSelected ? 15 : 14, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : Color.primary.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        ZStack {
                            if isSelected {
                                // Seçili arkaplan
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [difficultyColor, difficultyColor.opacity(0.7)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: difficultyColor.opacity(0.4), radius: 3, x: 0, y: 2)
                            } else {
                                // Seçili olmayan durum için görünür arka plan
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.clear : Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .contentShape(Rectangle()) // Tüm alanı tıklanabilir yap
                }
                .buttonStyle(EasyTapButtonStyle()) // Özel butonu stili ile tıklamayı kolaylaştır
            }
        }
        .padding(6)
    }
    
    // Zaman aralığı ikonu
    private func timeRangeIcon(for range: TimeRange) -> String {
        switch range {
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar.badge.plus"
        case .year:
            return "calendar"
        case .allTime:
            return "infinity"
        }
    }
    
    // Zorluk seviyesi ikonu
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
    
    // Özet istatistik kartı
    private var statisticsSummaryCard: some View {
        VStack(spacing: 16) {
            // Başlık
            HStack {
                Text(LocalizationManager.shared.localizedString(for: "Summary"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Renk açıklaması (seçilen zorluk seviyesinin rengi)
                HStack(spacing: 6) {
                    Circle()
                        .fill(getDifficultyColor(selectedDifficulty))
                        .frame(width: 10, height: 10)
                    
                    Text(selectedDifficulty.localizedName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(getDifficultyColor(selectedDifficulty).opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(getDifficultyColor(selectedDifficulty).opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
            
            // Bölüm çizgisi - gradient çizgi
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, getDifficultyColor(selectedDifficulty).opacity(0.5), .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal)
            
            // İstatistik değerleri - daha gelişmiş, kartlı tasarım
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Tamamlama oranı
                statCard(
                    title: LocalizationManager.shared.localizedString(for: "Tamamlama"),
                    value: String(format: "%d%%", Int(statistics.successRate * 100)),
                    icon: "checkmark.circle.fill",
                    color: .green,
                    details: "\(statistics.completedGames)/\(statistics.totalGames) " + LocalizationManager.shared.localizedString(for: "oyun")
                )
                
                // Ortalama süre
                statCard(
                    title: LocalizationManager.shared.localizedString(for: "Ort. Süre"),
                    value: formatTime(statistics.averageTime),
                    icon: "stopwatch.fill",
                    color: .blue,
                    details: LocalizationManager.shared.localizedString(for: "Her oyun")
                )
                
                // Doğruluk - hatalar
                statCard(
                    title: LocalizationManager.shared.localizedString(for: "Doğruluk"),
                    value: String(format: "%.1f", statistics.averageErrors),
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    details: LocalizationManager.shared.localizedString(for: "Ort. hata")
                )
                
                // Trend
                statCard(
                    title: LocalizationManager.shared.localizedString(for: "Trend"),
                    value: getTrendValue(),
                    icon: getTrendIcon(),
                    color: getTrendColor(),
                    details: LocalizationManager.shared.localizedString(for: "Son oyunlarda")
                )
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
    
    // Tek istatistik kartı
    private func statCard(title: String, value: String, icon: String, color: Color, details: String) -> some View {
        VStack(spacing: 14) {
            // İkon
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, color.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
                )
            
            VStack(spacing: 4) {
                // Ana değer
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                // Başlık
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                // Detay bilgisi
                Text(details)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Tamamlama oranı grafiği
    private var completionRateChart: some View {
        VStack(spacing: 16) {
            HStack {
                Text(LocalizationManager.shared.localizedString(for: "Tamamlama Oranı"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Etiket
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    
                    Text(LocalizationManager.shared.localizedString(for: "Tamamlanma"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
            
            if completionData.isEmpty {
                // Hiç veri yoksa mesaj göster
                emptyDataView()
            } else {
                // Geliştirilmiş tamamlama grafiği
                VStack(spacing: 8) {
                    // Çubuk grafik
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(completionData) { dataPoint in
                            VStack(spacing: 2) {
                                // Çubuk
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(
                                                colors: dataPoint.completed ? 
                                                    [Color.green, Color.green.opacity(0.7)] : 
                                                    [Color.red.opacity(0.7), Color.red.opacity(0.5)]
                                            ),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: dataPoint.completed ? 80 : 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                dataPoint.completed ? Color.green.opacity(0.7) : Color.red.opacity(0.7),
                                                lineWidth: 1
                                            )
                                    )
                                
                                // Tarih etiketi
                                Text(formatDateForDisplay(dataPoint.date))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(-45))
                                    .frame(width: 25)
                            }
                        }
                    }
                    .frame(height: 130)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Açıklama
                    HStack(spacing: 12) {
                        // Tamamlanan
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            
                            Text(LocalizationManager.shared.localizedString(for: "Completed"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Tamamlanmayan
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 12, height: 12)
                            
                            Text(LocalizationManager.shared.localizedString(for: "Not Completed"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
    
    // Performans grafiği
    private var performanceChart: some View {
        VStack(spacing: 16) {
            HStack {
                Text(LocalizationManager.shared.localizedString(for: "Performans Trendi"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // En iyi süre etiketi
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    
                    Text(formatTime(statistics.bestTime))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
            
            if performanceData.isEmpty {
                // Hiç veri yoksa mesaj göster
                emptyDataView()
            } else {
                // Geliştirilmiş performans grafiği
                VStack(spacing: 8) {
                    // Y-ekseni referans çizgileri
                    ZStack(alignment: .leading) {
                        // Çizgiler
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<5) { index in
                                HStack {
                                    // Y-ekseni etiketi
                                    Text("\((4-index) * 5)dk")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                        .frame(width: 25, alignment: .leading)
                                    
                                    // Yatay referans çizgisi
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                }
                            }
                        }
                        
                        // Çubuk grafik
                        HStack(alignment: .bottom, spacing: 8) {
                            // Eksenlerin genişliği için boşluk
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 25)
                            
                            ForEach(performanceData) { dataPoint in
                                VStack(spacing: 4) {
                                    // Çubuk
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(
                                                    colors: [Color.blue, Color.purple]
                                                ),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: CGFloat(min(dataPoint.time / 60.0, 20.0) * 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.blue.opacity(0.7), lineWidth: 1)
                                        )
                                    
                                    // Süre etiketi
                                    Text(formatTimeShort(dataPoint.time))
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)
                                    
                                    // Tarih etiketi
                                    Text(formatDateForDisplay(dataPoint.date))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .rotationEffect(.degrees(-45))
                                        .frame(width: 25)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
    
    // Veri yok görünümü
    private func emptyDataView() -> some View {
        VStack(spacing: 16) {
            // Boş veri ikonu
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(Color.gray.opacity(0.5))
                .padding(.bottom, 8)
            
            // Mesaj
            Text(noDataMessage)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Alt bilgi
            Text(LocalizationManager.shared.localizedString(for: "Oyun tamamladıkça burada istatistikleriniz görünecek"))
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5).opacity(0.5) : Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 30)
    }
    
    // MARK: - Helper Fonksiyonlar
    
    // Dil değişimi için kurulum
    @MainActor
    private func setupLocalization() {
        // Normal çağrı, await kullanma
        updateLocalizedTexts()
    }
    
    // Dil değişikliği dinleyici
    private func setupLanguageChangeListener() {
        // NotificationCenter üzerinden dil değişikliklerini izleyen yeni yaklaşım
        let publisher = NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))
        
        // Aboneliği bir değişkene kaydet
        let subscription = publisher.sink { _ in
            Task { @MainActor in
                self.updateLocalizedTexts()
                self.refreshTrigger = UUID()
            }
        }
        
        // Sabit değişken üzerinden aboneliği ekle
        cancellables = [subscription]
    }
    
    // Yerelleştirilmiş metinleri güncelle
    @MainActor
    private func updateLocalizedTexts() {
        pageTitle = LocalizationManager.shared.localizedString(for: "Detaylı İstatistikler")
        rangeSelectTitle = LocalizationManager.shared.localizedString(for: "Zaman Aralığı")
        difficultySelectTitle = LocalizationManager.shared.localizedString(for: "Zorluk Seviyesi")
        summaryTitle = LocalizationManager.shared.localizedString(for: "Özet")
        completionRateTitle = LocalizationManager.shared.localizedString(for: "Tamamlama Oranı")
        accuracyTitle = LocalizationManager.shared.localizedString(for: "Doğruluk")
        avgTimeTitle = LocalizationManager.shared.localizedString(for: "Ort. Süre")
        trendTitle = LocalizationManager.shared.localizedString(for: "Trend")
        gamesPlayedTitle = LocalizationManager.shared.localizedString(for: "Oynanan")
        noDataMessage = LocalizationManager.shared.localizedString(for: "Bu zaman aralığında veri bulunmuyor")
    }
    
    // Zorluk seviyesi rengi
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
    
    // Trend yönüne göre ikon
    private func getTrendIcon() -> String {
        switch statistics.trendDirection {
        case .up:
            return "arrow.up.circle.fill"
        case .down:
            return "arrow.down.circle.fill"
        case .stable:
            return "arrow.right.circle.fill"
        }
    }
    
    // Trend yönüne göre renk
    private func getTrendColor() -> Color {
        switch statistics.trendDirection {
        case .up:
            return .green
        case .down:
            return .red
        case .stable:
            return .gray
        }
    }
    
    // Trend değeri - @MainActor ile işaretleyerek ana aktör üzerinde çalışacak şekilde tanımla
    @MainActor
    private func getTrendValue() -> String {
        switch statistics.trendDirection {
        case .up:
            return LocalizationManager.shared.localizedString(for: "İyileşiyor")
        case .down:
            return LocalizationManager.shared.localizedString(for: "Geriliyor")
        case .stable:
            return LocalizationManager.shared.localizedString(for: "Sabit")
        }
    }
    
    // Zaman formatı
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes < 1 {
            return "\(seconds) sn"
        } else if seconds == 0 {
            return "\(minutes) dk"
        } else {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }
    
    // Kısa zaman formatı (grafikler için)
    private func formatTimeShort(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        if minutes < 1 {
            return "\(Int(time))s"
        } else {
            return "\(minutes)dk"
        }
    }
    
    // Zaman aralığı formatı
    private func formatDateForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week, .month:
            formatter.dateFormat = "d MMM"
        case .year, .allTime:
            formatter.dateFormat = "MMM yy"
        }
        
        // Dil uyarlaması
        formatter.locale = Locale(identifier: appLanguage)
        
        return formatter.string(from: date)
    }
    
    // Gerçek veriler yerine örnek verileri kullanalım
    private func loadData() {
        // İstatistik modelini sıfırla
        statistics = StatisticsData.placeholder
        completionData = []
        performanceData = []
        
        // Refresh ettiğimizi bildir
        logInfo("İSTATİSTİK YÜKLEME BAŞLADI")
        logInfo("Zorluk Seviyesi: \(selectedDifficulty.rawValue), Zaman Aralığı: \(selectedTimeRange.rawValue)")
        
        // Kullanıcı giriş yapmış mı kontrol et
        guard let userID = Auth.auth().currentUser?.uid else {
            logWarning("İstatistikler yüklenemedi: Kullanıcı giriş yapmamış")
            
            // Kullanıcı giriş yapmamışsa varsayılan dummy verileri kullan
            logInfo("Demo verileri yükleniyor (kullanıcı girişi yok)")
            loadDummyData()
            return
        }
        
        logInfo("Kullanıcı ID: \(userID) - Gerçek veriler yükleniyor")
        
        // Firestore'dan tamamlanmış oyunları çek
        let db = Firestore.firestore()
        
        // savedGames koleksiyonu yerine highScores koleksiyonunu kullan
        let query = db.collection("highScores")
            .whereField("userID", isEqualTo: userID)
            
        // Zaman aralığına göre filtreleme
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var fromDate: Date
        
        switch selectedTimeRange {
        case .week:
            fromDate = calendar.date(byAdding: .day, value: -7, to: today)!
        case .month:
            fromDate = calendar.date(byAdding: .month, value: -1, to: today)!
        case .year:
            fromDate = calendar.date(byAdding: .year, value: -1, to: today)!
        case .allTime:
            fromDate = calendar.date(byAdding: .year, value: -10, to: today)! // Pratik olarak "tüm zamanlar"
        }
        
        logInfo("Tarih filtresi: \(fromDate) - \(today)")
        
        // Sorgu çok basitleştirildi, sadece userID kullanılıyor. Diğer filtreleri kod içinde yapacağız.
        logInfo("Firestore sorgusu yapılıyor: highScores koleksiyonu")
        
        // Verileri çek
        query.getDocuments { snapshot, error in
            if let error = error {
                logWarning("Firestore'dan veriler alınamadı: \(error.localizedDescription)")
                logInfo("Firebase hatası nedeniyle demo veriler yükleniyor")
                self.loadDummyData()
                return
            }
            
            logSuccess("Firestore sorgusu tamamlandı")
            
            guard let documents = snapshot?.documents else {
                logWarning("Dökümanlar bulunamadı veya boş")
                logInfo("Döküman bulunamadığı için demo veriler yükleniyor")
                self.loadDummyData()
                return
            }
            
            // Tüm filtreleri kod içinde uygula
            let filteredDocuments = documents.filter { document in
                let data = document.data()
                
                // İlk olarak tamamlanma kontrolü - highScores'ta kayıt varsa tamamlanmış demektir
                // isCompleted kontrolünü kaldırdık çünkü highScores sadece tamamlanmış oyunları içerir
                
                // difficulty kontrolü
                guard (data["difficulty"] as? String) == selectedDifficulty.rawValue else {
                    return false
                }
                
                // Tarih kontrolü - date veya timestamp kullan
                if let dateTimestamp = data["date"] as? Timestamp {
                    let creationDate = dateTimestamp.dateValue()
                    return creationDate > fromDate
                } else if let timestamp = data["timestamp"] as? Timestamp {
                    let creationDate = timestamp.dateValue()
                    return creationDate > fromDate
                }
                
                return false
            }
            
            if filteredDocuments.isEmpty {
                logInfo("Bu filtreye uygun tamamlanmış oyun bulunamadı")
                // Veri bulunamadıysa boş bırak
                DispatchQueue.main.async {
                    logInfo("Veri olmadığı için boş istatistikler gösteriliyor")
                    self.statistics = StatisticsData.placeholder
                    self.completionData = []
                    self.performanceData = []
                }
                return
            }
            
            logInfo("\(filteredDocuments.count) tamamlanmış oyun bulundu")
            
            // İstatistik verileri için geçici diziler
            var tempCompletionData: [CompletionDataPoint] = []
            var tempPerformanceData: [PerformanceDataPoint] = []
            
            // Toplam süre ve hata sayıları
            var totalTime: TimeInterval = 0
            var totalErrors = 0
            var bestTime: TimeInterval = Double.infinity
            
            // Her oyunu işle
            for (index, document) in filteredDocuments.enumerated() {
                let data = document.data()
                
                // Doküman ID
                let docID = document.documentID
                logDebug("Oyun \(index+1)/\(filteredDocuments.count) işleniyor - ID: \(docID)")
                
                // Timestamp'i tarih olarak al
                if let timestamp = data["date"] as? Timestamp {
                    let date = timestamp.dateValue()
                    logDebug("   Tarih: \(date)")
                } else if let timestamp = data["timestamp"] as? Timestamp {
                    let date = timestamp.dateValue()
                    logDebug("   Tarih: \(date)")
                } else {
                    logWarning("   Timestamp bulunamadı")
                }
                
                // Süre
                if let elapsedTime = data["elapsedTime"] as? TimeInterval {
                    logDebug("   Süre: \(elapsedTime) saniye")
                } else {
                    logWarning("   elapsedTime alanı bulunamadı")
                }
                
                // Hatalar
                if let errorCount = data["errorCount"] as? Int {
                    logDebug("   Hata sayısı: \(errorCount)")
                } else {
                    logWarning("   errorCount alanı bulunamadı")
                }
                
                // Verileri al - tarih bilgisini date veya timestamp alanından al
                let date: Date
                if let dateTimestamp = data["date"] as? Timestamp {
                    date = dateTimestamp.dateValue()
                } else if let timestamp = data["timestamp"] as? Timestamp {
                    date = timestamp.dateValue()
                } else {
                    date = Date() // Varsayılan değer
                }
                
                let elapsedTime = data["elapsedTime"] as? TimeInterval ?? 0
                let errorCount = data["errorCount"] as? Int ?? 0
                
                // Tamamlama verisi ekle
                tempCompletionData.append(CompletionDataPoint(
                    date: date,
                    completed: true
                ))
                
                // Performans verisi ekle
                tempPerformanceData.append(PerformanceDataPoint(
                    date: date,
                    time: elapsedTime,
                    errors: errorCount
                ))
                
                // Toplam değerleri güncelle
                totalTime += elapsedTime
                totalErrors += errorCount
                
                // En iyi süreyi güncelle
                if elapsedTime > 0 && elapsedTime < bestTime {
                    bestTime = elapsedTime
                }
            }
            
            // Eğer hiç en iyi süre bulunamadıysa sıfırla
            if bestTime == Double.infinity {
                bestTime = 0
            }
            
            logSuccess("Veri işleme tamamlandı")
            logInfo("Toplam süre: \(totalTime), Toplam hata: \(totalErrors)")
            logInfo("En iyi süre: \(bestTime)")
            
            // Verileri zaman sırasına göre sırala
            tempCompletionData.sort { $0.date < $1.date }
            tempPerformanceData.sort { $0.date < $1.date }
            
            // Trend hesaplama için verileri ikiye böl
            let performanceCount = tempPerformanceData.count
            let firstHalf = Array(tempPerformanceData.prefix(max(1, performanceCount/2)))
            let secondHalf = Array(tempPerformanceData.suffix(max(1, performanceCount/2)))
            
            let firstHalfAvg = firstHalf.map { $0.time }.reduce(0, +) / Double(max(1, firstHalf.count))
            let secondHalfAvg = secondHalf.map { $0.time }.reduce(0, +) / Double(max(1, secondHalf.count))
            
            let trendDirection: StatisticsData.TrendDirection
            let trendDiff = secondHalfAvg - firstHalfAvg
            if abs(trendDiff) < 30 { // 30 saniyelik fark anlamsız kabul edilir
                trendDirection = .stable
            } else if trendDiff < 0 { // Daha hızlı çözdüyse (süre azaldıysa) iyileşme var
                trendDirection = .up
            } else { // Daha yavaş çözdüyse kötüleşme var
                trendDirection = .down
            }
            
            logInfo("İstatistikler hesaplandı - Trend: \(trendDirection)")
            
            // Ana thread'de UI güncellemelerini yap
            DispatchQueue.main.async {
                logInfo("UI güncellemesi başladı")
                
                // Sonuçları uygula
                self.completionData = tempCompletionData
                self.performanceData = tempPerformanceData
                
                // İstatistik özetini oluştur
                self.statistics = StatisticsData(
                    totalGames: filteredDocuments.count,
                    completedGames: filteredDocuments.count, // Tüm oyunlar tamamlanmış (filter ile çektik)
                    averageTime: totalTime / Double(max(1, filteredDocuments.count)),
                    bestTime: bestTime,
                    averageErrors: Double(totalErrors) / Double(max(1, filteredDocuments.count)),
                    successRate: 1.0, // Tamamlanma oranı %100 (filter ile tamamlanmış oyunları çektik)
                    trendDirection: trendDirection
                )
                
                logSuccess("UI güncellendi: \(filteredDocuments.count) oyun gösteriliyor")
                logSuccess("İSTATİSTİK YÜKLEME TAMAMLANDI")
            }
        }
    }
    
    // Örnek veriler oluştur (gerçek veri yoksa)
    private func loadDummyData() {
        logInfo("İstatistik verisi yok! Grafikleri boş gösteriyorum")
        
        // Verileri sıfırla
        statistics = StatisticsData.placeholder
        completionData = []
        performanceData = []
        
        logSuccess("İstatistikler sıfırlandı - boş gösterilecek")
    }
    
    // Tüm tamamlanmış oyunları silme fonksiyonu
    private func deleteAllCompletedGames() {
        logInfo("deleteAllCompletedGames fonksiyonu çağrıldı")
        
        // Kullanıcı giriş yapmış mı kontrol et
        if Auth.auth().currentUser == nil {
            logWarning("Kullanıcı giriş yapmamış - uyarı gösterilecek")
            // Kullanıcı giriş yapmamışsa uyarı göster
            let alertTitle = LocalizationManager.shared.localizedString(for: "Giriş Gerekli")
            let alertMessage = LocalizationManager.shared.localizedString(for: "Bu özelliği kullanmak için lütfen oturum açın.")
            
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "Tamam"), style: .default))
            
            // Uyarıyı göster
            getTopViewController()?.present(alert, animated: true)
            return
        }
        
        logInfo("Kullanıcı giriş yapmış: \(Auth.auth().currentUser?.uid ?? "bilinmiyor")")
        
        // Onay isteyin
        let confirmAlert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "Dikkat"),
            message: LocalizationManager.shared.localizedString(for: "Tüm istatistik verileri, yüksek skorlar ve tamamlanmış oyunlar silinecek. Bu işlem geri alınamaz."),
            preferredStyle: .alert
        )
        
        confirmAlert.addAction(UIAlertAction(
            title: LocalizationManager.shared.localizedString(for: "İptal"),
            style: .cancel
        ) { _ in 
            logInfo("Kullanıcı silme işlemini iptal etti")
        })
        
        confirmAlert.addAction(UIAlertAction(
            title: LocalizationManager.shared.localizedString(for: "Sil"),
            style: .destructive
        ) { _ in
            logSuccess("Kullanıcı silme işlemini onayladı")
            // Yükleme göstergesi
            let loadingAlert = UIAlertController(
                title: LocalizationManager.shared.localizedString(for: "İşlem Sürüyor"),
                message: LocalizationManager.shared.localizedString(for: "İstatistikler, skorlar ve tamamlanmış oyunlar siliniyor..."),
                preferredStyle: .alert
            )
            
            // Yükleme göstergesini göster
            self.getTopViewController()?.present(loadingAlert, animated: true)
            
            // Core Data'dan skorları sil
            logInfo("deleteAllHighScores fonksiyonu çağrılıyor")
            self.deleteAllHighScores { success in
                logSuccess("deleteAllHighScores tamamlandı - başarı: \(success)")
                
                // Tamamlanmış oyunları sil
                logInfo("deleteAllCompletedGames fonksiyonu çağrılıyor")
                PersistenceController.shared.deleteAllCompletedGames()
                
                // Veriyi hemen yenile
                logInfo("Veriler silindikten sonra yenileniyor")
                DispatchQueue.main.async {
                    // Sayfayı yenile
                    self.refreshTrigger = UUID() // View ID'sini değiştirerek yeniden render et
                    self.loadData() // Verileri yeniden yükle
                    
                    // Bildirim gönder - diğer görünümlerin de yenilenmesi için
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshSavedGames"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshStatistics"), object: nil)
                }
                
                // Yükleme göstergesini kaldır ve başarı mesajı göster
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Yükleme göstergesini kapat
                    loadingAlert.dismiss(animated: true) {
                        // Başarı mesajı göster
                        let successAlert = UIAlertController(
                            title: LocalizationManager.shared.localizedString(for: "İşlem Tamamlandı"),
                            message: success ? 
                                LocalizationManager.shared.localizedString(for: "Tüm istatistikler ve tamamlanmış oyunlar başarıyla silindi.") :
                                LocalizationManager.shared.localizedString(for: "Bazı veriler silinemedi."),
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(
                            title: LocalizationManager.shared.localizedString(for: "Tamam"),
                            style: .default
                        ))
                        
                        // Başarı mesajını göster
                        self.getTopViewController()?.present(successAlert, animated: true)
                    }
                }
            }
        })
        
        // Onay dialogunu göster
        getTopViewController()?.present(confirmAlert, animated: true)
    }
    
    // En üstteki view controller'ı bulma yardımcı fonksiyonu
    private func getTopViewController() -> UIViewController? {
        // UIWindow dizisini alıyoruz
        let windows = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .filter { $0.isKeyWindow }
        
        // Key window'u bulduk
        guard let keyWindow = windows.first else {
            logError("Key window bulunamadı!")
            return nil
        }
        
        // Root controller'dan başlayarak en üstteki controller'ı bul
        var topController = keyWindow.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        logSuccess("Top view controller bulundu: \(String(describing: type(of: topController)))")
        return topController
    }
    
    // Tüm yüksek skorları sil
    private func deleteAllHighScores(completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            logWarning("Kullanıcı giriş yapmamış!")
            completion(false)
            return
        }
        
        let context = PersistenceController.shared.container.viewContext
        
        // Firebase'den yüksek skorları sil
        Firestore.firestore().collection("highScores")
            .whereField("userID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                if let error = error {
                    logError("Firestore skor sorgulama hatası: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    logInfo("Firestore'da yüksek skor bulunamadı")
                    // Firebase'de veri yoksa Core Data'dan silmeye devam et
                    self.deleteHighScoresFromCoreData(context: context, completion: completion)
                    return
                }
                
                logInfo("Firebase'den silinecek skor sayısı: \(documents.count)")
                
                // Batch işlemi oluştur
                let batch = Firestore.firestore().batch()
                
                for document in documents {
                    logInfo("Firebase'den siliniyor: \(document.documentID)")
                    let scoreRef = Firestore.firestore().collection("highScores").document(document.documentID)
                    batch.deleteDocument(scoreRef)
                }
                
                // Batch işlemini uygula
                batch.commit { error in
                    if let error = error {
                        logError("Firebase skor silme hatası: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        logSuccess("Firebase'den \(documents.count) skor silindi")
                        // Firebase'den sildikten sonra Core Data'dan da sil
                        self.deleteHighScoresFromCoreData(context: context, completion: completion)
                    }
                }
            }
    }
    
    // Core Data'dan yüksek skorları sil
    private func deleteHighScoresFromCoreData(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        let fetchRequest: NSFetchRequest<HighScore> = HighScore.fetchRequest()
        
        do {
            let highScores = try context.fetch(fetchRequest)
            
            if highScores.isEmpty {
                logInfo("Core Data'da silinecek yüksek skor bulunamadı")
                completion(true)
                return
            }
            
            logInfo("Core Data'dan silinecek skor sayısı: \(highScores.count)")
            
            for score in highScores {
                context.delete(score)
                logInfo("Core Data'dan silindi: \(score.id?.uuidString ?? "bilinmiyor")")
            }
            
            try context.save()
            logSuccess("Tüm yüksek skorlar Core Data'dan silindi")
            completion(true)
        } catch {
            logError("Core Data skor silme hatası: \(error.localizedDescription)")
            completion(false)
        }
    }
}

// MARK: - Özel Buton Stili
struct StatScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Özel buton stili - kolay basılma için
struct EasyTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Önizleme Sağlayıcı
struct DetailedStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedStatisticsView()
            .environmentObject(LocalizationManager.shared)
    }
} 