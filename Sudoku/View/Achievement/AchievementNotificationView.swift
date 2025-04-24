import SwiftUI

struct AchievementNotificationView: View {
    @ObservedObject var notificationManager = AchievementNotificationManager.shared
    @State private var opacity: Double = 0
    @State private var timer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    // Bildirim süresi
    private let notificationDuration: TimeInterval = 10
    
    var body: some View {
        Group {
            if notificationManager.shouldShowNotification, let achievement = notificationManager.currentAchievement {
                VStack(spacing: 0) {
                    // Bildirim gösterge çubuğu - kuyrukta eleman varsa
                    if notificationManager.achievementQueue.count > 0 {
                        HStack(spacing: 4) {
                            // Mevcut bildirim göstergesi ve kuyruk sayısı
                            Text("\(notificationManager.achievementQueue.count + 1) bildirim")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.3))
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                    }
                    
                    HStack(spacing: 12) {
                        // Başarım kategorisine özel simge göster
                        Image(systemName: achievement.iconName)
                            .foregroundColor(.yellow)
                            .font(.system(size: 30))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yeni Başarım!")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(achievement.title)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text(achievement.description)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                            
                            // Başarım puanını göster
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12))
                                
                                Text("+\(achievement.pointValue) puan")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                            .padding(.top, 2)
                        }
                        
                        Spacer()
                        
                        // Kaydırma ipucu
                        if notificationManager.achievementQueue.count > 0 {
                            VStack(spacing: 2) {
                                Image(systemName: "chevron.compact.down")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 14))
                                Text("Kaydır")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.trailing, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(achievement.colorCode))
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 10)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            // Timer'ı durdur, kaydırma işlemi başladı
                            timer?.invalidate()
                            isDragging = true
                            
                            // Kaydırma hareketini sınırla
                            let maxOffset: CGFloat = 100
                            dragOffset = min(max(-maxOffset, gesture.translation.width), maxOffset)
                        }
                        .onEnded { gesture in
                            isDragging = false
                            
                            // Kaydırma bittiğinde kontrol et
                            let thresholdDistance: CGFloat = 50
                            
                            withAnimation(.spring()) {
                                if dragOffset > thresholdDistance && notificationManager.achievementQueue.count > 0 {
                                    // Sağa kaydırdı - bir sonraki bildirimi göster
                                    skipToNextNotification()
                                } else if dragOffset < -thresholdDistance && notificationManager.achievementQueue.count > 0 {
                                    // Sola kaydırdı - bir sonraki bildirimi göster
                                    skipToNextNotification()
                                } else {
                                    // Yeterli kaydırma yoksa resetle
                                    dragOffset = 0
                                    
                                    // Kaydırma bittiyse zamanlayıcıyı yeniden başlat
                                    resetTimer()
                                }
                            }
                        }
                )
                .opacity(opacity)
                .transition(.move(edge: .top))
                .animation(.spring(), value: opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 1.0
                    }
                    
                    // Bildirim süresi başlat
                    resetTimer()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func resetTimer() {
        // Var olan timer'ı iptal et
        timer?.invalidate()
        
        // Kaydırma işlemi devam ediyorsa timer'ı başlatma
        guard !isDragging else { return }
        
        // Yeni timer oluştur - süreyi artırmak için notificationDuration kullanılıyor
        timer = Timer.scheduledTimer(withTimeInterval: notificationDuration, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                opacity = 0
            }
            
            // Animasyon tamamlandıktan sonra bildirimi kapat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                notificationManager.shouldShowNotification = false
            }
        }
    }
    
    private func skipToNextNotification() {
        // Şu anki bildirimi kapat, sonraki gösterilecek
        withAnimation(.easeInOut(duration: 0.3)) {
            opacity = 0
        }
        
        // Animasyon tamamlandıktan sonra bir sonraki bildirimi göster
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            notificationManager.shouldShowNotification = false
        }
    }
}

struct AchievementNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3).edgesIgnoringSafeArea(.all)
            AchievementNotificationView()
        }
        .onAppear {
            let sampleAchievement = Achievement(
                id: "sample",
                name: "Meraklı Çaylak",
                description: "İlk kez kolay seviyede bir oyunu tamamladın!",
                category: .difficulty,
                iconName: "star.fill",
                targetValue: 1,
                pointValue: 50
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                AchievementNotificationManager.shared.showAchievementNotification(achievement: sampleAchievement)
                
                // Önizleme için birden fazla bildirim ekle
                let sampleAchievement2 = Achievement(
                    id: "sample2",
                    name: "Hızlı Çözücü",
                    description: "Bir Sudoku puzzleını 5 dakikadan kısa sürede çözdün!",
                    category: .time,
                    iconName: "clock.fill",
                    targetValue: 1,
                    pointValue: 50
                )
                
                AchievementNotificationManager.shared.showAchievementNotification(achievement: sampleAchievement2)
            }
        }
    }
} 