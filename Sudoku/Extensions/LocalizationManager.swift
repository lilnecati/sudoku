import Foundation
import SwiftUI

// MARK: - Language Struct
struct AppLanguage: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let flag: String
    
    static let english = AppLanguage(code: "en", name: "English", flag: "🇺🇸")
    static let turkish = AppLanguage(code: "tr", name: "Türkçe", flag: "🇹🇷")
    
    static let allLanguages = [english, turkish]
    
    static func language(for code: String) -> AppLanguage {
        return allLanguages.first { $0.code == code } ?? turkish
    }
}

// MARK: - Localization Manager
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "tr"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            appLanguageCode = currentLanguage.code
            objectWillChange.send()
        }
    }
    
    private init() {
        // Önce geçici değişkene ata, self referansı vermeden
        let languageCode = Locale.current.language.languageCode?.identifier ?? "tr"
        let storedCode = UserDefaults.standard.string(forKey: "appLanguage") ?? languageCode
        
        // Sonra currentLanguage'i başlat
        self.currentLanguage = AppLanguage.language(for: storedCode)
        
        print("🌐 Language initialized with: \(currentLanguage.name) (\(currentLanguage.code))")
    }
    
    func setLanguage(_ language: AppLanguage) {
        guard language.code != currentLanguage.code else { return }
        
        print("🌐 Changing language to: \(language.name) (\(language.code))")
        self.currentLanguage = language
        
        // Force UI update by notifying
        NotificationCenter.default.post(name: Notification.Name("AppLanguageChanged"), object: nil)
    }
    
    func localizedString(for key: String, defaultValue: String? = nil) -> String {
        // Get the bundle that contains our strings file
        // This function uses String(localized:) with bundle but also provides caching if needed
        let value = String(localized: String.LocalizationValue(key))
        if value != key || defaultValue == nil {
            return value
        }
        return defaultValue ?? key
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
    
    func body(content: Content) -> some View {
        content
            .environment(\.locale, Locale(identifier: localizationManager.currentLanguage.code))
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppLanguageChanged"))) { _ in
                // Force view refresh when language changes
            }
    }
}

// MARK: - String Extension
extension String {
    @MainActor
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    // Asenkron çalışan alternatif (gerekirse)
    func localizedAsync() async -> String {
        await MainActor.run {
            return LocalizationManager.shared.localizedString(for: self)
        }
    }
}

// MARK: - Text Extension for SwiftUI
extension Text {
    /// Creates a text view that displays localized content identified by a key
    @MainActor
    static func localized(_ key: String, defaultValue: String? = nil) -> Text {
        let localizedString = LocalizationManager.shared.localizedString(for: key, defaultValue: defaultValue)
        return Text(localizedString)
    }
} 