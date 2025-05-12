import SwiftUI

// Bu dosyadaki AchievementNotificationBridge sınıf tanımı kaldırıldı.
// Bu modifier artık Utils/AchievementNotificationBridge.swift dosyasındaki
// gerçek singleton örneğini kullanacak.

// Başarım bildirimlerini tüm sayfalarda göstermek için ViewModifier
struct AchievementNotificationViewModifier: ViewModifier {
    // Manager'ı ObservedObject olarak takip etmemiz yeterli olabilir,
    // ancak @StateObject genellikle daha güvenlidir.
    @StateObject private var notificationManager = AchievementNotificationManager.shared
    // ThemeManager'ı ekle
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        ZStack(alignment: .top) { // ZStack hizalamasını üste alalım
            content // Ana içerik

            // Sadece gösterilecek bir bildirim varsa göster
            if notificationManager.shouldShowNotification {
                AchievementNotificationView() // Parametresiz çağrı
                    // ThemeManager'ı environmentObject olarak geçir
                    .environmentObject(themeManager)
                    // .padding(.top, safeAreaInsetsTop()) // Üst güvenli alanı dikkate al
                    // Not: AchievementNotificationView kendi padding'ini yönetebilir.
                    // Gerekirse bu satır eklenebilir veya view içinde düzenlenebilir.
                    .transition(.move(edge: .top).combined(with: .opacity)) // Geçiş efekti
                    .animation(.spring(), value: notificationManager.shouldShowNotification) // Animasyon ekle
                    .zIndex(999) // Diğer içeriklerin üzerinde kalmasını sağla - zIndex değerini artırdım
            }
        }
        // Modifier'ın kendisi alt güvenli alanı dikkate almasına gerek yok,
        // ZStack tüm alanı kaplayacak ve AchievementNotificationView kendi konumunu yönetecek.
    }

    /*
    // Alt güvenli alan boşluğunu almak için yardımcı fonksiyon (Artık gerekli değil)
    private func safeAreaInsetsBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
    */

    /*
    // Üst güvenli alan boşluğunu almak için yardımcı fonksiyon (Gerekirse)
    private func safeAreaInsetsTop() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.top
    }
    */
}

// View uzantısı - kolay kullanım için
extension View {
    func achievementNotifications() -> some View {
        self.modifier(AchievementNotificationViewModifier())
    }
}
