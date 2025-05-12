//  SavedGamesView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 10.02.2025.
//

import SwiftUI
import CoreData
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SavedGameDisplayItem: Identifiable {
    let id: UUID
    let originalGame: SavedGame

    let difficulty: String
    let difficultyIconName: String
    let difficultyColor: Color
    let dateCreatedFormatted: String
    let miniBoardState: [String: Any]
    let gameProgress: Double
    let elapsedTimeFormatted: String
    let errorCount: Int
    let remainingHints: Int
    let isCompleted: Bool

    let elapsedTimeInSeconds: Int
    let calculatedProgress: Double

    init(game: SavedGame, themeManager: ThemeManager?, calculatedProgress: Double) {
        self.id = game.id ?? UUID()
        self.originalGame = game
        self.calculatedProgress = calculatedProgress

        self.difficulty = game.difficulty ?? "Bilinmeyen"
        
        let boardStateJSON = SavedGameDisplayItem.parseBoardState(from: game.boardState)

        self.isCompleted = boardStateJSON["isCompleted"] as? Bool ?? false
        
        // elapsedTime önceliği: JSON, sonra CoreData'daki ana game.elapsedTime
        if let jsonElapsedTime = boardStateJSON["elapsedTime"] as? Int {
            self.elapsedTimeInSeconds = jsonElapsedTime
        } else if let jsonElapsedTimeDouble = boardStateJSON["elapsedTime"] as? Double {
            self.elapsedTimeInSeconds = Int(jsonElapsedTimeDouble)
        } else {
            self.elapsedTimeInSeconds = Int(game.elapsedTime)
        }
        
        self.errorCount = boardStateJSON["errorCount"] as? Int ?? 0
        self.remainingHints = boardStateJSON["remainingHints"] as? Int ?? 3

        // gameProgress artık doğrudan calculatedProgress'ten geliyor
        self.gameProgress = calculatedProgress

        self.dateCreatedFormatted = SavedGameDisplayItem.formatDate(game.dateCreated ?? Date())
        self.elapsedTimeFormatted = SavedGameDisplayItem.formatTime(Double(self.elapsedTimeInSeconds))
        
        self.difficultyIconName = SavedGameDisplayItem.getDifficultyIconName(difficulty: self.difficulty)
        self.difficultyColor = SavedGameDisplayItem.getDifficultyColor(difficulty: self.difficulty, themeManager: themeManager)

        self.miniBoardState = boardStateJSON
    }

    static func parseBoardState(from data: Data?) -> [String: Any] {
        guard let boardData = data else { return [:] }
        do {
            if let dict = try JSONSerialization.jsonObject(with: boardData, options: []) as? [String: Any] {
                return dict
            }
        } catch {
            print("SavedGameDisplayItem: JSON ayrıştırma hatası: \\(error)")
        }
        return [:]
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "app_language") ?? "tr")
        return formatter.string(from: date)
    }

    static func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
             return String(format: "%d dk %02d sn", minutes, seconds)
        } else {
             return String(format: "%d sn", seconds)
        }
    }
    
    static func getDifficultyIconName(difficulty: String) -> String {
        let currentLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        let lowercasedDifficulty = difficulty.lowercased()

        if currentLanguage == "en" {
            switch lowercasedDifficulty {
                case "easy": return "leaf.fill"
                case "medium": return "flame.fill"
                case "hard": return "bolt.fill"
                case "expert": return "star.fill"
                default: return "questionmark.circle.fill"
            }
        } else if currentLanguage == "fr" {
            switch lowercasedDifficulty {
                case "facile": return "leaf.fill"
                case "moyen": return "flame.fill"
                case "difficile": return "bolt.fill"
                case "expert": return "star.fill"
                default: return "questionmark.circle.fill"
            }
        } else { // Türkçe
            switch difficulty { // Türkçe için büyük/küçük harf duyarlı olabilir, orijinalini kullanalım
                case "Kolay": return "leaf.fill"
                case "Orta": return "flame.fill"
                case "Zor": return "bolt.fill"
                case "Uzman": return "star.fill"
                default: return "questionmark.circle.fill"
            }
        }
    }

    static func getDifficultyColor(difficulty: String, themeManager: ThemeManager?) -> Color {
        let isBejMode = themeManager?.bejMode ?? false
        let lowercasedDifficulty = difficulty.lowercased() // Karşılaştırmalar için küçük harf

        // Renkleri bej moda ve normal moda göre ayır
        if isBejMode {
            if ["kolay", "easy", "facile"].contains(lowercasedDifficulty) { return Color(red: 0.4, green: 0.6, blue: 0.3) }
            if ["orta", "medium", "moyen"].contains(lowercasedDifficulty) { return Color(red: 0.7, green: 0.5, blue: 0.2) }
            if ["zor", "hard", "difficile"].contains(lowercasedDifficulty) { return Color(red: 0.7, green: 0.3, blue: 0.2) }
            if ["uzman", "expert"].contains(lowercasedDifficulty) { return Color(red: 0.5, green: 0.3, blue: 0.5) }
            return .gray
        } else {
            if ["kolay", "easy", "facile"].contains(lowercasedDifficulty) { return .green }
            if ["orta", "medium", "moyen"].contains(lowercasedDifficulty) { return .blue }
            if ["zor", "hard", "difficile"].contains(lowercasedDifficulty) { return .orange }
            if ["uzman", "expert"].contains(lowercasedDifficulty) { return .red }
            return .gray
        }
    }
}

