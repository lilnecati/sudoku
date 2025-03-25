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
    @State private var rotationAngle: Double = 0
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
        Group {
            if isReady {
                // Hazır olduğunda ContentView'u göster
                ContentView()
            } else {
                // Açılış ekranı
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
                        // Logo
                        ZStack {
                            ForEach(0..<4) { i in
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(gridColors[i % gridColors.count])
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(Double(i) * 90 / 4 + rotationAngle))
                            }
                            
                            Text("9")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
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
                        // Çıkış animasyonu
                        withAnimation(.easeInOut(duration: 0.5)) {
                            logoOpacity = 0
                            textOpacity = 0
                            backgroundOpacity = 0
                            gridOpacity = 0
                        }
                        
                        // Animasyon bittikten sonra ContentView'a geç
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            print("🚀 StartupView uygulamaı ContentView ile başlatıyor...")
                            isReady = true
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
        
        // Logo animasyonu
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Metin animasyonu (logo animasyonundan sonra)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.6)) {
                textOpacity = 1.0
            }
        }
        
        // Logo dönme animasyonu
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Grid animasyonu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showGrid = true
            withAnimation(.easeInOut(duration: 1.0)) {
                gridOpacity = 0.3
            }
        }
        
        // Sayıları göster
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showNumbers = true
        }
    }
    
    // Rastgele sayılar oluştur
    private func generateRandomNumbers() {
        let count = 15 // Sayı adedi
        var newNumbers: [Int] = []
        var newPositions: [CGPoint] = []
        var newColors: [Color] = []
        var newSizes: [CGFloat] = []
        
        // Ekran boyutları
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for _ in 0..<count {
            // 1-9 arası rastgele sayı
            newNumbers.append(Int.random(in: 1...9))
            
            // Rastgele konum - alt kısımdan uzak tut
            let x = CGFloat.random(in: 50...(screenWidth - 50))
            let y = CGFloat.random(in: 100...(screenHeight - 180)) // Alt kısımdan daha uzak tut
            newPositions.append(CGPoint(x: x, y: y))
            
            // Rastgele renk
            newColors.append(gridColors.randomElement() ?? .blue)
            
            // Rastgele boyut
            newSizes.append(CGFloat.random(in: 20...40))
        }
        
        numbers = newNumbers
        numberPositions = newPositions
        numberColors = newColors
        numberSizes = newSizes
    }
}

// Sudoku grid animasyonu
struct SudokuGridAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Yatay çizgiler
            ForEach(0..<10) { i in
                Rectangle()
                    .fill(Color.primary.opacity(i % 3 == 0 ? 0.3 : 0.1))
                    .frame(width: 300, height: i % 3 == 0 ? 2 : 1)
                    .offset(y: CGFloat(i * 30) - 135)
            }
            
            // Dikey çizgiler
            ForEach(0..<10) { i in
                Rectangle()
                    .fill(Color.primary.opacity(i % 3 == 0 ? 0.3 : 0.1))
                    .frame(width: i % 3 == 0 ? 2 : 1, height: 300)
                    .offset(x: CGFloat(i * 30) - 135)
            }
        }
        .rotationEffect(.degrees(isAnimating ? 5 : -5))
        .scaleEffect(isAnimating ? 1.05 : 0.95)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    StartupView()
}
