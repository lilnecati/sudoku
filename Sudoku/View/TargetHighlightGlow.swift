import SwiftUI

// Minimal ve profesyonel hedef hücre parlama animasyonu
struct TargetHighlightGlow: View {
    let color: Color
    @State private var isAnimating = false
    @StateObject private var powerManager = PowerSavingManager.shared

    var body: some View {
        Rectangle()
            .strokeBorder(color, lineWidth: 2.5)
            .opacity(isAnimating ? 0.65 : 0.95)
            .animation(
                Animation.easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                if !powerManager.isPowerSavingEnabled {
                    isAnimating = true
                }
            }
            .onChange(of: powerManager.isPowerSavingEnabled) { _, newValue in
                if newValue {
                    isAnimating = false
                } else {
                    isAnimating = true
                }
            }
    }
} 