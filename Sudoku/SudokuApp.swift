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
import FirebaseAuth

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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
    
    // Aktif oyun ekranı açık mı?
    @State private var isGameViewActive = false
    
    private var textSizePreference: TextSizePreference {
        return TextSizePreference(rawValue: textSizeString) ?? .medium
    }
    
    // Managed object context
    private let persistenceController = PersistenceController.shared
    private let viewContext: NSManagedObjectContext
    
    init() {
        logInfo("Sudoku app initializing...")
        #if DEBUG
        logDebug("Debug mode active")
        #endif
        
        // Initialize view context
        viewContext = persistenceController.container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Ekran kararması yönetimi GameView'e bırakıldı.
        // setupGameScreenObservers() // Ekran kararması yönetimi GameView'e devredildi
        
        // Firestore'u başlat
        FirebaseApp.configure()
        
        // PowerSavingManager'ı başlat
        _ = PowerSavingManager.shared
        logInfo("Power Saving Manager initialized")
        
        // Başarım bildirimi köprüsünü başlat
        _ = AchievementNotificationBridge.shared
        logInfo("Achievement Notification Bridge initialized")
    }
    
    // MARK: - Firebase Token Validation
    private func validateFirebaseToken() {
        if let currentUser = Auth.auth().currentUser {
            logInfo("Firebase token doğrulaması yapılıyor...")
            currentUser.getIDTokenResult(forcingRefresh: true) { tokenResult, error in
                if let error = error {
                    logError("Token doğrulama hatası: \(error.localizedDescription)")
                    // Token doğrulama hatası - kullanıcı hesabı silinmiş veya token geçersiz olabilir
                    // Kullanıcıyı otomatik olarak çıkış yaptır
                    do {
                        try Auth.auth().signOut()
                        logWarning("Geçersiz token nedeniyle kullanıcı çıkış yaptırıldı")
                        // Kullanıcı çıkış bildirimi gönder
                        NotificationCenter.default.post(name: Notification.Name("UserLoggedOut"), object: nil)
                    } catch let signOutError {
                        logError("Çıkış yapma hatası: \(signOutError.localizedDescription)")
                    }
                } else {
                    logSuccess("Firebase token doğrulaması başarılı")
                }
            }
        }
    }

    // MARK: - Game Screen Observers
    // Bu fonksiyon artık kullanılmıyor ve kaldırıldı.

    var body: some Scene {
        WindowGroup {
            StartupView(forceShowSplash: showSplashOnResume)
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .environment(\.managedObjectContext, viewContext)
                .environment(\.textScale, textSizePreference.scaleFactor)
                .preferredColorScheme(themeManager.useSystemAppearance ? nil : themeManager.darkMode ? .dark : .light)
                .accentColor(ColorManager.primaryBlue)
                .achievementToastSystem()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        // Firebase token doğrulaması yap
                        validateFirebaseToken()
                        
                        // Uygulama arka plandan ön plana geldiğinde
                        let currentTime = Date().timeIntervalSince1970
                        let timeSinceBackground = currentTime - lastBackgroundTime
                        
                        if timeSinceBackground > gameResetTimeInterval && lastBackgroundTime > 0 {
                            // Uygulama uzun süre arka planda kaldıysa splash göster
                            showSplashOnResume = true
                            logInfo("Uygulama \(Int(timeSinceBackground)) saniye arka planda kaldı, splash gösterilecek")
                        } else {
                            showSplashOnResume = false
                        }
                        
                        // Oyun verilerini senkronize et
                        if Auth.auth().currentUser != nil {
                            // Kullanıcı giriş yapmışsa, Firestore'dan verileri çek
                            PersistenceController.shared.syncSavedGamesFromFirestore { success in
                                if success {
                                    logInfo("Oyun verileri başarıyla senkronize edildi")
                                } else {
                                    logWarning("Oyun senkronizasyonunda sorun oluştu")
                                }
                            }
                        }
                    case .background:
                        // Arka plana geçiş zamanını kaydet
                        lastBackgroundTime = Date().timeIntervalSince1970
                        logInfo("Uygulama arka plana alındı: \(Date())")
                        
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
        // Firebase konfigürasyonu
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            logSuccess("Firebase yapılandırması başarıyla tamamlandı")
        } else {
            logWarning("Firebase zaten yapılandırılmış")
        }
        
        // Diğer ayarlar
        
        return true
    }
}

// Kullanıcı değişikliği bildirimlerini ayarla
private func setupUserChangeObservers() {
    // Kullanıcı çıkış yaptığında dinleyici
    NotificationCenter.default.addObserver(forName: Notification.Name("UserLoggedOut"), object: nil, queue: .main) { _ in
        logInfo("Kullanıcı çıkış yaptı")
        
        // Görüntüleri yenile
        NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
    }
    
    // Kullanıcı giriş yaptığında dinleyici
    NotificationCenter.default.addObserver(forName: Notification.Name("UserLoggedIn"), object: nil, queue: .main) { _ in
        if let user = PersistenceController.shared.getCurrentUser() {
            logInfo("Kullanıcı giriş yaptı: \(user.username ?? "N/A")")
            
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
