//  SudokuApp.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI
import CoreData
import Combine
import Firebase
import FirebaseFirestore

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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var localizationManager = LocalizationManager.shared
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    @AppStorage("highPerformanceMode") private var highPerformanceMode = true
    
    // Uygulamanın arka plana alınma zamanını kaydetmek için
    @AppStorage("lastBackgroundTime") private var lastBackgroundTime: Double = 0
    // Oyunun sıfırlanması için gereken süre (2 dakika = 120 saniye)
    private let gameResetTimeInterval: TimeInterval = 120
    
    // Uygulama yeniden açılırken splash ekranını gösterecek durum
    @State private var showSplashOnResume = false
    
    @Environment(\.colorScheme) var systemColorScheme
    
    // State to track if initialization succeeded
    @State private var initializationError: Error? = nil
    @State private var isInitialized = false
    
    // NOT: Ekran kararması kontrolü artık sadece GameView içinde yapılıyor
    
    private var textSizePreference: TextSizePreference {
        return TextSizePreference(rawValue: textSizeString) ?? .medium
    }
    
    // Managed object context
    private let persistenceController = PersistenceController.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
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
        WindowGroup {
            StartupView(forceShowSplash: showSplashOnResume)
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .preferredColorScheme(themeManager.useSystemAppearance ? nil : themeManager.darkMode ? .dark : .light)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        // Uygulamanın arka plandan dönüş süresini kontrol et
                        let currentTime = Date().timeIntervalSince1970
                        let timeSinceBackground = currentTime - lastBackgroundTime
                        
                        // Eğer belirli bir süreden fazla arka planda kaldıysa splash ekranını göster
                        if lastBackgroundTime > 0 && timeSinceBackground > gameResetTimeInterval {
                            print("🔄 Uygulama \(Int(timeSinceBackground)) saniye sonra geri döndü - Splash ekranı gösterilecek")
                            showSplashOnResume = true
                        } else {
                            showSplashOnResume = false
                        }
                        
                        // Uygulama aktif olduğunda verileri senkronize et
                        PersistenceController.shared.syncSavedGamesFromFirestore { success in
                            if success {
                                print("✅ Oyunlar başarıyla senkronize edildi")
                            } else {
                                print("⚠️ Oyun senkronizasyonunda sorun oluştu")
                            }
                        }
                    case .background:
                        // Arka plana geçiş zamanını kaydet
                        lastBackgroundTime = Date().timeIntervalSince1970
                        print("🔄 Uygulama arka plana alındı: \(Date())")
                        
                        // Arka plana geçerken değişiklikleri kaydet
                        PersistenceController.shared.save()
                    case .inactive:
                        // Uygulama inaktif olduğunda değişiklikleri kaydet
                        PersistenceController.shared.save()
                    @unknown default:
                        break
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

// Kullanıcı değişikliği bildirimlerini ayarla
private func setupUserChangeObservers() {
    // Kullanıcı çıkış yaptığında dinleyici
    NotificationCenter.default.addObserver(forName: Notification.Name("UserLoggedOut"), object: nil, queue: .main) { _ in
        print("👤 Kullanıcı çıkış yaptı")
        
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

// Error view component
struct InitializationErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text.localizedSafe("Uygulama Başlatılamadı")
                .font(.title)
                .fontWeight(.bold)
            
            Text.localizedSafe("Uygulamayı kapatıp tekrar açmayı deneyin.")
                .multilineTextAlignment(.center)
            
            Text("Hata: \(error.localizedDescription)")
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
            
            Button(action: retryAction) {
                Text.localizedSafe("Tekrar Dene")
                    .fontWeight(.semibold)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

// MARK: - Game Screen Observers
private func setupGameScreenObservers() {
    // Oyun ekranı açıldığında ekran kararmasını engelle - sadece Sudoku oyunu için
    NotificationCenter.default.addObserver(
        forName: Notification.Name("GameScreenOpened"),
        object: nil,
        queue: .main
    ) { _ in
        // Sadece Sudoku oyun ekranı için ekran kararmasını engelle
        // Ana iş parçacığında işlemi yap
        DispatchQueue.main.async {
            // Burada başka bir işlem yapmıyoruz, GameView zaten kendi içinde idleTimerDisabled'ı ayarlıyor
            print("🔆 GameScreenOpened bildirim alındı - GameView tarafından ekran kararması engelleniyor")
        }
    }
    
    // Oyun ekranı kapandığında ekran kararmasını tekrar etkinleştir
    NotificationCenter.default.addObserver(
        forName: Notification.Name("GameScreenClosed"),
        object: nil,
        queue: .main
    ) { _ in
        // Ana iş parçacığında ekran kararmasını tekrar etkinleştir
        DispatchQueue.main.async {
            // GameView kapandığında sistem otomatik olarak UIApplication.shared.isIdleTimerDisabled = false yapıyor
            print("🔅 GameScreenClosed bildirim alındı - Ekran kararması GameView tarafından etkinleştirildi")
        }
    }
}
