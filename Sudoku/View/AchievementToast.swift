import SwiftUI
import Foundation

// Ekranın en üstünden aşağıya sarkacak ve daha sonra yukarı doğru kaybolacak bildirim
struct AchievementToastView: View {
    var achievement: Achievement
    @Binding var isVisible: Bool
    
    // Animasyon için durumlar
    @State private var offset: CGFloat = -130
    @State private var opacity: Double = 0
    
    // Sürükleyerek kapatma için
    @GestureState private var dragOffset: CGFloat = 0
    
    // Otomatik kapanma için zamanlayıcı
    let displayDuration: Double = 3.5
    
    var body: some View {
        toastContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: max(-130, offset + dragOffset)) // -130'dan daha yukarı çıkmasını önle
            .opacity(opacity)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: [offset, opacity])
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height < -20 {
                            // Yukarı sürüklenmişse kapat
                            dismissToast()
                        } else if value.translation.height > 20 {
                            // Aşağı sürüklenmişse kapat
                            dismissToast()
                        }
                    }
            )
            .onAppear {
                // Bildirim göründüğünde animasyonu başlat
                showToast()
            }
    }
    
    private var toastContent: some View {
        VStack(spacing: 0) {
            // Bildirimin içeriği
            HStack(spacing: 12) {
                // Başarım ikonu
                Image(systemName: achievement.iconName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4)
                
                // Başarım metinleri
                VStack(alignment: .leading, spacing: 2) {
                    Text("Başarım Kazanıldı!")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(achievement.name)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                
                // Puan bilgisi
                VStack {
                    Text("+\(achievement.pointValue)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    
                    Text("Puan")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 60)
            }
            .padding(16)
            .background(LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.top, 44) // İPhone'un üst çentik alanı için padding
        }
    }
    
    // Toast bildirimini göster
    private func showToast() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            offset = 0 // Bildirimi göster
            opacity = 1
        }
        
        // Otomatik kapanma için zamanlayıcı
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            dismissToast()
        }
    }
    
    // Toast bildirimini kapat
    private func dismissToast() {
        withAnimation(.spring()) {
            offset = -130 // Bildirimi gizle
            opacity = 0
        }
        
        // Animasyon tamamlandıktan sonra bağlı değişkeni güncelle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isVisible = false
        }
    }
}

// Bildirim kuyruğu için ObservableObject
class AchievementToastSystem: ObservableObject {
    static let shared = AchievementToastSystem()
    
    @Published var queue: [Achievement] = []
    @Published var currentAchievement: Achievement? = nil
    @Published var isShowingToast: Bool = false
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        // NotificationCenter üzerinden yeni başarım bildirimlerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewAchievement),
            name: NSNotification.Name("AchievementUnlocked"),
            object: nil
        )
    }
    
    @objc private func handleNewAchievement(_ notification: Notification) {
        guard let achievement = notification.userInfo?["achievement"] as? Achievement else {
            return
        }
        
        DispatchQueue.main.async {
            // Başarımı kuyruğa ekle
            self.queue.append(achievement)
            
            // Eğer şu anda gösterim yoksa, kuyruktaki ilk başarımı göster
            if !self.isShowingToast {
                self.showNextAchievement()
            }
        }
    }
    
    private func showNextAchievement() {
        guard !queue.isEmpty else { return }
        
        // Kuyruğun başındaki başarımı al ve göster
        currentAchievement = queue.removeFirst()
        isShowingToast = true
    }
    
    // Sonraki bildirimin gösterimini tetikle
    func onToastDismissed() {
        // Mevcut bildirimi temizle
        currentAchievement = nil
        isShowingToast = false
        
        // Kuyrukta başka bildirim varsa göster
        if !queue.isEmpty {
            // Kısa bir gecikme sonra göster (kullanıcı deneyimi için)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showNextAchievement()
            }
        }
    }
}

// EnvironmentObject olarak bildirim sistemini erişilebilir yapan ViewModifier
struct AchievementToastSystemModifier: ViewModifier {
    @StateObject private var toastSystem = AchievementToastSystem.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            // Mevcut gösterilen başarım bildirimi
            if let achievement = toastSystem.currentAchievement, toastSystem.isShowingToast {
                AchievementToastView(
                    achievement: achievement,
                    isVisible: Binding(
                        get: { toastSystem.isShowingToast },
                        set: { newValue in
                            if !newValue {
                                toastSystem.onToastDismissed()
                            }
                        }
                    )
                )
                .transition(.opacity)
                .zIndex(999) // En üstte göster
            }
        }
        .environmentObject(toastSystem)
    }
}

// View uzantısı
extension View {
    func achievementToastSystem() -> some View {
        self.modifier(AchievementToastSystemModifier())
    }
}

// Önizleme
struct AchievementToast_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).edgesIgnoringSafeArea(.all)
            
            AchievementToastView(
                achievement: Achievement(
                    id: "first_easy",
                    name: "İlk Kolay Oyun",
                    description: "Bir kolay seviye Sudoku oyununu tamamladınız!",
                    category: .difficulty,
                    iconName: "star.fill",
                    targetValue: 1,
                    pointValue: 50
                ),
                isVisible: .constant(true)
            )
        }
    }
} 