//
//  StartupView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 24.03.2025.
//

import SwiftUI

/**
 * StartupView
 * 
 * Modern ve etkileyici bir açılış ekranı (splash screen) görünümü.
 * 3-5 saniye arasında rastgele bir süre gösterilir ve güzel animasyonlar içerir.
 * Kullanıcı deneyimini iyileştirmek için tasarlanmıştır.
 */
struct StartupView: View {
    // Ana görünüme geçiş için durum
    @State private var isReady = false
    
    // Animasyon durumları
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var showGrid = false
    @State private var gridOpacity: Double = 0
    @State private var rotationDegrees: Double = 0
    @State private var showNumbers = false
    
    // Rastgele sayılar için
    @State private var numbers: [Int] = []
    @State private var numberPositions: [CGPoint] = []
    @State private var numberColors: [Color] = []
    @State private var numberSizes: [CGFloat] = []
    
    // Rastgele görünme süresi (3-5 saniye arası)
    private let displayDuration: Double = Double.random(in: 3.0...5.0)
    
    // Sudoku grid renkleri
    private let gridColors = [
        ColorManager.primaryBlue,
        ColorManager.primaryGreen,
        ColorManager.primaryPurple,
        ColorManager.primaryOrange
    ]
    
    var body: some View {
        ZStack {
            // Ana uygulama her zaman yüklü ve hazır olacak (arka planda)
            ContentView()
                .localizationAware()
                .opacity(isReady ? 1 : 0)
                .animation(.easeIn(duration: 0.3), value: isReady)
            
            // Açılış ekranı (isReady olana kadar görünür)
            if !isReady {
                ZStack {
                    // Arkaplan gradyant
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor.systemBackground),
                            Color(UIColor.systemBackground).opacity(0.8),
                            gridColors[0].opacity(0.1),
                            gridColors[1].opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)
                    
                    // Sudoku grid animasyonu
                    if showGrid {
                        SudokuGridAnimation()
                            .opacity(gridOpacity)
                    }
                    
                    // Uçuşan sayılar
                    if showNumbers {
                        ForEach(0..<numbers.count, id: \.self) { index in
                            Text("\(numbers[index])")
                                .font(.system(size: numberSizes[index], weight: .semibold, design: .rounded))
                                .foregroundColor(numberColors[index])
                                .position(numberPositions[index])
                                .opacity(0.7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // Logo ve başlık - Ekranın ortasında
                    VStack(spacing: 20) {
                        Spacer()
                        // Logo - AnimatedSudokuLogo kullanıyoruz
                        AnimatedSudokuLogo(isStartupScreen: true, continuousRotation: true)
                            .frame(width: 120, height: 120)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                        
                        // Uygulama adı
                        Text("SUDOKU")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .tracking(5)
                            .opacity(textOpacity)
                        
                        // Alt başlık
                        Text("Zihninizi Çalıştırın")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.top, -5)
                            .opacity(textOpacity * 0.8)
                        
                        Spacer()
                        
                        // Geliştirici bilgisi - Arka plan ile korumalı
                        HStack(spacing: 8) {
                            // Geliştirici simgesi
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [gridColors[2], gridColors[0]]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 36, height: 36)
                                
                                Text("N")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            // Geliştirici adı
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Geliştirici")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("Necati Yıldırım")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground).opacity(0.9))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        .padding(.bottom, 20)
                        .opacity(textOpacity * 0.9)
                        .zIndex(10) // Uçuşan sayıların altında kalmasını önlemek için
                        
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                }
                .onAppear {
                    // Animasyon başlat
                    startAnimations()
                    
                    // Rastgele sayılar oluştur
                    generateRandomNumbers()
                    
                    // Belirtilen süre sonra ContentView'a geç
                    print("🚀 StartupView \(displayDuration) saniye sonra ContentView'a geçecek...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                        // ÖNCE ContentView'u hazırla (arka planda)
                        print("🚀 StartupView uygulamayı başlatıyor...")
                        isReady = true
                        
                        // SONRA kapanış animasyonunu uygula
                        withAnimation(.easeInOut(duration: 0.3)) {
                            logoOpacity = 0
                            textOpacity = 0
                            backgroundOpacity = 0
                            gridOpacity = 0
                        }
                    }
                }
            }
        }
    }
    
    // Animasyonları başlat
    private func startAnimations() {
        // Arkaplanı göster
        withAnimation(.easeOut(duration: 1.0)) {
            backgroundOpacity = 1.0
        }
        
        // Grid animasyonunu başlat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showGrid = true
            withAnimation(.easeOut(duration: 1.0)) {
                gridOpacity = 0.5
            }
        }
        
        // Logo animasyonu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.0)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
        
        // Metin animasyonu
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 1.0)) {
                textOpacity = 1.0
            }
        }
        
        // Sayılar animasyonu
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            showNumbers = true
        }
    }
    
    // Rastgele sayılar oluştur
    private func generateRandomNumbers() {
        // Ekran boyutları
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // 15 rastgele sayı oluştur
        for _ in 0..<15 {
            numbers.append(Int.random(in: 1...9))
            
            // Rastgele pozisyon
            let x = CGFloat.random(in: 20...(screenWidth - 20))
            let y = CGFloat.random(in: 20...(screenHeight - 20))
            numberPositions.append(CGPoint(x: x, y: y))
            
            // Rastgele renk
            let randomColor = gridColors[Int.random(in: 0..<gridColors.count)]
            numberColors.append(randomColor.opacity(Double.random(in: 0.5...0.9)))
            
            // Rastgele boyut
            numberSizes.append(CGFloat.random(in: 14...32))
        }
    }
}

// Sudoku grid animasyonu
struct SudokuGridAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Arka plan grid
            GridPattern(rows: 9, columns: 9, lineWidth: 1)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                .background(Color.clear)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .opacity(isAnimating ? 0.3 : 0.5)
            
            // Ön plan grid
            GridPattern(rows: 3, columns: 3, lineWidth: 2)
                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                .background(Color.clear)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .opacity(isAnimating ? 0.5 : 0.3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// Grid deseni
struct GridPattern: Shape {
    let rows: Int
    let columns: Int
    let lineWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Yatay çizgiler
        let rowHeight = rect.height / CGFloat(rows)
        for i in 0...rows {
            let y = rowHeight * CGFloat(i)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        // Dikey çizgiler
        let columnWidth = rect.width / CGFloat(columns)
        for i in 0...columns {
            let x = columnWidth * CGFloat(i)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        return path
    }
}
