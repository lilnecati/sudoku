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
    // Singleton örnek
    static let shared = ThemeManager()
    
    @AppStorage("darkMode") var darkMode: Bool = false {
        didSet {
            // Sadece değer değiştiyse güncelle (gereksiz güncellemeleri önle)
            if oldValue != darkMode {
            // Hızlı tema değişimi için doğrudan renk şemasını ayarla
            colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
                
                // Bej mod ve koyu mod aynı anda açık olamaz
                if darkMode && bejMode {
                    bejMode = false
                }
                
                // Tema değişikliği bildirimi gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("ThemeChanged"), 
                    object: nil, 
                    userInfo: ["isDarkMode": darkMode]
                )
                
                // Log mesajı
                logInfo("Tema değiştirildi: \(oldValue ? "Koyu" : "Açık") -> \(darkMode ? "Koyu" : "Açık")")
            }
        }
    }
    
    @AppStorage("useSystemAppearance") var useSystemAppearance: Bool = false {
        didSet {
            // Sadece değer değiştiyse güncelle (gereksiz güncellemeleri önle)
            if oldValue != useSystemAppearance {
            // Hızlı tema değişimi için doğrudan renk şemasını ayarla
            colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
                
                // Bej mod ve sistem görünümü aynı anda açık olamaz
                if useSystemAppearance && bejMode {
                    bejMode = false
                }
                
                // Tema değişikliği bildirimi gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("ThemeChanged"), 
                    object: nil, 
                    userInfo: ["useSystemAppearance": useSystemAppearance]
                )
                
                // Log mesajı
                logInfo("Sistem teması kullanımı değiştirildi: \(oldValue) -> \(useSystemAppearance)")
            }
        }
    }
    
    // Bej mod özelliği
    @AppStorage("bejMode") var bejMode: Bool = false {
        didSet {
            // Sadece değer değiştiyse güncelle
            if oldValue != bejMode {
                // Bej mod açıldığında diğer modları kapat
                if bejMode {
                    if darkMode {
                        darkMode = false
                    }
                    if useSystemAppearance {
                        useSystemAppearance = false
                    }
                }
                
                // Doğrudan colorScheme güncellemesi
                colorScheme = bejMode ? .light : (useSystemAppearance ? nil : (darkMode ? .dark : .light))
                
                // Tema değişikliği bildirimini gönder
                self.notifyThemeChanged()
                
                // Navigation bar görünümünü güncelle
                self.updateNavigationBarAppearance()
                
                // Log
                logInfo("Bej mod değişti: \(bejMode)")
            }
        }
    }
    
    // Tema değişikliği bildirimini gönder
    private func notifyThemeChanged() {
        // ThemeChanged bildirimi gönder
        NotificationCenter.default.post(name: NSNotification.Name("ThemeChanged"), object: nil)
        
        logInfo("Tema değişikliği bildirimi gönderildi")
    }
    
    // Sudoku tahtası renk tercihi için yeni özellik
    @AppStorage("sudokuBoardColor") var sudokuBoardColor: String = "blue" {
        didSet {
            if oldValue != sudokuBoardColor {
                // Renk değiştiğinde bildirimi yayınla
                objectWillChange.send()
                
                // Hızlı güncelleme için bildirim gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("BoardColorChanged"), 
                    object: nil, 
                    userInfo: ["oldColor": oldValue, "newColor": sudokuBoardColor]
                )
                
                // Ayrıca genel tema değişikliği bildirimi
                NotificationCenter.default.post(name: NSNotification.Name("ThemeChanged"), object: nil)
                
                logInfo("Tahta rengi değiştirildi: \(oldValue) -> \(sudokuBoardColor)")
            }
        }
    }
    
    @Published var colorScheme: ColorScheme?
    
    // YENİ - Yüksek kontrast mod için özellik ekleyelim
    @AppStorage("highContrastMode") var highContrastMode: Bool = false {
        didSet {
            // Sadece değer değiştiyse güncelle (gereksiz güncellemeleri önle)
            if oldValue != highContrastMode {
                // Bildirim gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("ThemeChanged"), 
                    object: nil, 
                    userInfo: ["highContrastMode": highContrastMode]
                )
                
                // Log mesajı
                logInfo("Yüksek kontrast modu değiştirildi: \(oldValue) -> \(highContrastMode)")
            }
        }
    }
    
    // Bej mod için renk sabitleri
    struct BejThemeColors {
        static let background = Color(red: 0.95, green: 0.92, blue: 0.85) // Ana arka plan rengi (#F2EAD9)
        static let secondaryBackground = Color(red: 0.92, green: 0.88, blue: 0.82) // İkincil arka plan (#EADFD1)
        static let text = Color(red: 0.25, green: 0.20, blue: 0.15) // Ana metin rengi (#403326)
        static let secondaryText = Color(red: 0.4, green: 0.35, blue: 0.3) // İkincil metin rengi (#665A4D)
        static let accent = Color(red: 0.6, green: 0.4, blue: 0.2) // Vurgu rengi (#996633)
        static let cardBackground = Color(red: 0.97, green: 0.95, blue: 0.91) // Kart arka planı (#F7F2E8)
        static let gridLines = Color(red: 0.4, green: 0.35, blue: 0.3).opacity(0.5) // Izgara çizgileri
        
        // Tahta renk seçenekleri için özel renkler
        struct boardColors {
            static let blue = Color(red: 0.30, green: 0.40, blue: 0.60)   // Bej uyumlu mavi
            static let red = Color(red: 0.75, green: 0.30, blue: 0.20)    // Bej uyumlu kırmızı
            static let pink = Color(red: 0.80, green: 0.40, blue: 0.50)   // Bej uyumlu pembe
            static let orange = Color(red: 0.85, green: 0.50, blue: 0.20) // Bej uyumlu turuncu
            static let purple = Color(red: 0.60, green: 0.35, blue: 0.60) // Bej uyumlu mor
            static let green = Color(red: 0.40, green: 0.55, blue: 0.30)  // Bej uyumlu yeşil
        }
    }
    
    init() {
        // Başlangıç teması ayarla
        colorScheme = bejMode ? .light : (useSystemAppearance ? nil : (darkMode ? .dark : .light))
        
        // Başlangıçta NavigationBar görünümünü ayarla
        updateNavigationBarAppearance()
    }
    
    // Bu metot artık doğrudan çağrılmayacak
    func updateTheme() {
        colorScheme = bejMode ? .light : (useSystemAppearance ? nil : (darkMode ? .dark : .light))
    }
    
    // Tema değişikliklerini tek bir yerden yönetmek için toplu güncelleme fonksiyonu
    func updateAppTheme(darkMode: Bool? = nil, useSystemAppearance: Bool? = nil, bejMode: Bool? = nil, highContrastMode: Bool? = nil) {
        // Değişiklik olup olmadığını kontrol etmek için
        var themeChanged = false
        
        // Bej mod için kontrol ekle
        if let newBejMode = bejMode {
            // Sadece değer değişiyorsa güncelle
            if self.bejMode != newBejMode {
                // Bej mod açılıyorsa diğer modları kapat
                if newBejMode {
                    if self.darkMode {
                        self.darkMode = false
                    }
                    if self.useSystemAppearance {
                        self.useSystemAppearance = false
                    }
                }
                
                self.bejMode = newBejMode
                themeChanged = true
            }
        }
        
        // Güncellenmesi gereken parametreleri kontrol et
        if let newDarkMode = darkMode {
            // Sadece değer değişiyorsa güncelle
            if self.darkMode != newDarkMode {
                // Koyu mod açılıyorsa bej modu kapat
                if newDarkMode && self.bejMode {
                    self.bejMode = false
                }
                
                self.darkMode = newDarkMode
                themeChanged = true
            }
        }
        
        if let newUseSystemAppearance = useSystemAppearance {
            // Sadece değer değişiyorsa güncelle
            if self.useSystemAppearance != newUseSystemAppearance {
                // Sistem görünümü açılıyorsa bej modu kapat
                if newUseSystemAppearance && self.bejMode {
                    self.bejMode = false
                }
                
                self.useSystemAppearance = newUseSystemAppearance
                themeChanged = true
            }
        }
        
        // YENİ - Yüksek kontrast modu ekleyelim
        if let newHighContrastMode = highContrastMode, self.highContrastMode != newHighContrastMode {
            self.highContrastMode = newHighContrastMode
            themeChanged = true
        }
        
        // Eğer bir değişiklik olduysa ve bildirim gönderilmediyse
        if themeChanged {
            // colorScheme zaten didSet bloklarında güncellendi, burada tekrar güncellemiyoruz
            
            // Değişiklikleri herkese bildir
            objectWillChange.send()
            
            // Tema değişikliği bildirimi gönder
            NotificationCenter.default.post(
                name: NSNotification.Name("ThemeChanged"), 
                object: nil,
                userInfo: ["bulkUpdate": true]
            )
            
            // Navigation Bar görünümünü güncelle
            updateNavigationBarAppearance()
            
            // Log mesajı
            logInfo("Toplu tema güncellemesi yapıldı")
        }
    }
    
    // Tema değiştirme kısayol fonksiyonu - Koyu mod / Açık mod geçişi
    func toggleTheme() {
        if useSystemAppearance {
            // Önce sistem temasını kapat, ardından koyu mod değerini değiştir
            updateAppTheme(useSystemAppearance: false)
            // Kısa bir gecikme ile koyu mod değerini tersine çevir
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateAppTheme(darkMode: !self.darkMode)
            }
        } else if bejMode {
            // Bej moddan çıkıp açık moda geç
            updateAppTheme(bejMode: false)
        } else {
            // Koyu mod değerini değiştir
            updateAppTheme(darkMode: !darkMode)
        }
    }
    
    // Metrik/Log için tema durumunu döndür
    func getCurrentThemeDescription() -> String {
        if bejMode {
            return "Bej Tema"
        } else if useSystemAppearance {
            return "Sistem (Otomatik)" + (highContrastMode ? " + Yüksek Kontrast" : "")
        } else {
            return darkMode ? "Koyu Tema" : "Açık Tema" + (highContrastMode ? " + Yüksek Kontrast" : "")
        }
    }
    
    // Tahta rengini almak için yardımcı fonksiyon
    func getBoardColor() -> Color {
        // Bej mod için özel renkler
        if bejMode {
            switch sudokuBoardColor {
            case "red":
                return BejThemeColors.boardColors.red
            case "pink":
                return BejThemeColors.boardColors.pink
            case "orange":
                return BejThemeColors.boardColors.orange
            case "purple":
                return BejThemeColors.boardColors.purple
            case "green":
                return BejThemeColors.boardColors.green
            default: // blue
                return BejThemeColors.boardColors.blue
            }
        } else {
            // Normal mod
            switch sudokuBoardColor {
            case "red":
                return Color.red
            case "pink":
                return Color.pink
            case "orange":
                return Color.orange
            case "purple":
                return Color.purple
            case "green":
                return Color.green
            default: // blue
                return Color.blue
            }
        }
    }
    
    // Renk adını döndüren yardımcı fonksiyon
    func getBoardColorName() -> String {
        switch sudokuBoardColor {
        case "red":
            return "Kırmızı"
        case "pink":
            return "Pembe"
        case "orange":
            return "Turuncu"
        case "purple":
            return "Mor"
        case "green":
            return "Yeşil"
        default:
            return "Mavi"
        }
    }
    
    // Arka plan rengini almak için yardımcı fonksiyon
    func getBackgroundColor() -> Color {
        if bejMode {
            return BejThemeColors.background
        } else {
            return darkMode ? Color(red: 0.1, green: 0.1, blue: 0.15) : Color(red: 0.97, green: 0.97, blue: 0.99)
        }
    }
    
    // Kart arka plan rengini almak için yardımcı fonksiyon
    func getCardBackgroundColor() -> Color {
        if bejMode {
            return BejThemeColors.cardBackground
        } else {
            return darkMode ? Color(.systemGray6) : Color.white
        }
    }
    
    // Metin rengini almak için yardımcı fonksiyon
    func getTextColor(isSecondary: Bool = false) -> Color {
        if bejMode {
            return isSecondary ? BejThemeColors.secondaryText : BejThemeColors.text
        } else {
            return isSecondary ? .secondary : .primary
        }
    }
    
    // Navigation Bar görünümünü tema değişikliklerine göre günceller
    func updateNavigationBarAppearance() {
        DispatchQueue.main.async {
            // Bej mod için özel görünüm ayarları
            let bejAppearance = UINavigationBarAppearance()
            bejAppearance.configureWithOpaqueBackground()
            bejAppearance.backgroundColor = UIColor(BejThemeColors.background)
            bejAppearance.titleTextAttributes = [.foregroundColor: UIColor(BejThemeColors.text)]
            bejAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(BejThemeColors.text)]
            
            // Standart açık/koyu mod için görünüm ayarları
            let standardAppearance = UINavigationBarAppearance()
            standardAppearance.configureWithDefaultBackground()
            
            // Bej mod aktifse, bej görünümü kullan, değilse standart görünümü kullan
            let currentAppearance = self.bejMode ? bejAppearance : standardAppearance
            
            // NavigationBar için global görünüm ayarları
            UINavigationBar.appearance().standardAppearance = currentAppearance
            UINavigationBar.appearance().compactAppearance = currentAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = currentAppearance
            
            // Bej mod aktifse, accent rengini ayarla
            if self.bejMode {
                UINavigationBar.appearance().tintColor = UIColor(BejThemeColors.accent)
            } else {
                // Sistem varsayılanına dön
                UINavigationBar.appearance().tintColor = nil
            }
            
            // TabBar görünümünü de güncelle
            self.updateTabBarAppearance()
            
            // UINavigationController'ların doğrudan güncellenmesi için
            self.updateAllActiveNavigationControllers()
            
            logInfo("NavigationBar görünümü güncellendi: \(self.bejMode ? "Bej Mod" : "Standart Mod")")
        }
    }
    
    // TabBar görünümünü tema değişikliklerine göre günceller
    private func updateTabBarAppearance() {
        // Bej mod için özel görünüm ayarları
        let bejAppearance = UITabBarAppearance()
        bejAppearance.configureWithOpaqueBackground()
        bejAppearance.backgroundColor = UIColor(BejThemeColors.background)
        
        // Standart görünüm
        let standardAppearance = UITabBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        
        // Bej mod aktifse, bej görünümü kullan, değilse standart görünümü kullan
        let appearance = self.bejMode ? bejAppearance : standardAppearance
        
        // TabBar için global görünüm ayarları
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Bej mod aktifse, renklerini ayarla
        if self.bejMode {
            UITabBar.appearance().tintColor = UIColor(BejThemeColors.accent)
            UITabBar.appearance().unselectedItemTintColor = UIColor(BejThemeColors.secondaryText)
        } else {
            // Sistem varsayılanına dön
            UITabBar.appearance().tintColor = nil
            UITabBar.appearance().unselectedItemTintColor = nil
        }
        
        logInfo("TabBar görünümü güncellendi: \(self.bejMode ? "Bej Mod" : "Standart Mod")")
    }
    
    // Tüm aktif navigation controller'ları bulan ve güncelleyen yardımcı metod
    private func updateAllActiveNavigationControllers() {
        if #available(iOS 15.0, *) {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { window in
                    if let rootVC = window.rootViewController {
                        self.updateNavigationControllersRecursively(in: rootVC)
                    }
                }
        } else {
            // iOS 15 öncesi için eski yöntem
            UIApplication.shared.windows.forEach { window in
                if let rootVC = window.rootViewController {
                    self.updateNavigationControllersRecursively(in: rootVC)
                }
            }
        }
    }
    
    // Recursive olarak tüm navigation controller'ları bulan ve güncelleyen fonksiyon
    private func updateNavigationControllersRecursively(in viewController: UIViewController) {
        // Eğer bu VC bir navigation controller ise görünümünü güncelle
        if let navController = viewController as? UINavigationController {
            self.applyNavigationBarAppearance(to: navController)
            
            // Alt view controller'ları için de kontrol et
            navController.viewControllers.forEach { self.updateNavigationControllersRecursively(in: $0) }
        }
        
        // Gösterilen (presented) view controller varsa o da kontrol edilir
        if let presentedVC = viewController.presentedViewController {
            self.updateNavigationControllersRecursively(in: presentedVC)
        }
        
        // Tab bar controller için tüm tab'leri kontrol et
        if let tabController = viewController as? UITabBarController {
            tabController.viewControllers?.forEach { self.updateNavigationControllersRecursively(in: $0) }
        }
        
        // Split view controller için view controller'ları kontrol et
        if let splitController = viewController as? UISplitViewController {
            splitController.viewControllers.forEach { self.updateNavigationControllersRecursively(in: $0) }
        }
        
        // Çocuk view controller'lar varsa onları da kontrol et
        viewController.children.forEach { self.updateNavigationControllersRecursively(in: $0) }
    }
    
    // Navigation controller'ın görünümünü doğrudan güncelle
    private func applyNavigationBarAppearance(to navController: UINavigationController) {
        // Bej mod için görünüm
        let bejAppearance = UINavigationBarAppearance()
        bejAppearance.configureWithOpaqueBackground()
        bejAppearance.backgroundColor = UIColor(BejThemeColors.background)
        bejAppearance.titleTextAttributes = [.foregroundColor: UIColor(BejThemeColors.text)]
        bejAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(BejThemeColors.text)]
        
        // Standart görünüm
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        
        // Duruma göre görünümü seç
        let appearance = self.bejMode ? bejAppearance : standardAppearance
        
        // Navigation bar görünümünü uygula
        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        
        // Tint color ayarla
        navController.navigationBar.tintColor = self.bejMode ? UIColor(BejThemeColors.accent) : nil
        
        // Görünümün hemen güncellenmesini sağla
        navController.navigationBar.layoutIfNeeded()
        
        // Değişiklikleri uygula
        navController.setNeedsStatusBarAppearanceUpdate()
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
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    @AppStorage("highPerformanceMode") private var highPerformanceMode = true
    
    // Uygulamanın arka plana alınma zamanını kaydetmek için
    @AppStorage("lastBackgroundTime") private var lastBackgroundTime: Double = 0
    // Oyunun sıfırlanması için gereken süre (2 dakika = 120 saniye)
    private let gameResetTimeInterval: TimeInterval = 120
    
    // Uygulama yeniden açılırken splash ekranını gösterecek durum
    @State private var showSplashOnResume = false
    @State private var startupViewId = 0
    
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
        // UIScrollView ve klavye davranışı için global ayarlar
        UIScrollView.appearance().keyboardDismissMode = .onDrag
        
        // Log seviyesini ayarla (açık bir şekilde)
        #if DEBUG
        LogManager.shared.setLogLevel(.debug)
        #else
        LogManager.shared.setLogLevel(.warning)  // Sadece warning ve error logları göster
        #endif
        
        logInfo("Sudoku app initializing...")
        
        // Initialize view context
        viewContext = persistenceController.container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Ekran kararması ayarını uygulama açılırken aktifleştir (sadece GameView'de kapatılacak)
        UIApplication.shared.isIdleTimerDisabled = false
        logInfo("🔅 SudokuApp init - Ekran kararması ayarı: AÇIK")
        
        // Firestore'u başlat
        FirebaseApp.configure()
        
        // PowerSavingManager'ı başlat
        _ = PowerSavingManager.shared
        logInfo("Power Saving Manager initialized")
        
        // Başarım bildirimi köprüsünü başlat
        _ = AchievementNotificationBridge.shared
        logInfo("Achievement Notification Bridge initialized")

        // *** YENİ: Ağ izleyiciyi başlat ***
        NetworkMonitor.shared.startMonitoring()
        logInfo("Network Monitor initialized and started")
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
                .id(startupViewId)
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .environment(\.managedObjectContext, viewContext)
                .environment(\.textScale, textSizePreference.scaleFactor)
                .preferredColorScheme(themeManager.useSystemAppearance ? nil : themeManager.darkMode ? .dark : .light)
                .animation(.easeInOut(duration: 0.3), value: themeManager.darkMode)
                .animation(.easeInOut(duration: 0.3), value: themeManager.useSystemAppearance)
                .accentColor(ColorManager.primaryBlue)
                // .achievementToastSystem()  // Toast bildirimleri kapatıldı
                .withAchievementNotifications()  // Yeni bildirim sistemini kullan
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    logInfo("Scene phase changed from \(oldPhase) to \(newPhase)")
                    switch newPhase {
                    case .active:
                        logInfo("Scene became active")
                        // Firebase token doğrulaması yap
                        validateFirebaseToken()
                        
                        // Uygulama arka plandan ön plana geldiğinde
                        let currentTime = Date().timeIntervalSince1970
                        let timeSinceBackground = currentTime - lastBackgroundTime
                        logInfo("Current time: \(currentTime), Last background time: \(lastBackgroundTime), Time since background: \(timeSinceBackground)")
                        
                        if timeSinceBackground > gameResetTimeInterval && lastBackgroundTime > 0 {
                            // Uygulama uzun süre arka planda kaldıysa splash göster
                            showSplashOnResume = true
                            startupViewId += 1
                            logInfo("Uygulama \(Int(timeSinceBackground)) saniye arka planda kaldı, splash gösterilecek. Setting showSplashOnResume = true, startupViewId = \(startupViewId)")
                        } else {
                            showSplashOnResume = false
                            if lastBackgroundTime > 0 {
                                logInfo("Uygulama \(Int(timeSinceBackground)) saniye arka planda kaldı, splash GÖSTERİLMEYECEK (limit: \(Int(gameResetTimeInterval)) sn). Setting showSplashOnResume = false")
                            } else {
                                logInfo("İlk açılış veya lastBackgroundTime sıfır, splash gösterilmeyecek. Setting showSplashOnResume = false")
                            }
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
                        logInfo("Uygulama arka plana alındı: \(Date()). Setting lastBackgroundTime = \(lastBackgroundTime)")
                        
                        // Arka plana geçerken değişiklikleri kaydet
                        PersistenceController.shared.save()
                    case .inactive:
                        logInfo("Scene became inactive")
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
    // ThemeChanged için gözleyici
    private var themeObserver: NSObjectProtocol?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase konfigürasyonu
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            logSuccess("Firebase yapılandırması başarıyla tamamlandı")
        } else {
            logWarning("Firebase zaten yapılandırılmış")
        }
        
        // Bej mod için NavigationBar görünümünü yapılandır
        configureNavigationBarAppearance()
        
        // Tema değişikliği dinleyicisi ekle
        setupThemeObserver()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Gözleyiciyi temizle
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // Tema değişikliği dinleyicisi ekle
    private func setupThemeObserver() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ThemeChanged"),
            object: nil,
            queue: .main) { [weak self] _ in
                logInfo("AppDelegate: ThemeChanged bildirimi alındı")
                self?.configureNavigationBarAppearance()
                self?.configureTabBarAppearance()
                self?.updateNavigationBarsInCurrentScenes()
                self?.forceRefreshUI()
            }
        
        logInfo("AppDelegate: ThemeChanged dinleyicisi kuruldu")
    }
    
    // Navigation bar görünümünü yapılandıran fonksiyon
    private func configureNavigationBarAppearance() {
        // Bej mod için özel görünüm ayarları
        let bejAppearance = UINavigationBarAppearance()
        bejAppearance.configureWithOpaqueBackground()
        bejAppearance.backgroundColor = UIColor(ThemeManager.BejThemeColors.background)
        bejAppearance.titleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.text)]
        bejAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.text)]
        
        // Standart açık/koyu mod için görünüm ayarları
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        
        // ThemeManager singleton'ını kullan
        let themeManager = ThemeManager.shared
        
        // Bej mod aktifse, bej görünümü kullan, değilse standart görünümü kullan
        let currentAppearance = themeManager.bejMode ? bejAppearance : standardAppearance
        
        // NavigationBar için global görünüm ayarları
        UINavigationBar.appearance().standardAppearance = currentAppearance
        UINavigationBar.appearance().compactAppearance = currentAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = currentAppearance
        
        // Bej mod aktifse, accent rengini ayarla
        if themeManager.bejMode {
            UINavigationBar.appearance().tintColor = UIColor(ThemeManager.BejThemeColors.accent)
        } else {
            // Sistem varsayılanına dön
            UINavigationBar.appearance().tintColor = nil
        }
        
        // Görünümü hemen güncellemek için tüm mevcut navigation controller'ları güncelle
        DispatchQueue.main.async {
            self.updateNavigationBarsInCurrentScenes()
            
            // ForceRefreshUI bildirimi gönder
            NotificationCenter.default.post(name: NSNotification.Name("ForceRefreshUI"), object: nil)
        }
        
        logInfo("NavigationBar görünümü yapılandırıldı: \(themeManager.bejMode ? "Bej Mod" : "Standart Mod")")
    }
    
    // TabBar görünümünü yapılandıran fonksiyon
    private func configureTabBarAppearance() {
        // ThemeManager singleton'ını kullan
        let themeManager = ThemeManager.shared
        
        // Bej mod için özel görünüm ayarları
        let bejAppearance = UITabBarAppearance()
        bejAppearance.configureWithOpaqueBackground()
        bejAppearance.backgroundColor = UIColor(ThemeManager.BejThemeColors.background)
        
        // Standart görünüm
        let standardAppearance = UITabBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        
        // Bej mod aktifse, bej görünümü kullan, değilse standart görünümü kullan
        let appearance = themeManager.bejMode ? bejAppearance : standardAppearance
        
        // TabBar için global görünüm ayarları
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Bej mod aktifse, renklerini ayarla
        if themeManager.bejMode {
            UITabBar.appearance().tintColor = UIColor(ThemeManager.BejThemeColors.accent)
            UITabBar.appearance().unselectedItemTintColor = UIColor(ThemeManager.BejThemeColors.secondaryText)
        } else {
            // Sistem varsayılanına dön
            UITabBar.appearance().tintColor = nil
            UITabBar.appearance().unselectedItemTintColor = nil
        }
        
        // Tab bar'lar için görünümü zorla güncelle
        updateTabBarsInCurrentScenes()
        
        logInfo("TabBar görünümü yapılandırıldı: \(themeManager.bejMode ? "Bej Mod" : "Standart Mod")")
    }
    
    // Tüm tab bar'ları bulup güncelleyen yardımcı fonksiyon
    private func updateTabBarsInCurrentScenes() {
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                
                for window in windowScene.windows {
                    updateTabBarsRecursively(in: window.rootViewController)
                }
            }
        } else {
            // iOS 15 öncesi için eski yöntem
            for window in UIApplication.shared.windows {
                updateTabBarsRecursively(in: window.rootViewController)
            }
        }
    }
    
    // Recursive olarak tab bar'ları bul ve güncelle
    private func updateTabBarsRecursively(in viewController: UIViewController?) {
        guard let viewController = viewController else { return }
        
        // Eğer bu bir tab bar controller ise, görünümü güncelle
        if let tabBarController = viewController as? UITabBarController {
            updateTabBarController(tabBarController)
        }
        
        // Presented controller varsa onu da kontrol et
        if let presented = viewController.presentedViewController {
            updateTabBarsRecursively(in: presented)
        }
        
        // Sayfa container ise, içindeki tüm sayfaları kontrol et
        if let tabController = viewController as? UITabBarController {
            tabController.viewControllers?.forEach { updateTabBarsRecursively(in: $0) }
        }
        
        // Navigation controller ise içindeki view controller'ları kontrol et
        if let navController = viewController as? UINavigationController {
            navController.viewControllers.forEach { updateTabBarsRecursively(in: $0) }
        }
        
        // Split view controller ise içindeki view controller'ları kontrol et
        if let splitController = viewController as? UISplitViewController {
            splitController.viewControllers.forEach { updateTabBarsRecursively(in: $0) }
        }
        
        // Çocuk view controller'ları kontrol et
        viewController.children.forEach { updateTabBarsRecursively(in: $0) }
    }
    
    // Tab bar controller için doğrudan güncelleme yap
    private func updateTabBarController(_ tabBarController: UITabBarController) {
        let themeManager = ThemeManager.shared
        
        // Bej mod için özel görünüm ayarları
        let bejAppearance = UITabBarAppearance()
        bejAppearance.configureWithOpaqueBackground()
        bejAppearance.backgroundColor = UIColor(ThemeManager.BejThemeColors.background)
        
        // Standart görünüm
        let standardAppearance = UITabBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        
        // Bej mod aktifse, bej görünümü kullan, değilse standart görünümü kullan
        if themeManager.bejMode {
            tabBarController.tabBar.standardAppearance = bejAppearance
            if #available(iOS 15.0, *) {
                tabBarController.tabBar.scrollEdgeAppearance = bejAppearance
            }
            tabBarController.tabBar.tintColor = UIColor(ThemeManager.BejThemeColors.accent)
            tabBarController.tabBar.unselectedItemTintColor = UIColor(ThemeManager.BejThemeColors.secondaryText)
        } else {
            tabBarController.tabBar.standardAppearance = standardAppearance
            if #available(iOS 15.0, *) {
                tabBarController.tabBar.scrollEdgeAppearance = standardAppearance
            }
            tabBarController.tabBar.tintColor = nil
            tabBarController.tabBar.unselectedItemTintColor = nil
        }
        
        // Görünümün zorla güncellenmesini sağla
        tabBarController.tabBar.setNeedsLayout()
        tabBarController.tabBar.layoutIfNeeded()
    }
    
    // Tüm UI'ı zorla yenileme işlemi
    private func forceRefreshUI() {
        DispatchQueue.main.async {
            if #available(iOS 15.0, *) {
                for scene in UIApplication.shared.connectedScenes {
                    guard let windowScene = scene as? UIWindowScene else { continue }
                    for window in windowScene.windows {
                        window.setNeedsLayout()
                        window.layoutIfNeeded()
                        
                        if let rootVC = window.rootViewController {
                            rootVC.beginAppearanceTransition(false, animated: false)
                            rootVC.endAppearanceTransition()
                            rootVC.beginAppearanceTransition(true, animated: false)
                            rootVC.endAppearanceTransition()
                            
                            // Navigation controller ise doğrudan güncelle
                            if let navVC = rootVC as? UINavigationController {
                                navVC.navigationBar.setNeedsLayout()
                                navVC.navigationBar.layoutIfNeeded()
                            }
                        }
                    }
                }
            } else {
                // iOS 15 öncesi için eski yöntem
                for window in UIApplication.shared.windows {
                    window.setNeedsLayout()
                    window.layoutIfNeeded()
                    
                    if let rootVC = window.rootViewController {
                        rootVC.beginAppearanceTransition(false, animated: false)
                        rootVC.endAppearanceTransition()
                        rootVC.beginAppearanceTransition(true, animated: false)
                        rootVC.endAppearanceTransition()
                        
                        // Navigation controller ise doğrudan güncelle
                        if let navVC = rootVC as? UINavigationController {
                            navVC.navigationBar.setNeedsLayout()
                            navVC.navigationBar.layoutIfNeeded()
                        }
                    }
                }
            }
            
            // SwiftUI tarafı için notification gönder
            NotificationCenter.default.post(name: NSNotification.Name("ForceRefreshUI"), object: nil)
            
            logInfo("Tüm UI zorla yenilendi")
        }
    }
    
    // Mevcut pencerelerdeki tüm navigation controller'ları günceller
    private func updateNavigationBarsInCurrentScenes() {
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        findAndUpdateNavigationControllers(in: window.rootViewController)
                    }
                }
            }
        } else {
            // iOS 15 öncesi için eski yöntem
            for window in UIApplication.shared.windows {
                findAndUpdateNavigationControllers(in: window.rootViewController)
            }
        }
    }
    
    // Recursive olarak navigation controller'ları bulan ve güncelleyen fonksiyon
    private func findAndUpdateNavigationControllers(in viewController: UIViewController?) {
        guard let viewController = viewController else { return }
        
        // Mevcut controller bir navigation controller ise bunu güncelle
        if let navController = viewController as? UINavigationController {
            updateAppearance(for: navController)
        }
        
        // Presented controller varsa onu da kontrol et
        if let presented = viewController.presentedViewController {
            findAndUpdateNavigationControllers(in: presented)
        }
        
        // Sayfa container ise, içindeki tüm sayfaları kontrol et
        if let tabController = viewController as? UITabBarController {
            tabController.viewControllers?.forEach { findAndUpdateNavigationControllers(in: $0) }
        }
        
        // Navigation controller ise içindeki view controller'ları kontrol et
        if let navController = viewController as? UINavigationController {
            navController.viewControllers.forEach { findAndUpdateNavigationControllers(in: $0) }
        }
        
        // Split view controller ise içindeki view controller'ları kontrol et
        if let splitController = viewController as? UISplitViewController {
            splitController.viewControllers.forEach { findAndUpdateNavigationControllers(in: $0) }
        }
    }
    
    // Belirli bir navigation controller için görünümü güncelle
    private func updateAppearance(for navController: UINavigationController) {
        // ThemeManager singleton'ını kullan
        let themeManager = ThemeManager.shared
        
        // Bej mod için görünüm
        let bejAppearance = UINavigationBarAppearance()
        bejAppearance.configureWithOpaqueBackground()
        bejAppearance.backgroundColor = UIColor(ThemeManager.BejThemeColors.background)
        bejAppearance.titleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.text)]
        bejAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.text)]
        
        // Standart görünüm
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        
        // Duruma göre görünümü seç
        let appearance = themeManager.bejMode ? bejAppearance : standardAppearance
        
        // Doğrudan bu navigation controller'a görünümü uygula
        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        navController.navigationBar.tintColor = themeManager.bejMode ? UIColor(ThemeManager.BejThemeColors.accent) : nil
        
        // Görünümün zorla güncellenmesini sağla
        navController.navigationBar.layoutIfNeeded()
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
