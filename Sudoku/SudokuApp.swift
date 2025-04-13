//  SudokuApp.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
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

// Tema yönetimi için global sınıf - tema değişikliklerinin anında tüm ekranlara yansıması için
class ThemeManager: ObservableObject {
    @AppStorage("darkMode") var darkMode: Bool = false {
        didSet {
            // Hızlı tema değişimi için doğrudan renk şemasını ayarla
            colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
        }
    }
    @AppStorage("useSystemAppearance") var useSystemAppearance: Bool = false {
        didSet {
            // Hızlı tema değişimi için doğrudan renk şemasını ayarla
            colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
        }
    }
    
    @Published var colorScheme: ColorScheme?
    
    init() {
        // Başlangıç teması ayarla
        colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
    }
    
    // Bu metot artık doğrudan çağrılmayacak
    func updateTheme() {
        colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
    }
    
    func toggleDarkMode() {
        darkMode.toggle()
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
    @StateObject private var themeManager = ThemeManager()
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    @AppStorage("highPerformanceMode") private var highPerformanceMode = false
    
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
        
        // Anonim kullanıcı için kontrol et
        setupAnonymousUserIfNeeded()
    }
    
    // Eğer giriş yapmış kullanıcı yoksa anonim kullanıcı oluştur/getir
    private func setupAnonymousUserIfNeeded() {
        // Hiç giriş yapmış kullanıcı yoksa anonim kullanıcı oluştur
        if PersistenceController.shared.getCurrentUser() == nil {
            // Anonim kullanıcı oluştur veya mevcut olanı getir
            if let anonymousUser = PersistenceController.shared.getOrCreateAnonymousUser() {
                print("👤 Anonim kullanıcı oluşturuldu/alındı: \(anonymousUser.username ?? "N/A")")
            }
        }
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
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .environment(\.textScale, textSizePreference.scaleFactor)
                        .environment(\.dynamicTypeSize, textSizePreference.toDynamicTypeSize())
                        .onAppear {
                            if !isInitialized {
                                isInitialized = true
                                print("✅ Content view appeared successfully")
                                
                                // Güç tasarrufu durumunu kontrol et
                                let powerManager = PowerSavingManager.shared
                                print("🔋 Power saving mode: \(powerManager.isPowerSavingEnabled ? "ON" : "OFF")")
                                
                                // StartupView ile başlangıç sorununu çözdük
                            }
                            
                            // Metin boyutu değişim bildirimini dinle
                            NotificationCenter.default.addObserver(forName: Notification.Name("TextSizeChanged"), object: nil, queue: .main) { notification in
                                print("📱 Text size changed to: \(self.textSizePreference.rawValue)")
                                
                                // UI'ı yenile
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
                                }
                            }
                            
                            // Kullanıcı giriş/çıkış bildirimlerini dinle
                            setupUserChangeObservers()
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
    
    // Kullanıcı değişikliği bildirimlerini ayarla
    private func setupUserChangeObservers() {
        // Kullanıcı çıkış yaptığında dinleyici
        NotificationCenter.default.addObserver(forName: Notification.Name("UserLoggedOut"), object: nil, queue: .main) { _ in
            print("👤 Kullanıcı çıkış yaptı")
            
            // Kullanıcı çıkışında mevcut kullanıcıyı kontrol et
            // PersistenceController içinde anonim kullanıcı otomatik olarak yönetildiği için
            // burada tekrar anonim kullanıcı oluşturmaya gerek yok
            
            // Görüntüleri yenile
            NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        }
        
        // Kullanıcı giriş yaptığında dinleyici
        NotificationCenter.default.addObserver(forName: Notification.Name("UserLoggedIn"), object: nil, queue: .main) { _ in
            if let user = PersistenceController.shared.getCurrentUser() {
                print("👤 Kullanıcı giriş yaptı: \(user.username ?? "N/A")")
                
                // Görüntüleri yenile
                NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
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
