import SwiftUI
import StoreKit

struct AchievementsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var showUnlockedOnly = false
    
    // Kategorilere göre filtrelenmiş başarılar
    private var filteredAchievements: [Achievement] {
        var achievements = achievementManager.achievements
        
        // Kategori filtresi
        if let category = selectedCategory {
            achievements = achievements.filter { $0.category == category }
        }
        
        // Açılmış başarı filtresi
        if showUnlockedOnly {
            achievements = achievements.filter { $0.isCompleted }
        }
        
        // Önce tamamlananlar, sonra ilerleme durumunda olanlar, en son kilitliler
        return achievements.sorted { a, b in
            if a.isCompleted && !b.isCompleted {
                return true
            } else if !a.isCompleted && b.isCompleted {
                return false
            } else if !a.isCompleted && !b.isCompleted {
                return a.progress > b.progress
            } else {
                // İki başarı da tamamlanmışsa, kategori ve ID'ye göre sırala
                if a.category == b.category {
                    return a.id < b.id
                }
                return a.category.rawValue < b.category.rawValue
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Arka plan
            GridBackgroundView()
                .ignoresSafeArea()
            
            // İçerik
            VStack(spacing: 0) {
                // Başlık ve toplam puan
                HStack {
                    Text("Başarılar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Toplam puan göstergesi
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        
                        Text("\(achievementManager.totalPoints)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                    )
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Filtreler
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Tümü filtresi
                        CategoryFilterButton(
                            title: "Tümü",
                            systemImage: "list.bullet",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        // Kategori filtreleri
                        ForEach(AchievementCategory.allCases) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                systemImage: category.iconName,
                                isSelected: selectedCategory == category,
                                action: { 
                                    selectedCategory = selectedCategory == category ? nil : category
                                }
                            )
                        }
                        
                        // Sadece açılanlar filtresi
                        Toggle(isOn: $showUnlockedOnly) {
                            Label {
                                Text("Sadece Açılanlar")
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "lock.open.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Başarılar listesi
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAchievements) { achievement in
                            AchievementCard(achievement: achievement)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// Kategori filtre butonu
struct CategoryFilterButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.subheadline)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : (colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground)))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

// Başarı kartı
struct AchievementCard: View {
    let achievement: Achievement
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showDetail = false
    
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
                                colorForCategory(achievement.category).opacity(0.7),
                                colorForCategory(achievement.category)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                        .shadow(color: colorForCategory(achievement.category).opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .opacity(achievement.isCompleted ? 1.0 : 0.6)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Başarı adı
                    Text(achievement.name)
                        .font(.headline)
                        .foregroundColor(achievement.isCompleted ? .primary : .secondary)
                    
                    // Başarı açıklaması
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // İlerleme çubuğu
                    ZStack(alignment: .leading) {
                        // Arka plan
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            .frame(height: 6)
                        
                        // İlerleme
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForCategory(achievement.category))
                            .frame(width: max(4, CGFloat(achievement.progress) * 200), height: 6)
                            .animation(.easeInOut, value: achievement.progress)
                    }
                    .frame(width: 200)
                }
                
                Spacer()
                
                // Rozet/Kilit ikonu
                Image(systemName: achievement.isCompleted ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(achievement.isCompleted ? .green : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
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
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Açıklama
                        Text(achievement.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Kategori
                        Text(achievement.category.rawValue)
                            .font(.subheadline)
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
                            .frame(width: 300)
                            
                            // İlerleme metni
                            HStack {
                                // Durum bilgisi
                                switch achievement.status {
                                case .locked:
                                    Text("Kilitli")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                case .inProgress(let current, let required):
                                    Text("\(current) / \(required)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                case .completed(let date):
                                    Text("Tamamlandı: \(formattedDate(date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Ödül puanı
                                Text("+\(achievement.rewardPoints) puan")
                                    .font(.caption)
                                    .fontWeight(.bold)
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
                                
                                Text("Başarı Kazanıldı!")
                                    .font(.headline)
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
                            Text("Nasıl Kazanılır?")
                                .font(.headline)
                                .padding(.leading)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                tipForAchievement(achievement)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationBarTitle("Başarı Detayı", displayMode: .inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
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
    
    // Başarı için ipucu
    @ViewBuilder
    private func tipForAchievement(_ achievement: Achievement) -> some View {
        if achievement.id.hasPrefix("easy_") || 
           achievement.id.hasPrefix("medium_") || 
           achievement.id.hasPrefix("hard_") || 
           achievement.id.hasPrefix("expert_") {
            HStack {
                Image(systemName: "gamecontroller.fill")
                Text("Bu başarıyı kazanmak için daha fazla \(achievement.category.rawValue) zorluk seviyesinde Sudoku oynayın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if achievement.id.hasPrefix("streak_") {
            HStack {
                Image(systemName: "calendar")
                Text("Her gün uygulamayı açın ve oynamaya devam edin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if achievement.id.hasPrefix("time_") {
            HStack {
                Image(systemName: "timer")
                Text("Odaklanın ve hızlı çözmeye çalışın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if achievement.id == "no_errors" {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                Text("Hata yapmadan dikkatli bir şekilde oynayın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if achievement.id == "no_hints" {
            HStack {
                Image(systemName: "lightbulb.slash.fill")
                Text("İpucu kullanmadan kendiniz çözün.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if achievement.id == "all_difficulties" {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                Text("Her zorluk seviyesinden en az bir oyun tamamlayın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                Text("Oynamaya devam edin ve bu başarıyı keşfedin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
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
                    Text("Yeni Başarı!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(achievement.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("+\(achievement.rewardPoints) puan")
                        .font(.caption)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
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
        }
    }
}