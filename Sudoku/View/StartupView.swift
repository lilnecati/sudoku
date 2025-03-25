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
 * Bu görünüm, uygulama başlangıcında TabView'un SettingsView yerine
 * Ana Sayfa'dan başlamasını sağlamak için kullanılır.
 *
 * Kısa bir süre sonra otomatik olarak ContentView'a geçer ve
 * TabView'un 0 (Ana Sayfa) sekmesiyle başlamasını sağlar.
 */
struct StartupView: View {
    @State private var isReady = false
    
    var body: some View {
        Group {
            if isReady {
                // Hazır olduğunda ContentView'u göster
                ContentView()
            } else {
                // Hazır olana kadar bu görünümü göster
                ZStack {
                    Color.darkModeBackground(for: .light)
                        .ignoresSafeArea()
                    
                    VStack {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.blue)
                            .padding()
                        
                        Text("Sudoku")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }
                .onAppear {
                    // Kısa bir süre sonra ContentView'a geçiş yap
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // TabView'un Ana Sayfa sekmesinden başlamasını sağlamak için
                        // gecikmeyle isReady'i true yap
                        print("🚀 StartupView uygulamayı ContentView ile başlatıyor...")
                        isReady = true
                    }
                }
            }
        }
    }
}

#Preview {
    StartupView()
}
