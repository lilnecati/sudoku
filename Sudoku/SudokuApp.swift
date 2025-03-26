//
//  SudokuApp.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.03.2025.
//

import SwiftUI
import CoreData
import Combine

// Metin ölçeği için EnvironmentKey
struct TextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

// Environment değerlerine ekleme
extension EnvironmentValues {
    var textScale: CGFloat {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

// Metin boyutu tercihi için enum
enum TextSizePreference: String, CaseIterable {
    case small = "Küçük"
    case medium = "Orta"
    case large = "Büyük"
    
    var displayName: String {
        return self.rawValue
    }
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        }
    }
}

// Ana renkleri yöneten yapı
struct ColorManager {
    // Ana renkler
    static let primaryBlue = Color("PrimaryBlue", bundle: nil) 
    static let primaryGreen = Color("PrimaryGreen", bundle: nil)
    static let primaryOrange = Color("PrimaryOrange", bundle: nil)
    static let primaryPurple = Color("PrimaryPurple", bundle: nil)
    static let primaryRed = Color("PrimaryRed", bundle: nil)
    
    // Arka plan renkleri
    static let backgroundLight = Color(red: 0.97, green: 0.97, blue: 0.99)
    static let backgroundDark = Color(red: 0.1, green: 0.1, blue: 0.15)
    
    // Vurgu renkleri
    static let highlightLight = primaryBlue.opacity(0.15)
    static let highlightDark = primaryBlue.opacity(0.3)
    
    // Hata renkleri
    static let errorColor = primaryRed
    static let warningColor = primaryOrange
    static let successColor = primaryGreen
    
    // Arka plan deseni renkleri
    struct backgroundColors {
        static let backgroundPatternLight = Color.blue.opacity(0.07)
        static let backgroundPatternDark = Color.white.opacity(0.07)
    }
}

@main
struct SudokuApp: App {
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("useSystemAppearance") private var useSystemAppearance: Bool = false
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    
    // Uygulamanın arka plana alınma zamanını kaydetmek için
    @AppStorage("lastBackgroundTime") private var lastBackgroundTime: Double = 0
    // Oyunun sıfırlanması için gereken süre (2 dakika = 120 saniye)
    private let gameResetTimeInterval: TimeInterval = 120
    
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.scenePhase) var scenePhase
    
    // State to track if initialization succeeded
    @State private var initializationError: Error? = nil
    @State private var isInitialized = false
    
    private var textSizePreference: TextSizePreference {
        return TextSizePreference(rawValue: textSizeString) ?? .medium
    }
    
    // Managed object context
    private let persistenceController = PersistenceController.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        print("📱 Sudoku app initializing...")
        #if DEBUG
        print("📊 Debug mode active")
        #endif
        
        // Initialize view context
        viewContext = persistenceController.container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // PowerSavingManager'ı başlat
        _ = PowerSavingManager.shared
        print("🔋 Power Saving Manager initialized")
    }
    
    var body: some Scene {
        // iOS'un uygulamayı kapatmasından sonra bile sekme durumunu restore etmesini engelle
        WindowGroup {
            // State restore özelliğini Window Group seviyesinde kontrol ediyoruz
            ZStack {
                if let error = initializationError {
                    InitializationErrorView(error: error) {
                        initializationError = nil
                        isInitialized = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isInitialized = true
                        }
                    }
                } else {
                    // Özel StartupView ile ContentView'u sarmalayarak, her açılışta ana sayfadan başlamayı garanti ediyoruz
                    StartupView()
                        .environment(\.managedObjectContext, viewContext)
                        .preferredColorScheme(useSystemAppearance ? nil : (darkMode ? .dark : .light))
                        .environment(\.textScale, textSizePreference.scaleFactor)
                        .onAppear {
                            if !isInitialized {
                                isInitialized = true
                                print("✅ Content view appeared successfully")
                                
                                // Güç tasarrufu durumunu kontrol et
                                let powerManager = PowerSavingManager.shared
                                print("🔋 Power saving mode: \(powerManager.isPowerSavingEnabled ? "ON" : "OFF")")
                                
                                // StartupView ile başlangıç sorununu çözdük
                            }
                        }
                }
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .background {
                // Uygulama arka plana geçtiğinde aktif oyunu otomatik olarak duraklat
                NotificationCenter.default.post(name: Notification.Name("PauseActiveGame"), object: nil)
                print("📱 App moved to background - pausing active game")
                
                // Arka plana geçme zamanını kaydet
                lastBackgroundTime = Date().timeIntervalSince1970
                print("⏰ Background time saved: \(lastBackgroundTime)")
                
                // CoreData bağlamını kaydet
                do {
                    try viewContext.save()
                    print("✅ Context saved successfully")
                } catch {
                    print("❌ Failed to save context: \(error)")
                }
            } else if newValue == .active {
                // Uygulama tekrar aktif olduğunda, ne kadar süre arka planda kaldığını kontrol et
                let currentTime = Date().timeIntervalSince1970
                let timeInBackground = currentTime - lastBackgroundTime
                
                if timeInBackground > gameResetTimeInterval {
                    // 2 dakikadan fazla arka planda kaldıysa, oyunu sıfırla
                    print("⏰ App was in background for \(Int(timeInBackground)) seconds - resetting game")
                    NotificationCenter.default.post(name: Notification.Name("ResetGameAfterTimeout"), object: nil)
                } else {
                    // Normal aktif olma bildirimi
                    print("📱 App became active after \(Int(timeInBackground)) seconds")
                    
                    // Bildirim göndermeden önce kısa bir gecikme ekle
                    // Bu, birden fazla bildirim gönderilmesini önleyecek
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: Notification.Name("AppBecameActive"), object: nil)
                    }
                }
            }
        }
    }
}

// Error view component
struct InitializationErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Uygulama Başlatılamadı")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Uygulamayı kapatıp tekrar açmayı deneyin.")
                .multilineTextAlignment(.center)
            
            Text("Hata: \(error.localizedDescription)")
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
            
            Button(action: retryAction) {
                Text("Tekrar Dene")
                    .fontWeight(.semibold)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}
