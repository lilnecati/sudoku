import SwiftUI

struct AchievementNotificationView: View {
    @ObservedObject var notificationManager: AchievementNotificationManager
    @State private var opacity: Double = 0
    @State private var timer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isAppearing: Bool = false
    @Namespace private var animation
    
    init(notificationManager: AchievementNotificationManager = AchievementNotificationManager.shared) {
        self.notificationManager = notificationManager
    }
    
    // Bildirim süresi
    private let notificationDuration: TimeInterval = 15
    
    // Önceden tanımlı geçişler derleyici performansını artırır
    private var customTransition: AnyTransition {
        let insertion = AnyTransition.scale(scale: 0.9)
            .combined(with: .opacity)
            .combined(with: .move(edge: .top))
            .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3))
        
        let removalEdge: Edge = dragOffset > 0 ? .trailing : .leading
        let removal = AnyTransition.scale(scale: 0.9)
            .combined(with: .opacity)
            .combined(with: .move(edge: removalEdge))
            .animation(.easeOut(duration: 0.3))
        
        return .asymmetric(insertion: insertion, removal: removal)
    }
    
    var body: some View {
        Group {
            if notificationManager.shouldShowNotification,
               let achievement = notificationManager.currentAchievement {
                notificationContent(for: achievement)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subviews & Helpers

    @ViewBuilder
    private func notificationContent(for achievement: Achievement) -> some View {
        VStack(spacing: 0) {
            queueIndicator
            cardContent(for: achievement)
        }
        .padding(.top, 10)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    timer?.invalidate()
                    isDragging = true

                    let maxOffset: CGFloat = 100
                    let newOffset = min(max(-maxOffset, gesture.translation.width), maxOffset)

                    withAnimation(.interactiveSpring()) {
                        dragOffset = newOffset
                    }

                    let absOffset = abs(newOffset)
                    if absOffset > 50 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            let newOpacity = max(0.6, 1.0 - Double(absOffset - 50) / 100.0)
                            opacity = newOpacity
                        }
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    let thresholdDistance: CGFloat = 50

                    withAnimation(.spring()) {
                        if dragOffset > thresholdDistance && notificationManager.achievementQueue.count > 0 {
                            skipToNextNotification()
                        } else if dragOffset < -thresholdDistance && notificationManager.achievementQueue.count > 0 {
                            skipToNextNotification()
                        } else {
                            dragOffset = 0
                            resetTimer()
                        }
                    }
                }
        )
        .opacity(opacity)
        .scaleEffect(isAppearing ? 1.0 : 0.95)
        .transition(customTransition)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: opacity)
        .onAppear {
            // Titreşim geri bildirimi
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Ses efekti eklenebilir
            // playAchievementSound()
            
            // Animasyon
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3)
            ) {
                opacity = 1.0
                isAppearing = true
            }
            
            // Konfeti efekti (opsiyonel)
            // showConfetti()
            
            resetTimer()
        }
    }

    @ViewBuilder
    private var queueIndicator: some View {
        if notificationManager.achievementQueue.count > 0 {
            HStack(spacing: 4) {
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
    }

    @ViewBuilder
    private func cardContent(for achievement: Achievement) -> some View {
        HStack(spacing: 12) {
            // İkon ve parıltı efekti
            ZStack {
                // Arka plan daire
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.1)]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                
                // Parıltı efekti
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 50, height: 50)
                    .blur(radius: 0.5)
                
                // İkon
                Image(systemName: achievement.iconName)
                    .foregroundColor(.yellow)
                    .font(.system(size: 30, weight: .bold))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
            .frame(width: 50, height: 50)

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
            ZStack {
                // Arka plan gradyent
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [achievement.colorCode, achievement.colorCode.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Parıltı efekti
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.3), .clear]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                
                // İnce kenarlık
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.6), .white.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: achievement.colorCode.opacity(0.5), radius: 10, x: 0, y: 5)
        )
        .matchedGeometryEffect(id: "achievementCard", in: animation)
        .padding(.horizontal)
    }

    private func resetTimer() {
        // Var olan timer'ı iptal et
        timer?.invalidate()
        
        // Kaydırma işlemi devam ediyorsa timer'ı başlatma
        guard !isDragging else { return }
        
        // Yeni timer oluştur - süreyi artırmak için notificationDuration kullanılıyor
        timer = Timer.scheduledTimer(withTimeInterval: notificationDuration, repeats: false) { _ in
            // Çıkış animasyonu
            withAnimation(.easeInOut(duration: 0.5)) {
                opacity = 0
                isAppearing = false
            }
            
            // Animasyon tamamlandıktan sonra bildirimi kapat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                notificationManager.shouldShowNotification = false
            }
        }
    }
    
    private func skipToNextNotification() {
        // Çıkış animasyonu için hazırlık
        withAnimation(.easeInOut(duration: 0.3)) {
            opacity = 0
            isAppearing = false
        }
        
        // Hafif titreşim geri bildirimi
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
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
            AchievementNotificationView(notificationManager: AchievementNotificationManager.shared)
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
                let manager = AchievementNotificationManager.shared
                manager.showAchievementNotification(achievement: sampleAchievement)
                
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
                
                manager.showAchievementNotification(achievement: sampleAchievement2)
            }
        }
    }
}