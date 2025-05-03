//  BackgroundView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 15.11.2024.
//

import SwiftUI

struct GridBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        ZStack {
            // Arka plan rengi - colorScheme'e göre değişir
            baseBackground
            
            // Izgara deseni - colorScheme'e göre değişir
            gridPattern
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    // Temel arka plan - colorScheme'e göre değişir
    private var baseBackground: some View {
        Group {
            if isBejMode {
                // Bej mod arka plan
                ThemeManager.BejThemeColors.background
                    .edgesIgnoringSafeArea(.all)
                
                // Hafif bej gradient efekti
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            ThemeManager.BejThemeColors.secondaryBackground.opacity(0.7),
                            ThemeManager.BejThemeColors.background.opacity(0.9),
                            ThemeManager.BejThemeColors.background
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
            }
            else if colorScheme == .dark {
                // Koyu arka plan (karanlık tema için)
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                // Hafif arka plan gradient efekti
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            Color.purple.opacity(0.2),
                            Color.blue.opacity(0.1),
                            Color.black.opacity(0.95)
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // Açık arka plan (açık tema için)
                Color.white
                    .edgesIgnoringSafeArea(.all)
                
                // Hafif açık arka plan gradient efekti
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.purple.opacity(0.02),
                            Color.white.opacity(0.95)
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    // Izgara desenini oluşturan görünüm - colorScheme'e göre değişir
    private var gridPattern: some View {
        Canvas { context, size in
            if isBejMode {
                drawBejModeGrid(context: context, size: size)
            }
            else if colorScheme == .dark {
                drawDarkModeGrid(context: context, size: size)
            } else {
                drawLightModeGrid(context: context, size: size)
            }
        }
        .drawingGroup() // Metal hızlandırması için
        .blur(radius: isBejMode ? 0.3 : (colorScheme == .dark ? 0.5 : 0)) // Glow efekti için - Canvas dışında uygulayabiliriz
        .blendMode(isBejMode ? .multiply : (colorScheme == .dark ? .screen : .multiply)) // Karışım modu tema rengiyle uyumlu
    }
    
    // Bej mod ızgara çizgileri
    private func drawBejModeGrid(context: GraphicsContext, size: CGSize) {
        // Izgara çizgilerinin rengi - bej uyumlu
        let primaryGridColor = ThemeManager.BejThemeColors.accent.opacity(0.15)
        let secondaryGridColor = ThemeManager.BejThemeColors.text.opacity(0.08)
        
        // Izgara hücre boyutu - büyük ızgara
        let cellSize: CGFloat = 60
        
        // Izgara çizgisi kalınlığı
        let lineWidth: CGFloat = 0.7
        
        // Yatay ve dikey çizgi sayısı
        let horizontalLineCount = Int(size.height / cellSize) + 1
        let verticalLineCount = Int(size.width / cellSize) + 1
        
        // Izgara çizgilerini çiz (dikey çizgiler)
        context.stroke(
            Path { path in
                for i in 0...verticalLineCount {
                    let x = CGFloat(i) * cellSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            },
            with: .color(primaryGridColor),
            lineWidth: lineWidth
        )
        
        // Izgara çizgilerini çiz (yatay çizgiler)
        context.stroke(
            Path { path in
                for i in 0...horizontalLineCount {
                    let y = CGFloat(i) * cellSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            },
            with: .color(secondaryGridColor),
            lineWidth: lineWidth
        )
        
        // İkincil daha küçük ızgara
        let smallCellSize: CGFloat = 20
        let smallLineWidth: CGFloat = 0.3
        
        // Küçük ızgara çizgilerini çiz (dikey)
        context.stroke(
            Path { path in
                for i in 0...Int(size.width / smallCellSize) {
                    // Ana ızgara çizgilerini atla
                    if i % 3 != 0 {
                        let x = CGFloat(i) * smallCellSize
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
            },
            with: .color(primaryGridColor.opacity(0.5)),
            lineWidth: smallLineWidth
        )
        
        // Küçük ızgara çizgilerini çiz (yatay)
        context.stroke(
            Path { path in
                for i in 0...Int(size.height / smallCellSize) {
                    // Ana ızgara çizgilerini atla
                    if i % 3 != 0 {
                        let y = CGFloat(i) * smallCellSize
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
            },
            with: .color(secondaryGridColor.opacity(0.5)),
            lineWidth: smallLineWidth
        )
        
        // Dekoratif desenler ekle - bej mod için küçük noktalar
        let dotSize: CGFloat = 2
        let dotSpacing: CGFloat = 40
        
        for x in stride(from: dotSpacing/2, to: size.width, by: dotSpacing) {
            for y in stride(from: dotSpacing/2, to: size.height, by: dotSpacing) {
                // Rastgele opaklık ile nokta çiz (daha doğal görünüm için)
                let opacity = Double.random(in: 0.1...0.25)
                
                // Desenin kesişim noktalarına nokta ekle
                let dotRect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(ThemeManager.BejThemeColors.accent.opacity(opacity))
                )
            }
        }
        
        // Dekoratif büyük halkalar - bej mod için vurgu
        let circleCount = 5
        let maxRadius: CGFloat = 100
        
        for _ in 0..<circleCount {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let radius = CGFloat.random(in: 40...maxRadius)
            
            context.stroke(
                Path(ellipseIn: CGRect(x: x - radius/2, y: y - radius/2, width: radius, height: radius)),
                with: .color(ThemeManager.BejThemeColors.accent.opacity(0.05)),
                lineWidth: 1.5
            )
        }
    }
    
    // Karanlık mod ızgara çizgileri
    private func drawDarkModeGrid(context: GraphicsContext, size: CGSize) {
        // Izgara çizgilerinin rengi - neon mor/mavi efekti için
        let primaryGridColor = Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.4)
        let secondaryGridColor = Color(red: 0.2, green: 0.3, blue: 0.8).opacity(0.3)
        
        // Izgara hücre boyutu - büyük ızgara
        let cellSize: CGFloat = 60
        
        // Izgara çizgisi kalınlığı
        let lineWidth: CGFloat = 0.7
        
        // Yatay ve dikey çizgi sayısı
        let horizontalLineCount = Int(size.height / cellSize) + 1
        let verticalLineCount = Int(size.width / cellSize) + 1
        
        // Izgara çizgilerini çiz (dikey çizgiler)
        context.stroke(
            Path { path in
                for i in 0...verticalLineCount {
                    let x = CGFloat(i) * cellSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            },
            with: .color(primaryGridColor),
            lineWidth: lineWidth
        )
        
        // Izgara çizgilerini çiz (yatay çizgiler)
        context.stroke(
            Path { path in
                for i in 0...horizontalLineCount {
                    let y = CGFloat(i) * cellSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            },
            with: .color(secondaryGridColor),
            lineWidth: lineWidth
        )
        
        // İkincil daha küçük ızgara
        let smallCellSize: CGFloat = 20
        let smallLineWidth: CGFloat = 0.3
        
        // Küçük ızgara çizgilerini çiz (dikey)
        context.stroke(
            Path { path in
                for i in 0...Int(size.width / smallCellSize) {
                    // Ana ızgara çizgilerini atla
                    if i % 3 != 0 {
                        let x = CGFloat(i) * smallCellSize
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
            },
            with: .color(primaryGridColor.opacity(0.15)),
            lineWidth: smallLineWidth
        )
        
        // Küçük ızgara çizgilerini çiz (yatay)
        context.stroke(
            Path { path in
                for i in 0...Int(size.height / smallCellSize) {
                    // Ana ızgara çizgilerini atla
                    if i % 3 != 0 {
                        let y = CGFloat(i) * smallCellSize
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
            },
            with: .color(secondaryGridColor.opacity(0.15)),
            lineWidth: smallLineWidth
        )
    }
    
    // Açık mod ızgara çizgileri
    private func drawLightModeGrid(context: GraphicsContext, size: CGSize) {
        // Izgara çizgilerinin rengi - açık tema için pastel mavi ton
        let primaryGridColor = Color(red: 0.7, green: 0.8, blue: 0.9).opacity(0.5)
        let secondaryGridColor = Color(red: 0.8, green: 0.9, blue: 1.0).opacity(0.5)
        
        // Izgara hücre boyutu - büyük ızgara
        let cellSize: CGFloat = 60
        
        // Izgara çizgisi kalınlığı
        let lineWidth: CGFloat = 0.7
        
        // Yatay ve dikey çizgi sayısı
        let horizontalLineCount = Int(size.height / cellSize) + 1
        let verticalLineCount = Int(size.width / cellSize) + 1
        
        // Izgara çizgilerini çiz (dikey çizgiler)
        context.stroke(
            Path { path in
                for i in 0...verticalLineCount {
                    let x = CGFloat(i) * cellSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            },
            with: .color(primaryGridColor),
            lineWidth: lineWidth
        )
        
        // Izgara çizgilerini çiz (yatay çizgiler)
        context.stroke(
            Path { path in
                for i in 0...horizontalLineCount {
                    let y = CGFloat(i) * cellSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            },
            with: .color(secondaryGridColor),
            lineWidth: lineWidth
        )
        
        // İkincil daha küçük ızgara
        let smallCellSize: CGFloat = 20
        let smallLineWidth: CGFloat = 0.3
        
        // Küçük ızgara çizgilerini çiz (dikey)
        context.stroke(
            Path { path in
                for i in 0...Int(size.width / smallCellSize) {
                    // Ana ızgara çizgilerini atla
                    if i % 3 != 0 {
                        let x = CGFloat(i) * smallCellSize
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
            },
            with: .color(primaryGridColor.opacity(0.4)),
            lineWidth: smallLineWidth
        )
        
        // Küçük ızgara çizgilerini çiz (yatay)
        context.stroke(
            Path { path in
                for i in 0...Int(size.height / smallCellSize) {
                    // Ana ızgara çizgilerini atla
                    if i % 3 != 0 {
                        let y = CGFloat(i) * smallCellSize
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
            },
            with: .color(secondaryGridColor.opacity(0.4)),
            lineWidth: smallLineWidth
        )
    }
}

// Kullanımı kolay olması için ViewModifier
struct GridBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            GridBackgroundView()
            content
        }
    }
}

// View uzantısı - kullanımı kolaylaştırır
extension View {
    func withGridBackground() -> some View {
        self.modifier(GridBackgroundModifier())
    }
}

#Preview {
    VStack {
        Text("Izgara Arka Plan Örneği")
            .foregroundColor(.white)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(8)
    }
    .withGridBackground()
} 