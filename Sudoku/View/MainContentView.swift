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
    
    var body: some View {
        ZStack {
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
            .onAppear {
                // Başarımları yüklemeyi dene (eğer henüz yüklenmediyse veya güncelleme gerekiyorsa)
                // Bu çağrı artık completion bekliyor, ancak burada sonuçla işimiz yok.
                AchievementManager.shared.loadAchievementsFromFirebase { _ in /* ContentView içinde sonuçla ilgilenmiyoruz */ }
            }
            
            // Başarım bildirimlerini birleştir
            // Her iki sistemin de bildirimleri ekranın üstünden gelsin
            
            // Başarım bildirimlerini GeometryReader içinde ekranın üst kısmında gösterelim
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // AchievementNotificationView - Dynamic Island tarzı
                    if notificationManager.shouldShowNotification {
                        AchievementNotificationView()
                            .frame(width: geometry.size.width)
                            .transition(.move(edge: .top))
                    }
                    
                    // AchievementManager ile gelen bildirimler de üstte görünsün
                    if achievementManager.showAchievementAlert, 
                       let achievement = achievementManager.lastUnlockedAchievement {
                        // Eski AchievementNotification bileşenini üste taşı
                        AchievementNotification(achievement: achievement) {
                            achievementManager.showAchievementAlert = false
                            
                            // Bu bildirim kapatıldığında, aynı başarımı Dynamic Island bildiriminde de göster
                            if !notificationManager.shouldShowNotification && 
                               achievement.id.count > 0 {
                                notificationManager.showAchievementNotification(achievement: achievement)
                            }
                        }
                        .transition(.move(edge: .top))
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
                .edgesIgnoringSafeArea(.top)
            }
            .animation(.spring(), value: notificationManager.shouldShowNotification)
            .animation(.spring(), value: achievementManager.showAchievementAlert)
            .zIndex(100) // En üstte göster
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