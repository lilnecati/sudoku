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
    // CoreData Persistence Controller
    let persistenceController = PersistenceController.shared
    
    // Theme Manager - Tema yönetimi için EnvironmentObject
    @StateObject var themeManager = ThemeManager()
    
    // Session Manager - Oturum yönetimi için EnvironmentObject
    @StateObject var sessionManager = SessionManager.shared
    
    // Güç TasarruFu Yöneticisi
    @StateObject var powerSavingManager = PowerSavingManager.shared
    
    // Achievement Notification Bridge
    @StateObject var achievementNotificationBridge = AchievementNotificationBridge.shared
    
    // AppDelegate'i kullanarak uygulama yaşam döngüsü olaylarını yönet
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // ScenePhase'i takip et
    @Environment(\.scenePhase) var scenePhase
    
    // Splash ekranını yönetmek için durum değişkenleri
    @State private var showSplashOnResume = false
    @State private var lastBackgroundTime: Date? = nil
    
    // Network Monitor instance
    @StateObject var networkMonitor = NetworkMonitor.shared
    
    // Başlangıç konfigürasyonu için durum
    @State private var isReady = false
    
    var body: some Scene {
        WindowGroup {
            StartupView()
                 .environment(\.managedObjectContext, persistenceController.container.viewContext)
                 .environmentObject(themeManager)
                 .environmentObject(sessionManager)
                 .environmentObject(powerSavingManager)
                 .environmentObject(achievementNotificationBridge)
                 .environmentObject(networkMonitor)
                 .preferredColorScheme(themeManager.colorScheme)
                 .onAppear {
                     NetworkMonitor.shared.startMonitoring()
                 }
                 .onChange(of: scenePhase) { oldPhase, newPhase in
                     handleScenePhaseChange(from: oldPhase, to: newPhase)
                 }
                 .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                      lastBackgroundTime = Date()
                      logInfo("Uygulama arka plana girdi.")
                 }
                 .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                      logInfo("Uygulama ön plana geçecek.")
                 }
        }
    }

    // Sahne değişikliklerini yöneten fonksiyon
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        logInfo("Scene phase changed from \(oldPhase) to \(newPhase)")

        switch newPhase {
        case .active:
            logInfo("Scene became active")
            if let backgroundTime = lastBackgroundTime {
                let timeSinceBackground = Date().timeIntervalSince(backgroundTime)
                logInfo("Current time: \(Date().timeIntervalSince1970), Last background time: \(backgroundTime.timeIntervalSince1970), Time since background: \(timeSinceBackground)")
                let splashTimeout: TimeInterval = 120
                if timeSinceBackground >= splashTimeout {
                     logInfo("Uygulama \(Int(timeSinceBackground)) saniye arka planda kaldı, splash GÖSTERİLECEK (limit: \(Int(splashTimeout)) sn). Setting showSplashOnResume = true")
                    showSplashOnResume = true
                } else {
                     logInfo("Uygulama \(Int(timeSinceBackground)) saniye arka planda kaldı, splash GÖSTERİLMEYECEK (limit: \(Int(splashTimeout)) sn). Setting showSplashOnResume = false")
                    showSplashOnResume = false
                }
            }
            lastBackgroundTime = nil
            
            // Ağ bağlantısı geldiğinde bekleyen işlemleri kontrol et
            if NetworkMonitor.shared.isConnected {
                logInfo("Ağ bağlantısı var, bekleyen işlemler kontrol edilecek (eğer metod public ise).")
            }
            
            logInfo("Ekran kararması engellenecek (eğer metod varsa).")
            
            logInfo("Günlük başarım durumu kontrol edilecek (eğer metod varsa).")
            logInfo("Günlük giriş kontrolü yapılacak (eğer metod varsa).")

        case .inactive:
            logInfo("Scene became inactive")
            logInfo("Ekran kararması etkinleştirilecek (eğer metod varsa).")
            
        case .background:
            logInfo("Scene moved to background")
            logInfo("Ekran kararması etkinleştirilecek (eğer metod varsa).")
            lastBackgroundTime = Date()
            
        @unknown default:
            logWarning("Unknown scene phase.")
        }
    }

    private func configureFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            logSuccess("Firebase successfully configured.")
        } else {
            logWarning("Firebase already configured.")
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        
        if themeManager.bejMode {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(ThemeManager.BejThemeColors.background)
            appearance.titleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.text), .font: UIFont.systemFont(ofSize: 18, weight: .bold)]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.text), .font: UIFont.systemFont(ofSize: 34, weight: .bold)]
            
            let buttonAppearance = UIBarButtonItemAppearance()
            buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(ThemeManager.BejThemeColors.accent)]
            appearance.buttonAppearance = buttonAppearance
            appearance.backButtonAppearance = buttonAppearance
        } else {
            appearance.configureWithDefaultBackground()
        }
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        logInfo("NavigationBar appearance configured: \(themeManager.bejMode ? "Bej Mode" : "Default/Dark Mode")")
        setupThemeChangeListenerInAppDelegate()
    }
    
    private func setupThemeChangeListenerInAppDelegate() {
        appDelegate.themeManager = themeManager
        logInfo("AppDelegate: ThemeChanged listener setup initiated.")
    }

    private func setupUserDefaults() {
        UserDefaults.standard.register(defaults: [
            "haptics_enabled": true,
            "sound_effects_enabled": true,
            "timer_enabled": true,
            "highlight_similar_numbers": true,
            "highlight_mistakes": true,
            "auto_remove_notes": true,
            "prevent_screen_dimming": true,
            "selected_theme": "system",
            "bej_mode_enabled": false,
            "grid_line_style": "thin",
            "app_language": "tr"
        ])
        logInfo("UserDefaults defaults registered.")
    }
    
    var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
