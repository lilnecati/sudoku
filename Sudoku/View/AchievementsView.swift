import SwiftUI
import StoreKit

// Ana Başarımlar sayfası - artık bir sheet görünümü
struct AchievementsSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var showUnlockedOnly = false
    @State private var showingInfo = false
    // Filtre ve sıralama seçenekleri için enum'lar
    enum FilterOption {
        case all, completed, incomplete
    }
    
    enum SortOption {
        case `default`, completed, progress
    }
    
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .default
    // Ekranı yenilemek için ekstra durum
    @State private var refreshID = UUID()
    
    // Kategorilere göre filtrelenmiş başarılar
    private var filteredAchievements: [Achievement] {
        // İlk önce tüm başarımları al
        var achievements = achievementManager.achievements
        
        // Kategori filtresi
        if let category = selectedCategory {
            achievements = achievements.filter { $0.category == category }
        }
        
        // Açılmış başarı filtresi
        if showUnlockedOnly {
            achievements = achievements.filter { $0.isCompleted }
        }
        
        // Sıralama için yardımcı fonksiyon
        return sortAchievements(achievements)
    }
    
    // Başarımları sıralayan yardımcı fonksiyon
    private func sortAchievements(_ achievements: [Achievement]) -> [Achievement] {
        return achievements.sorted(by: compareAchievements)
    }
    
    // Karşılaştırma fonksiyonu - ayrı şekilde tanımlandı
    private func compareAchievements(a: Achievement, b: Achievement) -> Bool {
        // Önce duruma göre karşılaştır
        let comparisonResult = compareByCompletionStatus(a: a, b: b)
        if comparisonResult != nil {
            return comparisonResult!
        }
        
        // Durumları aynıysa kategoriye göre karşılaştır
        return compareByCategoryAndId(a: a, b: b)
    }
    
    // Tamamlanma durumuna göre karşılaştırma
    private func compareByCompletionStatus(a: Achievement, b: Achievement) -> Bool? {
        // Önce tamamlanmış olanlar
        if a.isCompleted && !b.isCompleted {
            return true
        } 
        // Sonra tamamlanmamış olanlar
        else if !a.isCompleted && b.isCompleted {
            return false
        } 
        // İkisi de tamamlanmamışsa, ilerleme durumuna göre
        else if !a.isCompleted && !b.isCompleted {
            return a.progress > b.progress
        } 
        
        // İkisi de tamamlandıysa nil döndür (diğer kriterlere göre değerlendirilecek)
        return nil
    }
    
    // Kategori ve ID'ye göre karşılaştırma
    private func compareByCategoryAndId(a: Achievement, b: Achievement) -> Bool {
        // Aynı kategorideyse ID'ye göre
        if a.category == b.category {
            return a.id < b.id
        }
        // Farklı kategorideyse kategori adına göre
        return a.category.rawValue < b.category.rawValue
    }
    
    var body: some View {
        NavigationView {
        ZStack {
                Color(isBejMode ? UIColor(ThemeManager.BejThemeColors.background) : .systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Kategori seçici
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CategoryFilterButton(
                                title: "achievements.category.all",
                                systemImage: "rectangle.grid.2x2.fill",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil },
                                isLocalizedKey: true,
                                defaultValue: "Tümü"
                            )
                            
                            CategoryFilterButton(
                                title: "achievements.category.daily",
                                systemImage: "calendar",
                                isSelected: selectedCategory == .beginner,
                                action: { selectedCategory = .beginner },
                                isLocalizedKey: true,
                                defaultValue: "Günlük"
                            )
                            
                            CategoryFilterButton(
                                title: "achievements.category.streak",
                                systemImage: "flame.fill",
                                isSelected: selectedCategory == .streak,
                                action: { selectedCategory = .streak },
                                isLocalizedKey: true,
                                defaultValue: "Seri"
                            )
                            
                            CategoryFilterButton(
                                title: "achievements.category.special",
                                systemImage: "sparkles",
                                isSelected: selectedCategory == .special,
                                action: { selectedCategory = .special },
                                isLocalizedKey: true,
                                defaultValue: "Özel"
                            )
                            
                            CategoryFilterButton(
                                title: "achievements.category.difficulty",
                                systemImage: "chart.bar.fill",
                                isSelected: selectedCategory == .difficulty,
                                action: { selectedCategory = .difficulty },
                                isLocalizedKey: true,
                                defaultValue: "Zorluk"
                            )
                            
                            CategoryFilterButton(
                                title: "achievements.category.time",
                                systemImage: "clock.fill",
                                isSelected: selectedCategory == .time,
                                action: { selectedCategory = .time },
                                isLocalizedKey: true,
                                defaultValue: "Zaman"
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(isBejMode ? ThemeManager.BejThemeColors.cardBackground : Color(.systemBackground))
                    
                    // Filtre seçenekleri
                    HStack {
                        Menu {
                            Button(action: {
                                self.showUnlockedOnly = false
                                self.filterOption = .all
                            }) {
                                Label {
                                    Text.localizedSafe("achievements.filter.all", defaultValue: "Tümünü Göster")
                                } icon: {
                                    if filterOption == .all {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button(action: {
                                self.showUnlockedOnly = true
                                self.filterOption = .completed
                            }) {
                                Label {
                                    Text.localizedSafe("achievements.filter.completed", defaultValue: "Tamamlananlar")
                                } icon: {
                                    if filterOption == .completed {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button(action: {
                                self.showUnlockedOnly = false
                                self.filterOption = .incomplete
                            }) {
                                Label {
                                    Text.localizedSafe("achievements.filter.incomplete", defaultValue: "Tamamlanmayanlar")
                                } icon: {
                                    if filterOption == .incomplete {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text.localizedSafe("achievements.filter.button", defaultValue: "Filtrele")
                                    .scaledFont(size: 14)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isBejMode ? 
                                         ThemeManager.BejThemeColors.cardBackground.opacity(0.8) : 
                                         (colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)))
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                        }
                        
                        Spacer()
                        
                        if achievementManager.achievements.filter({ $0.isCompleted }).count > 0 {
                            // Başarı puanı
                            HStack(spacing: 4) {
                                Text("\(achievementManager.totalPoints)")
                                    .scaledFont(size: 16, weight: .bold)
                                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isBejMode ? 
                                         ThemeManager.BejThemeColors.cardBackground.opacity(0.8) : 
                                         (colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)))
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Başarı listesi
                    if filteredAchievements.isEmpty {
                        // Boş durumu
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 50))
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .gray)
                                .padding(.top, 40)
                            
                            Text.localizedSafe("achievements.empty", defaultValue: "Hiç başarım bulunamadı")
                                .scaledFont(size: 18, weight: .medium)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            
                            Text.localizedSafe("achievements.empty.subtitle", defaultValue: "Filtreleri değiştirmeyi deneyin")
                                .scaledFont(size: 15)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Başarı listesi
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredAchievements) { achievement in
                                    AchievementCard(achievement: achievement)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationBarTitle(Text.localizedSafe("achievements.title", defaultValue: "Başarımlar"), displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Tamam")
                        .fontWeight(.semibold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                }
            )
        }
        .onAppear {
            // Başarımlar AchievementManager tarafından otomatik yüklenir.
        }
    }
}

// Kategori filtre butonu
struct CategoryFilterButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    var isLocalizedKey: Bool = false
    var defaultValue: String = ""
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                
                if isLocalizedKey {
                    Text.localizedSafe(title, defaultValue: defaultValue)
                        .scaledFont(size: 14)
                } else {
                    Text(title)
                        .scaledFont(size: 14)
                }
            }
            .foregroundColor(isSelected ? 
                           (isBejMode ? ThemeManager.BejThemeColors.cardBackground : .white) : 
                           (isBejMode ? ThemeManager.BejThemeColors.text : .primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? 
                         (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue) : 
                         (isBejMode ? 
                          ThemeManager.BejThemeColors.background : 
                          (colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

// Başarı kartı
struct AchievementCard: View {
    let achievement: Achievement
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDetail = false
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        Button(action: {
            showDetail.toggle()
        }) {
            HStack(spacing: 15) {
                // Başarı ikonu
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                isBejMode ? 
                                    ThemeManager.BejThemeColors.accent.opacity(0.7) : 
                                    colorForCategory(achievement.category).opacity(0.7),
                                isBejMode ? 
                                    ThemeManager.BejThemeColors.accent : 
                                    colorForCategory(achievement.category)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                        .shadow(color: isBejMode ? 
                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                               colorForCategory(achievement.category).opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .opacity(achievement.isCompleted ? 1.0 : 0.6)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Başarı adı
                    Text.localizedSafe("achievement.\(achievement.id).name", defaultValue: achievement.name)
                        .scaledFont(size: 16, weight: .medium)
                        .foregroundColor(achievement.isCompleted ? 
                                        (isBejMode ? ThemeManager.BejThemeColors.text : .primary) : 
                                        (isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary))
                    
                    // Başarı açıklaması
                    Text.localizedSafe("achievement.\(achievement.id).description", defaultValue: achievement.description)
                        .scaledFont(size: 14)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                        .lineLimit(1)
                    
                    // İlerleme çubuğu
                    ZStack(alignment: .leading) {
                        // Arka plan
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isBejMode ? 
                                 ThemeManager.BejThemeColors.secondaryBackground : 
                                 (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)))
                            .frame(height: 6)
                        
                        // İlerleme
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isBejMode ? 
                                 ThemeManager.BejThemeColors.accent : 
                                 colorForCategory(achievement.category))
                            .frame(width: max(4, CGFloat(achievement.progress) * 200), height: 6)
                    }
                    .frame(width: 200, height: 6)
                }
                
                Spacer()
                
                // Rozet/Kilit ikonu
                Image(systemName: achievement.isCompleted ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(achievement.isCompleted ? 
                                    (isBejMode ? ThemeManager.BejThemeColors.accent : .green) : 
                                    (isBejMode ? ThemeManager.BejThemeColors.secondaryText : .gray))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(.systemGray6) : Color.white))
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            AchievementDetailView(achievement: achievement)
        }
    }
    
    // Kategori için renk
    private func colorForCategory(_ category: AchievementCategory) -> Color {
        switch category {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .expert:
            return .orange
        case .streak:
            return .purple
        case .special:
            return .pink
        case .time:
            return .yellow
        case .difficulty:
            return .blue
        }
    }
}

// Başarı detay görünümü
struct AchievementDetailView: View {
    let achievement: Achievement
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Başarı kartı
                    VStack(spacing: 15) {
                        // İkon
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        colorForCategory(achievement.category).opacity(0.7),
                                        colorForCategory(achievement.category)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .shadow(color: colorForCategory(achievement.category).opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            Image(systemName: achievement.iconName)
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // Başlık
                        Text(achievement.name)
                            .scaledFont(size: 22, weight: .bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Açıklama
                        Text(achievement.description)
                            .scaledFont(size: 16)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Kategori
                        Text(achievement.category.rawValue)
                            .scaledFont(size: 14)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorForCategory(achievement.category).opacity(0.2))
                            )
                            .foregroundColor(colorForCategory(achievement.category))
                        
                        // İlerleme
                        VStack(spacing: 8) {
                            // İlerleme çubuğu
                            ZStack(alignment: .leading) {
                                // Arka plan
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    .frame(height: 12)
                                
                                // İlerleme
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorForCategory(achievement.category))
                                    .frame(width: max(4, CGFloat(achievement.progress) * 300), height: 12)
                            }
                            .frame(width: 300, height: 12)
                            
                            // İlerleme metni
                            HStack {
                                // Durum bilgisi
                                if achievement.isCompleted {
                                    Text.localizedSafe("achievements.status.completed", defaultValue: "Tamamlandı")
                                        .scaledFont(size: 12)
                                        .foregroundColor(.secondary)
                                } else {
                                    let progressFormat = NSLocalizedString("achievements.status.progress", comment: "")
                                    
                                    // Hesaplamaları View yapısı dışında yapalım
                                    let progress = getProgressValues(for: achievement)
                                    let progressText = String.localizedStringWithFormat(progressFormat, progress.current, progress.target)
                                    
                                    Text(progressText)
                                        .scaledFont(size: 12)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Ödül puanı
                                let pointsFormat = NSLocalizedString("achievements.status.reward_points", comment: "")
                                let pointsText = String.localizedStringWithFormat(pointsFormat, achievement.pointValue)
                                
                                Text(pointsText)
                                    .scaledFont(size: 12, weight: .bold)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                        
                        // Tamamlandı işareti
                        if achievement.isCompleted {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                
                                Text.localizedSafe("achievements.completed", defaultValue: "Başarı Kazanıldı!")
                                    .scaledFont(size: 16, weight: .medium)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 10)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding()
                    
                    // İpucu bölümü
                    if !achievement.isCompleted {
                        VStack(alignment: .leading, spacing: 10) {
                            tipTitle()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                tipView(for: achievement)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            )
                            .padding(.horizontal)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitle(Text.localizedSafe("achievements.detail.title", defaultValue: "Başarı Detayı"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text.localizedSafe("achievements.detail.close", defaultValue: "Kapat")
            })
        }
    }
    
    // Kategori için renk
    private func colorForCategory(_ category: AchievementCategory) -> Color {
        switch category {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .expert:
            return .orange
        case .streak:
            return .purple
        case .special:
            return .pink
        case .time:
            return .yellow
        case .difficulty:
            return .blue
        }
    }
    
    // Tarih formatı
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    // İpucu görünümü
    private func tipView(for achievement: Achievement) -> some View {
        Group {
            if isTotalCompletionAchievement(achievement.id) {
                totalCompletionsTipView(achievement)
            } else if isDifficultyAchievement(achievement.id) {
                difficultyTipView(for: achievement)
        } else if isStreakAchievement(achievement.id) {
                streakTipView(for: achievement)
        } else if isTimeAchievement(achievement.id) {
                timeTipView(for: achievement)
        } else if achievement.id == "no_errors" {
            noErrorsTipView()
            } else if isPuzzleVarietyAchievement(achievement.id) {
                variationsTipView(achievement)
        } else {
                // Diğer başarım tipleri için varsayılan ipucu
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text.localizedSafe("achievements.tip.general", defaultValue: "Bu başarımın koşullarını sağlamak için oynamaya devam edin.")
                        .scaledFont(size: 14)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                )
            }
        }
    }
    
    // İlerleme metni
    private func progressText() -> some View {
        Group {
            if achievement.isCompleted {
                Text.localizedSafe("achievements.completed", defaultValue: "Başarı Kazanıldı!")
                    .font(.headline)
                    .foregroundColor(.green)
            } else {
                let localizedFormat = NSLocalizedString("achievements.progress.value", comment: "")
                let localizedText = String.localizedStringWithFormat(localizedFormat, achievement.currentValue, achievement.targetValue)
                
                Text(localizedText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // İpucu başlığı
    private func tipTitle() -> some View {
        HStack {
            Text.localizedSafe("achievements.howto.earn", defaultValue: "Nasıl Kazanılır?")
                .font(.headline)
                .padding(.leading, 8)
            Spacer()
        }
        .padding(.top)
    }
    
    // Başarım ID kontrolü için yardımcı metodlar
    private func isDifficultyAchievement(_ id: String) -> Bool {
        return id.hasPrefix("easy_") || 
               id.hasPrefix("medium_") || 
               id.hasPrefix("hard_") || 
               id.hasPrefix("expert_")
    }
    
    private func isStreakAchievement(_ id: String) -> Bool {
        return id.hasPrefix("streak_")
    }
    
    private func isTimeAchievement(_ id: String) -> Bool {
        return id.hasPrefix("time_")
    }
    
    private func isTotalCompletionAchievement(_ id: String) -> Bool {
        return id.hasPrefix("total_")
    }
    
    private func isPuzzleVarietyAchievement(_ id: String) -> Bool {
        return id.hasPrefix("variety_")
    }
    
    // Özel ipucu görünümleri
    @ViewBuilder
    private func difficultyTipView(for achievement: Achievement) -> some View {
        let components = achievement.id.components(separatedBy: "_")
        if components.count >= 2 {
            let difficulty = components[0]
            
        HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                
                // %@ formatı kullanılmış, doğru şekilde formatlama yapılmalı
                let localizedFormat = NSLocalizedString("achievements.tip.difficulty", comment: "")
                let localizedText = String.localizedStringWithFormat(localizedFormat, difficulty)
                
                Text(localizedText)
                    .font(.footnote)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(8)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func streakTipView(for achievement: Achievement) -> some View {
        if let days = Int(achievement.id.components(separatedBy: "_").last ?? "0") {
        HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.purple)
                
                // %lld formatı kullanılmış, doğru şekilde formatlama yapılmalı
                let localizedFormat = NSLocalizedString("achievements.tip.streak", comment: "")
                let localizedText = String.localizedStringWithFormat(localizedFormat, days)
                
                Text(localizedText)
                    .font(.footnote)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(8)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func timeTipView(for achievement: Achievement) -> some View {
        if let minutes = Int(achievement.id.components(separatedBy: "_").last ?? "0") {
        HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.yellow)
                
                // %lld formatı kullanılmış, doğru şekilde formatlama yapılmalı
                let localizedFormat = NSLocalizedString("achievements.tip.time", comment: "")
                let localizedText = String.localizedStringWithFormat(localizedFormat, minutes)
                
                Text(localizedText)
                    .font(.footnote)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(8)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func noErrorsTipView() -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text.localizedSafe("achievements.tip.no_errors", defaultValue: "Hiç hata yapmadan bir Sudoku tamamlayın")
                .font(.footnote)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.8))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func totalCompletionsTipView(_ achievement: Achievement) -> some View {
        if let count = Int(achievement.id.components(separatedBy: "_").last ?? "0") {
        HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.blue)
                
                // %lld formatı kullanılmış, doğru şekilde formatlama yapılmalı
                let localizedFormat = NSLocalizedString("achievements.tip.total_games", comment: "")
                let localizedText = String.localizedStringWithFormat(localizedFormat, count)
                
                Text(localizedText)
                    .font(.footnote)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(8)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func variationsTipView(_ achievement: Achievement) -> some View {
        if let count = Int(achievement.id.components(separatedBy: "_").last ?? "0") {
        HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.orange)
                
                // %lld formatı kullanılmış, doğru şekilde formatlama yapılmalı
                let localizedFormat = NSLocalizedString("achievements.tip.variations", comment: "")
                let localizedText = String.localizedStringWithFormat(localizedFormat, count)
                
                Text(localizedText)
                    .font(.footnote)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(8)
        } else {
            EmptyView()
        }
    }
    
    // Yardımcı fonksiyon - ilerleme değerlerini hesaplar
    private func getProgressValues(for achievement: Achievement) -> (current: Int, target: Int) {
        var currentVal = 0
        var targetVal = achievement.targetValue
        
        switch achievement.status {
        case .inProgress(let current, let required):
            currentVal = current
            targetVal = required
        case .completed:
            currentVal = achievement.targetValue
            targetVal = achievement.targetValue
        case .locked:
            currentVal = 0
        }
        
        return (currentVal, targetVal)
    }
}

// Başarı bildirimi
struct AchievementNotification: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    
    @State private var isShowing = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                // Başarı ikonu
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                colorForCategory(achievement.category).opacity(0.7),
                                colorForCategory(achievement.category)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 45, height: 45)
                        .shadow(color: colorForCategory(achievement.category).opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text.localizedSafe("achievements.notification.new", defaultValue: "Yeni Başarı!")
                        .scaledFont(size: 16, weight: .medium)
                        .foregroundColor(.primary)
                    
                    Text.localizedSafe("achievement.\(achievement.id).name", defaultValue: achievement.name)
                        .scaledFont(size: 14)
                        .foregroundColor(.secondary)
                    
                    let pointsFormat = NSLocalizedString("achievements.notification.points", comment: "")
                    let pointsText = String.localizedStringWithFormat(pointsFormat, achievement.pointValue)
                    
                    Text(pointsText)
                        .scaledFont(size: 12)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isShowing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            .offset(y: isShowing ? 0 : 200)
        }
        .onAppear {
            withAnimation(.spring()) {
                isShowing = true
            }
            
            // 4 saniye sonra otomatik kapanma
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if isShowing {
                    withAnimation {
                        isShowing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
    
    // Kategori için renk
    private func colorForCategory(_ category: AchievementCategory) -> Color {
        switch category {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .expert:
            return .orange
        case .streak:
            return .purple
        case .special:
            return .pink
        case .time:
            return .yellow
        case .difficulty:
            return .blue
        }
    }
}

// Eski AchievementsView'ı yedekliyoruz
// Orijinal AchievementsView
struct AchievementsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showAchievementsSheet = false
    
    var body: some View {
        ZStack {
            // Arka plan
            GridBackgroundView()
                .ignoresSafeArea()
            
            // İçerik
            Button(action: {
                showAchievementsSheet = true
            }) {
                Text("Başarımlar")
                    .scaledFont(size: 16, weight: .medium)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .sheet(isPresented: $showAchievementsSheet) {
                AchievementsSheet()
            }
        }
    }
}

struct AchievementsInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text.localizedSafe("achievements.info.title", defaultValue: "Başarımlar Hakkında")
                            .font(.headline)
                        
                        Text.localizedSafe("achievements.info.description", defaultValue: "Başarımlar, Sudoku oynarken ilerlemenizi ve başarılarınızı takip eden özel ödüllerdir. Farklı kategorilerde başarımlar kazanabilir ve yıldız puanları toplayabilirsiniz.")
                            .font(.body)
                        
                        Text.localizedSafe("achievements.info.categories", defaultValue: "Başarım Kategorileri")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            Text.localizedSafe("achievements.info.daily", defaultValue: "Başlangıç: Kolay zorluk seviyesinde tamamlanan başarımlar.")
                        }
                        
                        HStack {
                            Image(systemName: "flame")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.orange)
                            Text.localizedSafe("achievements.info.streak", defaultValue: "Seri: Arka arkaya günlerde oynayarak kazanılan başarımlar.")
                        }
                        
                        HStack {
                            Image(systemName: "star")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.yellow)
                            Text.localizedSafe("achievements.info.special", defaultValue: "Özel: Belirli koşulları sağlayarak kazanılan özel başarımlar.")
                        }
                        
                        HStack {
                            Image(systemName: "chart.bar")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.purple)
                            Text.localizedSafe("achievements.info.difficulty", defaultValue: "Zorluk: Farklı zorluk seviyelerinde oyunlar tamamlayarak kazanılan başarımlar.")
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.red)
                            Text.localizedSafe("achievements.info.time", defaultValue: "Zaman: Belirli sürelerde oyunlar tamamlayarak kazanılan başarımlar.")
                        }
                    }
                    
                    Divider()
                    
                    Group {
                        Text.localizedSafe("achievements.info.tips", defaultValue: "İpuçları")
                            .font(.headline)
                        
                        Text.localizedSafe("achievements.info.tips.description", defaultValue: "Başarımların detay sayfasında, onları nasıl kazanacağınıza dair ipuçları bulabilirsiniz. Bazı başarımlar için ilerleme durumunuzu da görebilirsiniz.")
                            .font(.body)
                    }
                    
                    Divider()
                    
                    Group {
                        Text.localizedSafe("achievements.info.sync", defaultValue: "Senkronizasyon")
                            .font(.headline)
                        
                        Text.localizedSafe("achievements.info.sync.description", defaultValue: "Başarımlarınız, hesabınıza giriş yaptığınızda otomatik olarak senkronize edilir ve farklı cihazlarda da erişilebilir olur.")
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationBarTitle(Text.localizedSafe("achievements.info.header", defaultValue: "Başarımlar Hakkında"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text.localizedSafe("achievements.info.done", defaultValue: "Tamam")
            })
        }
    }
}

extension View {
    // Herhangi bir View'ı AnyView tipine dönüştürmek için yardımcı metod
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}

// AchievementCategory için all değerini tanımlayan extension'ı tutuyoruz
extension AchievementCategory {
    static var all: AchievementCategory? {
        return nil
    }
}
