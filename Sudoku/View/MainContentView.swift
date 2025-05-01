import SwiftUI

// Tab seçenekleri için enum
enum Tab {
    case dashboard
    case settings
    case stats
}

struct MainContentView: View {
    @State private var selectedTab: Tab = .dashboard
    
    // AchievementManager'ı izle
    @ObservedObject private var achievementManager = AchievementManager.shared
    @ObservedObject private var notificationManager = AchievementNotificationManager.shared
    
    // Bildirim animasyonları için namespace
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .top) {
            // Tab view - ana içerik
            TabView(selection: $selectedTab) {
                // Ana ekran (dashboard) - MainMenuView ile değiştirildi
                MainMenuView()
                    .tabItem {
                        Label("Ana Sayfa", systemImage: "house")
                    }
                    .tag(Tab.dashboard)
                
                // Ayarlar
                SettingsView()
                    .tabItem {
                        Label("Ayarlar", systemImage: "gear")
                    }
                    .tag(Tab.settings)
                
                // İstatistikler - DetailedStatisticsView ile değiştirildi
                DetailedStatisticsView()
                    .tabItem {
                        Label("İstatistikler", systemImage: "chart.bar")
                    }
                    .tag(Tab.stats)
            }
            .accentColor(.blue)
            
            // Bildirimler için optimize edilmiş overlay
            VStack(spacing: 0) {
                // AchievementNotificationView - Dynamic Island tarzı
                if notificationManager.shouldShowNotification {
                    AchievementNotificationView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(101)
                }
                
                // AchievementManager ile gelen bildirimler
                if achievementManager.showAchievementAlert, 
                   let achievement = achievementManager.lastUnlockedAchievement {
                    AchievementNotification(achievement: achievement) {
                        achievementManager.showAchievementAlert = false
                        
                        // Bu bildirim kapatıldığında, aynı başarımı Dynamic Island bildiriminde de göster
                        if !notificationManager.shouldShowNotification && 
                           achievement.id.count > 0 {
                            notificationManager.showAchievementNotification(achievement: achievement)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 10)
                    .zIndex(100)
                }
                
                Spacer()
            }
            .animation(.spring(response: 0.4), value: notificationManager.shouldShowNotification)
            .animation(.spring(response: 0.4), value: achievementManager.showAchievementAlert)
        }
        .onAppear {
            // Başarımları yüklemeyi dene (eğer henüz yüklenmediyse veya güncelleme gerekiyorsa)
            AchievementManager.shared.loadAchievementsFromFirebase { _ in /* ContentView içinde sonuçla ilgilenmiyoruz */ }
        }
        // AchievementManager'dan yeni başarımlar kazanıldığında Dynamic Island bildirimini tetikle
        .onChange(of: achievementManager.lastUnlockedAchievement) { _, newAchievement in
            if achievementManager.showAchievementAlert,
               let achievement = newAchievement,
               achievement.id.count > 0 {
                // Bildirim görüntülendikten sonra veriyi Dynamic Island bildirimlerine aktar
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    notificationManager.showAchievementNotification(achievement: achievement)
                }
            }
        }
    }
} 