import SwiftUI

extension Color {
    static let sudokuBackground = Color("SudokuBackground")
    static let sudokuCell = Color("SudokuCell")
    static let sudokuText = Color("SudokuText")
    static let sudokuAccent = Color("SudokuAccent")
    static let sudokuSecondary = Color("SudokuSecondary")
    
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