struct SavedGamesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.textScale) var textScale
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // @State private var savedGames: [SavedGame] = [] { // Eski state
    //     didSet {
    //         filterGames()
    //     }
    // }
    @State private var allDisplayItems: [SavedGameDisplayItem] = [] // Ham, filtrelenmemiş display item'lar
    @State private var filteredGames: [SavedGameDisplayItem] = []  // Filtrelenmiş oyunları saklayacak yeni değişken
    
    @ObservedObject var viewModel: SudokuViewModel
    @State private var gameToDelete: SavedGame? = nil
    @State private var showingDeleteAlert = false
    @State private var selectedDifficulty: String = "Tümü" {
        didSet {
            // Zorluk seviyesi değiştiğinde filtrelemeyi çağır
            filterGames()
        }
    }
    @Environment(\.presentationMode) var presentationMode
    
    // Oyun seçme fonksiyonu - ContentView'a oyunu iletmek için
    var gameSelected: (NSManagedObject) -> Void
    
    // Animasyonları kaldırmak için önce dosyanın içeriğini okumam gerekiyor
    
    var difficultyLevels: [String] {
        // Dile göre zorluk seviyelerini ayarla
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        
        if languageCode == "en" {
            return ["All", "Easy", "Medium", "Hard", "Expert"]
        } else if languageCode == "fr" {
            return ["Tous", "Facile", "Moyen", "Difficile", "Expert"]
        } else {
            return ["Tümü", "Kolay", "Orta", "Zor", "Uzman"]
        }
    }
    
    // Oyunları filtreleyen fonksiyon
    private func filterGames() {
        logInfo("Filtreleme başladı: \(allDisplayItems.count) oyun mevcut")
        
        // Önce tamamlanmamış oyunları filtrele (isCompleted == false)
        let uncompleted = allDisplayItems.filter { !$0.isCompleted }
        
        logInfo("Tamamlanmamış oyun sayısı: \(uncompleted.count)")
        
        // Ardından zorluk seviyesine göre filtrele
        if selectedDifficulty == "Tümü" || selectedDifficulty == "All" || selectedDifficulty == "Tous" {
            logInfo("Tüm zorluk seviyeleri gösteriliyor. Toplam oyun sayısı: \(uncompleted.count)")
            filteredGames = uncompleted.sorted { $0.originalGame.dateCreated ?? Date.distantPast > $1.originalGame.dateCreated ?? Date.distantPast }
        } else {
            let filtered = uncompleted.filter { $0.difficulty == selectedDifficulty }
            logInfo("'\(selectedDifficulty)' zorluk seviyesine göre filtreleniyor. Oyun sayısı: \(filtered.count)")
            filteredGames = filtered.sorted { $0.originalGame.dateCreated ?? Date.distantPast > $1.originalGame.dateCreated ?? Date.distantPast }
        }
        
        logInfo("UI güncellendi: \(filteredGames.count) oyun gösteriliyor")
    }
    
    // Boş durum görünümü
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "bookmark.slash.fill")
                .font(.system(size: 70))
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.5) : Color.blue.opacity(0.5))
            
            Text.localizedSafe("Kaydedilmiş oyun bulunamadı")
                .font(.system(size: Font.TextStyle.title2.defaultSize * textScale).bold())
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : Color.textColor(for: colorScheme))
            
            if selectedDifficulty == "Tümü" || selectedDifficulty == "All" || selectedDifficulty == "Tous" {
                Text.localizedSafe("Henüz kaydedilmiş oyun bulunmamaktadır. Bir oyunu kaydetmek için oyun ekranında 'Kaydet' butonunu kullanın.")
                    .font(.system(size: Font.TextStyle.subheadline.defaultSize * textScale))
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                // Format string'i doğru şekilde kullan
                let difficultyText = selectedDifficulty
                let formatKey = "%@ zorluk seviyesinde kaydedilmiş oyun bulunmamaktadır."
                
                // Önce yerelleştirilmiş formatı al, sonra formatla
                let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
                let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
                let bundle = path != nil ? Bundle(path: path!) : Bundle.main
                let localizedFormat = bundle?.localizedString(forKey: formatKey, value: formatKey, table: "Localizable") ?? formatKey
                
                // Formatı uygula
                let formattedText = String(format: localizedFormat, difficultyText)
                
                Text(formattedText)
                    .font(.system(size: Font.TextStyle.subheadline.defaultSize * textScale))
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(.systemGray6) : Color.white))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding()
    }
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // Başlık ve Temizle butonu yan yana
                HStack {
                    Text.localizedSafe("Kaydedilmiş Oyunlar")
                        .font(.system(size: 28 * textScale, weight: .bold, design: .rounded))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : Color.textColor(for: colorScheme))
                    
                    Spacer()
                    
                    // Tümünü Temizle butonu
                    if !filteredGames.isEmpty {
                        Button(action: {
                            // Sadece PersistenceController üzerinden silme işlemini tetikle.
                            // Arayüz güncellemesi "RefreshSavedGames" bildirimi ile yapılacak.
                            PersistenceController.shared.deleteAllSavedGames()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text.localizedSafe("Tümünü Sil")
                            }
                            .font(.system(size: 14 * textScale, weight: .medium))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isBejMode ? 
                                         ThemeManager.BejThemeColors.cardBackground : 
                                         (colorScheme == .dark ? Color.red.opacity(0.15) : Color.red.opacity(0.1)))
                                    .overlay(
                                        Capsule()
                                            .stroke(isBejMode ? 
                                                  ThemeManager.BejThemeColors.accent.opacity(0.5) : 
                                                  Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Zorluk seviyesi seçici
                HStack {
                    ForEach(difficultyLevels, id: \.self) { difficulty in
                        Button(action: {
                            selectedDifficulty = difficulty
                        }) {
                            HStack(spacing: 4) {
                                Text(difficulty)
                                    .font(.system(size: 14 * textScale, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundColor(selectedDifficulty == difficulty ? 
                                           (isBejMode ? ThemeManager.BejThemeColors.text : .white) : 
                                           (isBejMode ? ThemeManager.BejThemeColors.text : .primary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedDifficulty == difficulty ? 
                                         (isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.8) : Color.blue) : 
                                         (isBejMode ? ThemeManager.BejThemeColors.cardBackground.opacity(0.7) : Color.clear))
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedDifficulty == difficulty ? 
                                                  (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue) : 
                                                  (isBejMode ? ThemeManager.BejThemeColors.text.opacity(0.3) : Color.gray.opacity(0.3)), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.cardBackground : 
                             (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
                
                // Boş durum veya oyun listesi
                if filteredGames.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    // Kaydedilmiş oyun listesi
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredGames) { item in
                                SavedGameCard(displayItem: item, viewModel: viewModel) {
                                    // Oyun seçimi ve ekranı kapat
                                    gameSelected(item.originalGame)
                                    presentationMode.wrappedValue.dismiss()
                                } onDelete: {
                                    // Oyun silme işlemi
                                    gameToDelete = item.originalGame
                                    showingDeleteAlert = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .onAppear {
                // CloudKit senkronizasyonunu burada değil, ViewModel veya AppDelegate'de yapacağız
                loadAndPrepareDisplayItems()
            }
            .onChange(of: selectedDifficulty) { oldValue, newValue in
                // Değişiklik filtreleme fonksiyonunda zaten ele alınıyor
                logInfo("Zorluk seviyesi değişti: \(oldValue) -> \(newValue)")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSavedGames"))) { _ in
                // Bildirim alındığında verileri yeniden yükle
                logInfo("SavedGamesView: RefreshSavedGames bildirimi alındı")
                loadAndPrepareDisplayItems()
            }
            // Silme için uyarı
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Oyunu Sil"),
                    message: Text("Bu oyunu silmek istediğinizden emin misiniz?"),
                    primaryButton: .destructive(Text("Sil")) {
                        if let game = gameToDelete {
                            deleteGame(game)
                        }
                    },
                    secondaryButton: .cancel(Text("İptal"))
                )
            }
        }
    }
    
    // Özelleştirilmiş zorluk seviyesi seçici
    private func customDifficultyPicker() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(difficultyLevels, id: \.self) { level in
                    Button(action: {
                        selectedDifficulty = level
                        SoundManager.shared.playNavigationSound()
                    }) {
                        Text(level)
                            .font(.system(size: 14 * textScale, weight: selectedDifficulty == level ? .bold : .medium))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                ZStack {
                                    if selectedDifficulty == level {
                                        Capsule()
                                            .fill(difficultyColorForLevel(level))
                                            .shadow(color: difficultyColorForLevel(level).opacity(0.4), radius: 4, x: 0, y: 2)
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
                            .foregroundColor(selectedDifficulty == level ? .white : Color.primary.opacity(0.8))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // Metni kısaltma
    private func shortenedText(for level: String) -> String {
        // Zaten kısa olduğu için doğrudan döndür
        return level
    }
    
    // Zorluk seviyesine göre renk hesaplama
    private func difficultyColorForLevel(_ level: String) -> Color {
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        
        if languageCode == "en" {
            switch level {
            case "Easy":
                return .green
            case "Medium":
                return .blue
            case "Hard":
                return .orange
            case "Expert":
                return .red
            default:
                return .purple // All için mor renk
            }
        } else if languageCode == "fr" {
            switch level {
            case "Facile":
                return .green
            case "Moyen":
                return .blue
            case "Difficile":
                return .orange
            case "Expert":
                return .red
            default:
                return .purple // Tous için mor renk
            }
        } else {
            switch level {
            case "Kolay":
                return .green
            case "Orta":
                return .blue
            case "Zor":
                return .orange
            case "Uzman":
                return .red
            default:
                return .purple // Tümü için mor renk
            }
        }
    }
    
    private func savedGameCard(for game: SavedGame) -> some View {
        let difficulty = game.difficulty ?? "Bilinmeyen"
        let dateCreated = game.dateCreated ?? Date()
        
        // Türkçe tarih formatı ayarları
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy HH:mm"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        
        // Zorluk seviyesine göre renk
        let difficultyColor: Color = {
            switch difficulty {
            case "Kolay":
                return .green
            case "Orta":
                return .blue
            case "Zor":
                return .orange
            case "Uzman":
                return .red
            default:
                return .gray
            }
        }()
        
        // Tamamlanma yüzdesi - gerçek oyun verisi temelinde 
        let completionPercentage = calculateCompletionPercentage(for: game)
        
        return ZStack {
            // Geliştirilmiş arka plan - subtle gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95),
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.9) : difficultyColor.opacity(0.03)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    // Zorluk seviyesine göre renkli kenar çizgisi - daha ince ve zarif
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [difficultyColor.opacity(0.7), difficultyColor.opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
            
            // Kart içeriği - geliştirilmiş
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Sol üst: Tarih ve saat - iyileştirilmiş
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text.localizedSafe("Tarih")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Text(dateFormatter.string(from: dateCreated))
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Spacer()
                    
                    // Sağ üst: Zorluk seviyesi - geliştirilmiş rozet
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 4) {
                            Text.localizedSafe("Zorluk")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Image(systemName: difficultyIcon(for: difficulty))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Text.localizedSafe(difficulty)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [difficultyColor.opacity(0.15), difficultyColor.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [difficultyColor.opacity(0.4), difficultyColor.opacity(0.2)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .foregroundColor(difficultyColor)
                    }
                }
                
                // Orta: İlerleme çubuğu
                VStack(spacing: 6) {
                    HStack {
                        Text.localizedSafe("Tamamlanma")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(completionPercentage)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(difficultyColor)
                    }
                    
                    // Progress bar
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 6)
                        
                        // Progress indicator
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [difficultyColor, difficultyColor.opacity(0.7)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(CGFloat(completionPercentage) / 100, 1.0)) * (UIScreen.main.bounds.width * 0.75 - 40), height: 6)
                            .animation(nil, value: completionPercentage)
                    }
                }
                .padding(.top, 4)
                
                // Ayırıcı çizgi - zarif gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [.clear, Color.gray.opacity(0.2), .clear]
                            ),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.vertical, 4)
                
                HStack(alignment: .center) {
                    // Sol alt: Süre bilgisi - geliştirilmiş görsellik
                    let elapsedTimeSeconds = Int(game.elapsedTime)
                    let minutes = elapsedTimeSeconds / 60
                    let seconds = elapsedTimeSeconds % 60
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text.localizedSafe("Süre")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Geliştirilmiş süre gösterimi
                        ZStack(alignment: .leading) {
                            // Arkaplan
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [difficultyColor.opacity(0.12), difficultyColor.opacity(0.05)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 28)
                            
                            HStack(spacing: 2) {
                                if minutes > 0 {
                                    // Dakika ve saniye
                                    Text("\(minutes)")
                                        .fontWeight(.bold)
                                        .foregroundColor(difficultyColor)
                                    
                                    Text.localizedSafe("dk")
                                        .font(.caption2)
                                        .foregroundColor(difficultyColor.opacity(0.8))
                                        .padding(.trailing, 2)
                                }
                                
                                Text("\(seconds)")
                                    .fontWeight(.bold)
                                    .foregroundColor(difficultyColor)
                                
                                Text.localizedSafe("sn")
                                    .font(.caption2)
                                    .foregroundColor(difficultyColor.opacity(0.8))
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                    
                    Spacer()
                    
                    // Sağ alt: Devam et butonu - modern UI
                    Button(action: {
                        // Animasyon kaldırıldı
                        
                        logInfo("SavedGamesView: Oyun yükleniyor ID: \(game.value(forKey: "id") ?? "ID yok")")
                        
                        // Önce SudokuViewModel'e oyunu yükle
                        viewModel.loadGame(from: game)
                        logInfo("SavedGamesView: Oyun yüklendi, callback çağrılıyor")
                        
                        // Callback'i doğrudan çağır
                        gameSelected(game)
                    }) {
                        HStack(spacing: 8) {
                            Text.localizedSafe("Devam Et")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [difficultyColor, difficultyColor.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: difficultyColor.opacity(0.5), radius: 5, x: 0, y: 3)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 210)
        .padding(.horizontal, 2)
    }
    
    // Zorluk seviyesine göre ikon belirle
    private func difficultyIcon(for difficulty: String) -> String {
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        
        if languageCode == "en" {
            switch difficulty {
            case "Easy":
                return "leaf"
            case "Medium":
                return "flame"
            case "Hard":
                return "bolt"
            case "Expert":
                return "star"
            default:
                return "square.grid.2x2" // All için grid ikonu
            }
        } else if languageCode == "fr" {
            switch difficulty {
            case "Facile":
                return "leaf"
            case "Moyen":
                return "flame"
            case "Difficile":
                return "bolt"
            case "Expert":
                return "star"
            default:
                return "square.grid.2x2" // Tous için grid ikonu
            }
        } else {
            switch difficulty {
            case "Kolay":
                return "leaf"
            case "Orta":
                return "flame"
            case "Zor":
                return "bolt"
            case "Uzman":
                return "star"
            default:
                return "square.grid.2x2" // Tümü için grid ikonu
            }
        }
    }
    
    // Kaydedilmiş oyunlar için tamamlanma yüzdesi hesaplama
    private func calculateCompletionPercentage(for game: SavedGame) -> Int {
        guard game.boardState != nil else {
            return 0 // Veri yoksa 0% göster
        }
        
        // Kaydedilmiş değer yoksa veya hesaplama gerekliyse hesapla
        let cachedKey = "completion_percentage_\(game.objectID.uriRepresentation().absoluteString)"
        if let cachedPercentage = UserDefaults.standard.object(forKey: cachedKey) as? Int {
            return cachedPercentage
        }
        
        // SudokuViewModel üzerinden tamamlanma yüzdesini al
        let percentage = viewModel.getCompletionPercentage(for: game)
        
        // 0-100 arasında bir değere dönüştür
        let result = Int(percentage * 100)
        
        // Minimum %5 değerini garantile (UI olarak tamamen boş görünmemesi için)
        let finalResult = max(5, min(result, 100))
        
        // Değeri önbelleğe al (oyundan çıkılana kadar geçerli olacak)
        UserDefaults.standard.set(finalResult, forKey: cachedKey)
        
        return finalResult
    }
    
    // Manuel olarak kayıtlı oyunları yükleme fonksiyonu
    private func loadAndPrepareDisplayItems() {
        let fetchedGames = PersistenceController.shared.getAllSavedGames()
        logInfo("Toplam \(fetchedGames.count) kayıtlı oyun yüklendi")
        
        // SavedGame nesnelerini SavedGameDisplayItem nesnelerine dönüştür
        // Bu aşamada getCompletionPercentage çağrılıyor
        DispatchQueue.global(qos: .userInitiated).async {
            let items = fetchedGames.map { game -> SavedGameDisplayItem in
                // Her oyun için ilerlemeyi hesapla
                let progress = self.viewModel.getCompletionPercentage(for: game)
                // Hesaplanan progress ile DisplayItem oluştur
                return SavedGameDisplayItem(game: game, themeManager: self.themeManager, calculatedProgress: progress)
            }
            
            // Ana thread'e dönüp UI'ı güncelle
            DispatchQueue.main.async {
                self.allDisplayItems = items
                logInfo("\(items.count) adet DisplayItem oluşturuldu")
                self.filterGames() // Başlangıç filtresini uygula
            }
        }
    }
    
    // Kayıtlı oyunu silme fonksiyonu
    private func deleteGame(_ game: SavedGame) {
        // Oyunu silmek için PersistenceController kullan
        PersistenceController.shared.deleteSavedGame(game)
        
        // UI'ı yenile
        loadAndPrepareDisplayItems()
        
        // gameToDelete'i temizle
        gameToDelete = nil
    }
}

struct SavedGameCard: View {
    let displayItem: SavedGameDisplayItem
    let viewModel: SudokuViewModel
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.textScale) var textScale
    @EnvironmentObject var themeManager: ThemeManager
    
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: displayItem.difficultyIconName)
                            .font(.system(size: 14))
                        
                        Text(displayItem.difficulty)
                            .font(.system(size: 14 * textScale, weight: .medium))
                    }
                    .foregroundColor(displayItem.difficultyColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(displayItem.difficultyColor.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(displayItem.difficultyColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                    
                    Text(displayItem.dateCreatedFormatted)
                        .font(.system(size: 12 * textScale))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                }
                .padding(.horizontal, 15)
                .padding(.top, 15)
                .padding(.bottom, 10)
                
                Divider()
                    .padding(.horizontal, 15)
                
                HStack(alignment: .center, spacing: 15) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isBejMode ? 
                                 ThemeManager.BejThemeColors.background.opacity(0.5) : 
                                 (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)))
                            .frame(width: 80, height: 80)
                        
                        MiniSudokuBoard(boardState: displayItem.miniBoardState)
                            .drawingGroup()
                            .frame(width: 70, height: 70)
                    }
                    .padding(.leading, 15)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: displayItem.gameProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: isBejMode ? ThemeManager.BejThemeColors.accent : .blue))
                            .frame(maxWidth: .infinity)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .orange)
                                    
                                    Text(displayItem.elapsedTimeFormatted)
                                        .font(.system(size: 12 * textScale, weight: .medium))
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                        .lineLimit(1)
                                }
                                
                                HStack(spacing: 5) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isBejMode ? 
                                                       Color(red: 0.7, green: 0.3, blue: 0.2) : 
                                                       .red)
                                    
                                    Text("\(displayItem.errorCount) Hata")
                                        .font(.system(size: 12 * textScale, weight: .medium))
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                        .lineLimit(1)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isBejMode ? 
                                                       Color(red: 0.7, green: 0.6, blue: 0.2) : 
                                                       .yellow)
                                    
                                    Text("\(displayItem.remainingHints) İpucu")
                                        .font(.system(size: 12 * textScale, weight: .medium))
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                        .lineLimit(1)
                                }
                                
                                HStack(spacing: 5) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                                    
                                    Text("\(Int(displayItem.gameProgress * 100))% Tamamlandı")
                                        .font(.system(size: 12 * textScale, weight: .medium))
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isBejMode ? Color(red: 0.7, green: 0.3, blue: 0.2) : .red)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isBejMode ? 
                                         ThemeManager.BejThemeColors.cardBackground : 
                                         (colorScheme == .dark ? Color.red.opacity(0.15) : Color.red.opacity(0.1)))
                            )
                    }
                    .padding(.trailing, 15)
                }
                .padding(.vertical, 15)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MiniSudokuBoard: View {
    let boardState: [String: Any]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Örnek sayıları gösterecek bir değişken
    private let sampleNumbers = [
        [nil, nil, 5, nil, nil, 8, nil, nil, nil],
        [nil, nil, nil, 4, nil, nil, 1, nil, nil],
        [3, nil, nil, nil, nil, nil, nil, 6, nil],
        [nil, 1, nil, nil, 9, nil, nil, nil, 7],
        [nil, nil, nil, nil, nil, nil, nil, nil, nil],
        [2, nil, nil, nil, 8, nil, nil, 5, nil],
        [nil, 4, nil, nil, nil, nil, nil, nil, 8],
        [nil, nil, 6, nil, nil, 3, nil, nil, nil],
        [nil, nil, nil, 5, nil, nil, 9, nil, nil]
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 9
            
            // 9x9 grid
            VStack(spacing: 0) {
                ForEach(0..<9) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9) { col in
                            // Cell
                            ZStack {
                                Rectangle()
                                    .fill(getCellColor(row: row, col: col))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        Rectangle()
                                            .stroke(isBejMode ? 
                                                  ThemeManager.BejThemeColors.text.opacity(0.3) : 
                                                  (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)), 
                                                   lineWidth: 0.5)
                                    )
                                
                                // Hücre içindeki sayı
                                if let value = getDisplayValue(row: row, col: col) {
                                    Text("\(value)")
                                        .font(.system(size: min(cellSize * 0.7, 8), weight: .medium))
                                        .foregroundColor(isBejMode ? 
                                                       ThemeManager.BejThemeColors.text : 
                                                       (colorScheme == .dark ? .white : .black))
                                }
                            }
                        }
                    }
                }
            }
            .overlay(
                // Bölge çizgileri
                GridLines(color: isBejMode ? 
                         ThemeManager.BejThemeColors.text.opacity(0.5) : 
                         (colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.3)), 
                          lineWidth: 1.0)
            )
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    private func getCellColor(row: Int, col: Int) -> Color {
        // Bej moda göre renkler
        if isBejMode {
            if getDisplayValue(row: row, col: col) == nil {
                if isFixed(row: row, col: col) {
                    return ThemeManager.BejThemeColors.background
                } else {
                    return ThemeManager.BejThemeColors.cardBackground
                }
            } else {
                return ThemeManager.BejThemeColors.accent.opacity(0.2)
            }
        } else {
            // Normal mod
            if getDisplayValue(row: row, col: col) == nil {
                if isFixed(row: row, col: col) {
                    return colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05)
                } else {
                    return colorScheme == .dark ? Color.black.opacity(0.1) : Color.white
                }
            } else {
                return colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.15)
            }
        }
    }
    
    private func getDisplayValue(row: Int, col: Int) -> Int? {
        // Önce gerçek oyun verisinden okumaya çalış
        if let value = getCellValue(row: row, col: col) {
            // Sıfırları gösterme
            return value > 0 ? value : nil
        }
        
        // Gerçek veri yoksa örnek verileri kullan (sıfırları gösterme)
        let sampleValue = sampleNumbers[row][col]
        return sampleValue != nil && sampleValue! > 0 ? sampleValue : nil
    }
    
    private func getCellValue(row: Int, col: Int) -> Int? {
        // Veriyi kontrol et
        if let boardValues = boardState["board"] as? [[Int?]] {
            if boardValues.count > row && boardValues[row].count > col {
                return boardValues[row][col]
            }
        }
        return nil
    }
    
    private func isFixed(row: Int, col: Int) -> Bool {
        // Veriyi kontrol et
        if let fixedCells = boardState["fixedCells"] as? [[Bool]] {
            if fixedCells.count > row && fixedCells[row].count > col {
                return fixedCells[row][col]
            }
        }
        
        // Örnek verilerde tek sayıları sabit göster
        return sampleNumbers[row][col] != nil
    }
}

struct GridLines: View {
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                // Dikey çizgiler
                for i in 1...2 {
                    let x = width / 3 * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                // Yatay çizgiler
                for i in 1...2 {
                    let y = height / 3 * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}
