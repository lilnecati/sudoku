import Foundation
import SwiftUI

// Add country flags for each language
extension AppLanguage {
    var flag: String {
        switch code {
        case "en": return "🇬🇧"
        case "tr": return "🇹🇷"
        default: return "🏳️"
        }
    }
}

// Make AppLanguage identifiable for ForEach usage
extension AppLanguage: Identifiable {
    var id: String { code }
} 