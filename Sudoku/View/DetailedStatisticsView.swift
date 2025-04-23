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
                        
                        // Filtreler
                        HStack(spacing: 16) {
                            // Zaman aralığı seçici
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizationManager.shared.localizedString(for: "Time Range"))
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                
                                timeRangePicker
                            }
                            
                            // Zorluk seviyesi seçici
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizationManager.shared.localizedString(for: "Difficulty Level"))
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                
                                difficultyPicker
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
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
                            print("📌 SIL BUTONUNA BASILDI")
                            deleteAllCompletedGames()
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text(LocalizationManager.shared.localizedString(for: "Tüm İstatistikleri Sil"))
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red)
                            )
                        }
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
            print("📱 DetailedStatisticsView görünümü açıldı")
            // Gerçek veri yükle
            loadData()
            setupLanguageChangeListener()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStatistics"))) { _ in
            print("🔄 DetailedStatisticsView: İstatistikler yenileme bildirimi alındı")
            loadData()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            print("🔄 Zaman aralığı değişti: \(selectedTimeRange.rawValue)")
            loadData()
        }
        .onChange(of: selectedDifficulty) { _, _ in
            print("🔄 Zorluk seviyesi değişti: \(selectedDifficulty.rawValue)")
            loadData()
        }
    }
    
    // MARK: - Bileşenler
    
    // Zaman aralığı seçici
    private var timeRangePicker: some View {
        Picker("", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases) { range in
                Group {
                    switch range {
                    case .week:
                        Text(LocalizationManager.shared.localizedString(for: "Son Hafta")).tag(range)
                    case .month:
                        Text(LocalizationManager.shared.localizedString(for: "Son Ay")).tag(range)
                    case .year:
                        Text(LocalizationManager.shared.localizedString(for: "Son Yıl")).tag(range)
                    case .allTime:
                        Text(LocalizationManager.shared.localizedString(for: "Tüm Zamanlar")).tag(range)
                    }
                }
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    // Zorluk seviyesi seçici
    private var difficultyPicker: some View {
        Picker("", selection: $selectedDifficulty) {
            ForEach(SudokuBoard.Difficulty.allCases) { difficulty in
                Text(difficulty.localizedName).tag(difficulty)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    // Özet istatistik kartı
    private var statisticsSummaryCard: some View {
        VStack(spacing: 16) {
            // Başlık
            HStack {
                Text(LocalizationManager.shared.localizedString(for: "Summary"))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Renk açıklaması (seçilen zorluk seviyesinin rengi)
                Circle()
                    .fill(getDifficultyColor(selectedDifficulty))
                    .frame(width: 12, height: 12)
                
                Text(selectedDifficulty.localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Bölüm çizgisi
            Divider()
                .padding(.horizontal)
            
            // İstatistik değerleri - 3 satır, 2 sütun grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                statItem(title: gamesPlayedTitle, value: "\(statistics.totalGames)", icon: "gamecontroller.fill", color: .blue)
                
                statItem(
                    title: completionRateTitle,
                    value: "\(Int(statistics.successRate * 100))%",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                statItem(
                    title: accuracyTitle,
                    value: "\(Int((1 - min(1, statistics.averageErrors / 3)) * 100))%",
                    icon: "target",
                    color: .orange
                )
                
                statItem(
                    title: avgTimeTitle,
                    value: formatTime(statistics.averageTime),
                    icon: "clock.fill",
                    color: .purple
                )
                
                statItem(
                    title: LocalizationManager.shared.localizedString(for: "Trend"),
                    value: getTrendValue(),
                    icon: getTrendIcon(), 
                    color: getTrendColor()
                )
                
                statItem(
                    title: LocalizationManager.shared.localizedString(for: "Fastest"),
                    value: formatTime(statistics.bestTime),
                    icon: "bolt.fill",
                    color: .yellow
                )
            }
            .padding()
            
            if statistics.totalGames == 0 {
                // Hiç veri yoksa mesaj göster
                Text(noDataMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
    
    // Tek istatistik öğesi
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            // İkon
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Tamamlama oranı grafiği
    private var completionRateChart: some View {
        VStack(spacing: 16) {
            HStack {
                Text(LocalizationManager.shared.localizedString(for: "Completion Rate"))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Tamamlama oranı
                HStack(spacing: 4) {
                    Text(String(format: "%d%%", Int(statistics.successRate * 100)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.green)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
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
                Text(noDataMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 30)
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
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // En iyi süre
                HStack(spacing: 4) {
                    Text(formatTime(statistics.bestTime))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.purple)
                    
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 14))
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
                Text(noDataMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 30)
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
        print("📊 İSTATİSTİK YÜKLEME BAŞLADI 📊")
        print("📝 Zorluk Seviyesi: \(selectedDifficulty.rawValue), Zaman Aralığı: \(selectedTimeRange.rawValue)")
        
        // Kullanıcı giriş yapmış mı kontrol et
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ İstatistikler yüklenemedi: Kullanıcı giriş yapmamış")
            
            // Kullanıcı giriş yapmamışsa varsayılan dummy verileri kullan
            print("🔄 Demo verileri yükleniyor (kullanıcı girişi yok)")
            loadDummyData()
            return
        }
        
        print("👤 Kullanıcı ID: \(userID) - Gerçek veriler yükleniyor")
        
        // Firestore'dan tamamlanmış oyunları çek
        let db = Firestore.firestore()
        var query = db.collection("savedGames")
            .whereField("userID", isEqualTo: userID)
            .whereField("isCompleted", isEqualTo: true)
            .whereField("difficulty", isEqualTo: selectedDifficulty.rawValue)
            
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
        
        print("📅 Tarih filtresi: \(fromDate) - \(today)")
        
        // Tarih filtresini ekle
        query = query.whereField("timestamp", isGreaterThan: fromDate)
        
        // Sorgulama yapılıyor bilgisi
        print("🔍 Firestore sorgusu yapılıyor: savedGames koleksiyonu")
        
        // Verileri çek
        query.getDocuments { snapshot, error in
            if let error = error {
                print("⚠️ Firestore'dan veriler alınamadı: \(error.localizedDescription)")
                print("🔄 Firebase hatası nedeniyle demo veriler yükleniyor")
                self.loadDummyData()
                return
            }
            
            print("✅ Firestore sorgusu tamamlandı")
            
            guard let documents = snapshot?.documents else {
                print("⚠️ Dökümanlar bulunamadı veya boş")
                print("🔄 Döküman bulunamadığı için demo veriler yükleniyor")
                self.loadDummyData()
                return
            }
            
            if documents.isEmpty {
                print("ℹ️ Bu filtreye uygun tamamlanmış oyun bulunamadı")
                // Veri bulunamadıysa boş bırak
                DispatchQueue.main.async {
                    print("📊 Veri olmadığı için boş istatistikler gösteriliyor")
                    self.statistics = StatisticsData.placeholder
                    self.completionData = []
                    self.performanceData = []
                }
                return
            }
            
            print("📊 \(documents.count) tamamlanmış oyun bulundu")
            
            // İstatistik verileri için geçici diziler
            var tempCompletionData: [CompletionDataPoint] = []
            var tempPerformanceData: [PerformanceDataPoint] = []
            
            // Toplam süre ve hata sayıları
            var totalTime: TimeInterval = 0
            var totalErrors = 0
            var bestTime: TimeInterval = Double.infinity
            
            // Her oyunu işle
            for (index, document) in documents.enumerated() {
                let data = document.data()
                
                // Doküman ID
                let docID = document.documentID
                print("📄 Oyun \(index+1)/\(documents.count) işleniyor - ID: \(docID)")
                
                // Timestamp'i tarih olarak al
                if let timestamp = data["timestamp"] as? Timestamp {
                    let date = timestamp.dateValue()
                    print("   📅 Tarih: \(date)")
                } else {
                    print("   ⚠️ Timestamp bulunamadı")
                }
                
                // Oyun tamamlanmış mı?
                if let isCompleted = data["isCompleted"] as? Bool {
                    print("   ✓ Tamamlanma: \(isCompleted ? "Evet" : "Hayır")")
                } else {
                    print("   ⚠️ isCompleted alanı bulunamadı")
                }
                
                // Süre
                if let elapsedTime = data["elapsedTime"] as? TimeInterval {
                    print("   ⏱️ Süre: \(elapsedTime) saniye")
                } else {
                    print("   ⚠️ elapsedTime alanı bulunamadı")
                }
                
                // Hatalar
                if let errorCount = data["errorCount"] as? Int {
                    print("   ❌ Hata sayısı: \(errorCount)")
                } else {
                    print("   ⚠️ errorCount alanı bulunamadı")
                }
                
                // Verileri al
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let isCompleted = data["isCompleted"] as? Bool ?? false
                let elapsedTime = data["elapsedTime"] as? TimeInterval ?? 0
                let errorCount = data["errorCount"] as? Int ?? 0
                
                // Tamamlama verisi ekle
                tempCompletionData.append(CompletionDataPoint(
                    date: timestamp,
                    completed: isCompleted
                ))
                
                // Performans verisi ekle
                tempPerformanceData.append(PerformanceDataPoint(
                    date: timestamp,
                    time: elapsedTime,
                    errors: errorCount
                ))
                
                // Toplam değerleri güncelle
                totalTime += elapsedTime
                totalErrors += errorCount
                
                // En iyi süreyi güncelle
                if isCompleted && elapsedTime > 0 && elapsedTime < bestTime {
                    bestTime = elapsedTime
                }
            }
            
            // Eğer hiç en iyi süre bulunamadıysa sıfırla
            if bestTime == Double.infinity {
                bestTime = 0
            }
            
            print("✅ Veri işleme tamamlandı")
            print("📈 Toplam süre: \(totalTime), Toplam hata: \(totalErrors)")
            print("🏆 En iyi süre: \(bestTime)")
            
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
            
            print("📊 İstatistikler hesaplandı - Trend: \(trendDirection)")
            
            // Ana thread'de UI güncellemelerini yap
            DispatchQueue.main.async {
                print("🔄 UI güncellemesi başladı")
                
                // Sonuçları uygula
                self.completionData = tempCompletionData
                self.performanceData = tempPerformanceData
                
                // İstatistik özetini oluştur
                self.statistics = StatisticsData(
                    totalGames: documents.count,
                    completedGames: documents.count, // Tüm oyunlar tamamlanmış (filter ile çektik)
                    averageTime: totalTime / Double(max(1, documents.count)),
                    bestTime: bestTime,
                    averageErrors: Double(totalErrors) / Double(max(1, documents.count)),
                    successRate: 1.0, // Tamamlanma oranı %100 (filter ile tamamlanmış oyunları çektik)
                    trendDirection: trendDirection
                )
                
                print("✅ UI güncellendi: \(documents.count) oyun gösteriliyor")
                print("📊 İSTATİSTİK YÜKLEME TAMAMLANDI 📊")
            }
        }
    }
    
    // Örnek veriler oluştur (gerçek veri yoksa)
    private func loadDummyData() {
        print("ℹ️ İstatistik verisi yok! Grafikleri boş gösteriyorum")
        
        // Verileri sıfırla
        statistics = StatisticsData.placeholder
        completionData = []
        performanceData = []
        
        print("✅ İstatistikler sıfırlandı - boş gösterilecek")
    }
    
    // Tüm tamamlanmış oyunları silme fonksiyonu
    private func deleteAllCompletedGames() {
        print("🔍 deleteAllCompletedGames fonksiyonu çağrıldı")
        
        // Kullanıcı giriş yapmış mı kontrol et
        if Auth.auth().currentUser == nil {
            print("⚠️ Kullanıcı giriş yapmamış - uyarı gösterilecek")
            // Kullanıcı giriş yapmamışsa uyarı göster
            let alertTitle = LocalizationManager.shared.localizedString(for: "Giriş Gerekli")
            let alertMessage = LocalizationManager.shared.localizedString(for: "Bu özelliği kullanmak için lütfen oturum açın.")
            
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "Tamam"), style: .default))
            
            // Uyarıyı göster
            getTopViewController()?.present(alert, animated: true)
            return
        }
        
        print("👤 Kullanıcı giriş yapmış: \(Auth.auth().currentUser?.uid ?? "bilinmiyor")")
        
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
            print("❌ Kullanıcı silme işlemini iptal etti")
        })
        
        confirmAlert.addAction(UIAlertAction(
            title: LocalizationManager.shared.localizedString(for: "Sil"),
            style: .destructive
        ) { _ in
            print("✅ Kullanıcı silme işlemini onayladı")
            // Yükleme göstergesi
            let loadingAlert = UIAlertController(
                title: LocalizationManager.shared.localizedString(for: "İşlem Sürüyor"),
                message: LocalizationManager.shared.localizedString(for: "İstatistikler, skorlar ve tamamlanmış oyunlar siliniyor..."),
                preferredStyle: .alert
            )
            
            // Yükleme göstergesini göster
            self.getTopViewController()?.present(loadingAlert, animated: true)
            
            // Core Data'dan skorları sil
            print("🔄 deleteAllHighScores fonksiyonu çağrılıyor")
            self.deleteAllHighScores { success in
                print("✅ deleteAllHighScores tamamlandı - başarı: \(success)")
                
                // Tamamlanmış oyunları sil
                print("🔄 deleteAllCompletedGames fonksiyonu çağrılıyor")
                PersistenceController.shared.deleteAllCompletedGames()
                
                // Veriyi hemen yenile
                print("🔄 Veriler silindikten sonra yenileniyor")
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
            print("❌ Key window bulunamadı!")
            return nil
        }
        
        // Root controller'dan başlayarak en üstteki controller'ı bul
        var topController = keyWindow.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        print("✅ Top view controller bulundu: \(String(describing: type(of: topController)))")
        return topController
    }
    
    // Tüm yüksek skorları sil
    private func deleteAllHighScores(completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Kullanıcı giriş yapmamış!")
            completion(false)
            return
        }
        
        let context = PersistenceController.shared.container.viewContext
        
        // Firebase'den yüksek skorları sil
        Firestore.firestore().collection("highScores")
            .whereField("userID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firestore skor sorgulama hatası: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ Firestore'da yüksek skor bulunamadı")
                    // Firebase'de veri yoksa Core Data'dan silmeye devam et
                    self.deleteHighScoresFromCoreData(context: context, completion: completion)
                    return
                }
                
                print("📊 Firebase'den silinecek skor sayısı: \(documents.count)")
                
                // Batch işlemi oluştur
                let batch = Firestore.firestore().batch()
                
                for document in documents {
                    print("🗑️ Firebase'den siliniyor: \(document.documentID)")
                    let scoreRef = Firestore.firestore().collection("highScores").document(document.documentID)
                    batch.deleteDocument(scoreRef)
                }
                
                // Batch işlemini uygula
                batch.commit { error in
                    if let error = error {
                        print("❌ Firebase skor silme hatası: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Firebase'den \(documents.count) skor silindi")
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
                print("ℹ️ Core Data'da silinecek yüksek skor bulunamadı")
                completion(true)
                return
            }
            
            print("📊 Core Data'dan silinecek skor sayısı: \(highScores.count)")
            
            for score in highScores {
                context.delete(score)
                print("🗑️ Core Data'dan silindi: \(score.id?.uuidString ?? "bilinmiyor")")
            }
            
            try context.save()
            print("✅ Tüm yüksek skorlar Core Data'dan silindi")
            completion(true)
        } catch {
            print("❌ Core Data skor silme hatası: \(error.localizedDescription)")
            completion(false)
        }
    }
}

// MARK: - Önizleme Sağlayıcı
struct DetailedStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedStatisticsView()
            .environmentObject(LocalizationManager.shared)
    }
} 