import SwiftUI

// Toast bildirim yöneticisi
struct AchievementNotificationModifier: ViewModifier {
    @ObservedObject var notificationManager = AchievementNotificationManager.shared
    
    func body(content: Content) -> some View {
        // Bildirimin doğru şekilde konumlandırılması
        ZStack {
            // Ana içerik
            content
            
            // Bildirim katmanı - eğer bildirim gösterilmesi gerekiyorsa
            if notificationManager.shouldShowNotification {
                // Bildirimi safeArea'nın üzerinde tutmak için geomtry okuyoruz
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Bildirimi yalnızca en üstte göster
                        Sudoku.AchievementNotificationView()
                            .frame(width: geometry.size.width)
                        
                        Spacer() // Alt kısmı boş bırak
                    }
                    .edgesIgnoringSafeArea(.top) // SafeArea'yı yok say
                }
                .transition(.opacity)
                .zIndex(100) // En üstte göster
            }
        }
    }
}

// View tipi için yeni extension - achievementNotification() adıyla
extension View {
    func achievementNotification() -> some View {
        modifier(AchievementNotificationModifier())
    }
} 