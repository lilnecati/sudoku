import Foundation
import SwiftUI

// MARK: - Language Struct
struct AppLanguage: Equatable {
    static let english = AppLanguage(code: "en", name: "English")
    static let turkish = AppLanguage(code: "tr", name: "Türkçe")
    static let french = AppLanguage(code: "fr", name: "Français")
    
    static let allLanguages = [english, turkish, french]
    
    let code: String
    let name: String
}

// MARK: - Localization Manager
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("app_language") var currentLanguage: String = "en"
    
    private init() {
        // Başlangıçta kullanıcının tercih ettiği dili ayarla
        let preferredLanguages = Locale.preferredLanguages
        if let firstLanguage = preferredLanguages.first {
            let code = String(firstLanguage.prefix(2))
            if AppLanguage.allLanguages.contains(where: { $0.code == code }) {
                currentLanguage = code
            }
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set([language.code], forKey: "AppleLanguages")
        UserDefaults.standard.set(language.code, forKey: "app_language")
        currentLanguage = language.code
        
        // Yeni dili uygula ve UI'ı güncelle
        NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
        
        // App language changed bildirimini gönder (daha geniş kapsamlı)
        NotificationCenter.default.post(name: Notification.Name("AppLanguageChanged"), object: nil)
        
        // Force UI update
        NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        
        // Force refresh EnvironmentObjects
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func localizedString(for key: String, comment: String = "") -> String {
        let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj") 
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        
        return bundle?.localizedString(forKey: key, value: nil, table: "Localizable") ?? key
    }
}

// MARK: - View Extension for Localization
extension View {
    /// Applies localization changes to this view when language changes
    func localizationAware() -> some View {
        self.modifier(LocalizationViewModifier())
    }
}

// MARK: - Localization View Modifier
struct LocalizationViewModifier: ViewModifier {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID() // Görünümü zorla yenilemek için
    
    func body(content: Content) -> some View {
        content
            .id(refreshID) // View'ı zorla yenilemek için
            .environment(\.locale, Locale(identifier: localizationManager.currentLanguage))
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))) { _ in
                // Force view refresh when language changes
                localizationManager.objectWillChange.send()
                
                // View'ı zorla yenile
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceUIUpdate"))) { _ in
                // View'ı zorla yenile - özel UI yenileme bildirimi
                refreshID = UUID()
                
                // EnvironmentObject'i güncelle
                localizationManager.objectWillChange.send()
            }
    }
}

// MARK: - Text Extension for SwiftUI
extension Text {
    /// Creates a text view that displays localized content
    @MainActor
    static func localized(_ key: String) -> Text {
        return Text(LocalizationManager.shared.localizedString(for: key))
    }
    
    /// Creates a text view that displays localized content, safe for use in any context
    static func localizedSafe(_ key: String) -> Text {
        // Dil kodunu al
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        
        // Desteklenen diller için kontrol yap
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Yerelleştirme paketi bulunamadıysa varsayılan metni göster
            return Text(key)
        }
        
        // Yerelleştirilmiş metni bul veya varsayılanı kullan
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        // Yerelleştirme bulunamadıysa key'i göster
        return Text(localizedString != key ? localizedString : key)
    }
    
    /// Creates a text view that displays localized content with a custom default value
    static func localizedSafe(_ key: String, defaultValue: String) -> Text {
        // Dil kodunu al
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        
        // Desteklenen diller için kontrol yap
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Yerelleştirme paketi bulunamadıysa varsayılan metni göster
            return Text(defaultValue)
        }
        
        // Yerelleştirilmiş metni bul veya varsayılanı kullan
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        // Yerelleştirme bulunamadıysa defaultValue'yi göster
        return Text(localizedString != key ? localizedString : defaultValue)
    }
}

// Text uzantısı - Text nesnesinden String değeri almak için
extension Text {
    var string: String {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let string = child.value as? String {
                return string
            }
        }
        return ""
    }
} 

