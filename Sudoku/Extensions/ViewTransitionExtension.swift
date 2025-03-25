import SwiftUI

// Sayfa geçiş animasyonları için uzantı
extension AnyTransition {
    static var slideFromRight: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var slideFromLeft: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    
    static var slideFromBottom: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    static var slideFromTop: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static var scale: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .scale(scale: 0.8, anchor: .center).combined(with: .opacity),
            removal: .scale(scale: 1.2, anchor: .center).combined(with: .opacity)
        )
    }
    
    static var flip: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .modifier(
                active: FlipModifier(angle: 90, axis: (x: 0, y: 1)),
                identity: FlipModifier(angle: 0, axis: (x: 0, y: 1))
            ),
            removal: .modifier(
                active: FlipModifier(angle: -90, axis: (x: 0, y: 1)),
                identity: FlipModifier(angle: 0, axis: (x: 0, y: 1))
            )
        )
    }
}

// 3D döndürme efekti için özel modifier
struct FlipModifier: ViewModifier {
    var angle: Double
    var axis: (x: CGFloat, y: CGFloat)
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: axis.x, y: axis.y, z: 0))
    }
}

// Görünüm geçişleri için uzantı
extension View {
    // Görünümü belirtilen süre boyunca animasyonlu olarak göster/gizle
    func fadeInOut(isShowing: Bool, duration: Double = 0.3) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .animation(.easeInOut(duration: duration), value: isShowing)
    }
    
    // Görünümü belirtilen süre boyunca yukarıdan aşağıya doğru kaydırarak göster/gizle
    func slideInFromTop(isShowing: Bool, duration: Double = 0.3, offset: CGFloat = 20) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .offset(y: isShowing ? 0 : -offset)
            .animation(.easeInOut(duration: duration), value: isShowing)
    }
    
    // Görünümü belirtilen süre boyunca aşağıdan yukarıya doğru kaydırarak göster/gizle
    func slideInFromBottom(isShowing: Bool, duration: Double = 0.3, offset: CGFloat = 20) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .offset(y: isShowing ? 0 : offset)
            .animation(.easeInOut(duration: duration), value: isShowing)
    }
    
    // Görünümü belirtilen süre boyunca soldan sağa doğru kaydırarak göster/gizle
    func slideInFromLeft(isShowing: Bool, duration: Double = 0.3, offset: CGFloat = 20) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .offset(x: isShowing ? 0 : -offset)
            .animation(.easeInOut(duration: duration), value: isShowing)
    }
    
    // Görünümü belirtilen süre boyunca sağdan sola doğru kaydırarak göster/gizle
    func slideInFromRight(isShowing: Bool, duration: Double = 0.3, offset: CGFloat = 20) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .offset(x: isShowing ? 0 : offset)
            .animation(.easeInOut(duration: duration), value: isShowing)
    }
    
    // Görünümü belirtilen süre boyunca ölçeklendirerek göster/gizle
    func scaleInOut(isShowing: Bool, duration: Double = 0.3, scale: CGFloat = 0.9) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .scaleEffect(isShowing ? 1 : scale)
            .animation(.spring(response: duration, dampingFraction: 0.6), value: isShowing)
    }
    
    // Görünümü belirtilen süre boyunca döndürerek göster/gizle
    func rotateInOut(isShowing: Bool, duration: Double = 0.3, angle: Double = 10) -> some View {
        self.opacity(isShowing ? 1 : 0)
            .rotationEffect(.degrees(isShowing ? 0 : angle))
            .animation(.easeInOut(duration: duration), value: isShowing)
    }
}
