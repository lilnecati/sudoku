import SwiftUI

extension Color {
    // Hex renk kodları için initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Tema renkleri
    static let sudokuBackground = Color("SudokuBackground")
    static let sudokuCell = Color("SudokuCell")
    static let sudokuText = Color("SudokuText")
    static let sudokuAccent = Color("SudokuAccent")
    static let sudokuSecondary = Color("SudokuSecondary")
    
    // Modern Sudoku renk paleti
    static let modernBlue = Color(hex: "1E88E5")
    static let modernLightBlue = Color(hex: "64B5F6")
    static let modernDarkBlue = Color(hex: "1565C0")
    static let modernPurple = Color(hex: "673AB7")
    static let modernRed = Color(hex: "E53935")
    static let modernGreen = Color(hex: "43A047")
    static let modernGray = Color(hex: "9E9E9E")
    static let modernDarkGray = Color(hex: "424242")
    static let modernLightGray = Color(hex: "EEEEEE")
    
    // Koyu tema arka plan renkleri
    static let darkBg1 = Color(hex: "121212")
    static let darkBg2 = Color(hex: "1E1E1E")
    static let darkBg3 = Color(hex: "242631")
    
    // Açık tema arka plan renkleri
    static let lightBg1 = Color(hex: "FFFFFF")
    static let lightBg2 = Color(hex: "F5F5F5")
    static let lightBg3 = Color(hex: "F0F4FF")
    
    // Karanlık mod için arka plan rengi
    static func darkModeBackground(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? Color(#colorLiteral(red: 0.1019607843, green: 0.1019607843, blue: 0.1215686275, alpha: 1)) : Color(#colorLiteral(red: 0.9490196078, green: 0.9490196078, blue: 0.9725490196, alpha: 1)),
                colorScheme == .dark ? Color(#colorLiteral(red: 0.1294117647, green: 0.1294117647, blue: 0.1568627451, alpha: 1)) : Color(#colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9960784314, alpha: 1))
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Kart arka plan rengi
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white
    }
    
    // Buton arka plan rengi
    static func buttonBackground(for colorScheme: ColorScheme, isSelected: Bool = false) -> Color {
        if isSelected {
            return colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2)
        } else {
            return colorScheme == .dark ? Color(UIColor.tertiarySystemBackground) : Color(UIColor.secondarySystemBackground)
        }
    }
    
    // Metin rengi
    static func textColor(for colorScheme: ColorScheme, isHighlighted: Bool = false) -> Color {
        if isHighlighted {
            return .blue
        } else {
            return colorScheme == .dark ? Color.white : Color.primary
        }
    }
}
