//  SudokuBoardView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 11.11.2024.
//

import SwiftUI
import Combine
import FirebaseAuth

struct SudokuBoardView: View {
    // Tema yönetimini alabilmek için
    @EnvironmentObject var themeManager: ThemeManager
    
    // MVVM: SudokuViewModel'i saklı tut - her güncelleme view'i yeniden çizer
    @ObservedObject var viewModel: SudokuViewModel
    
    // Otomatik güncellenen koyu mod tercihi (performans için)
    @AppStorage("prefersDarkMode") private var prefersDarkMode = false
    @Environment(\.colorScheme) private var systemColorScheme
    
    // Görünümü yenilemek için ID
    @State private var boardRefreshID = UUID()
    
    // Geçerli renk şeması
    private var effectiveColorScheme: ColorScheme {
        return systemColorScheme
    }
    
    // Bej mod kullanılıyor mu kontrol et
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Performans için önbellekleme
    @State private var cellSize: CGFloat = 0
    @State private var gridSize: CGFloat = 0
    @State private var lastCalculatedFrame: CGRect = .zero
    
    // Sabit değerler
    private let cellPadding: CGFloat = 1
    private let boldLineWidth: CGFloat = 2.5
    private let normalLineWidth: CGFloat = 0.8
    
    // Hücre arka plan renkleri - önbellekleme
    private func originalCellBackground() -> Color {
        return themeManager.getBoardColor().opacity(0.05)
    }
    
    private func selectedRowColBackground() -> Color {
        return themeManager.getBoardColor().opacity(0.08)
    }
    
    private func selectedCellBackground() -> Color {
        return themeManager.getBoardColor().opacity(0.2)
    }
    
    private let matchingValueBackground: Color = Color.green.opacity(0.15)
    private let invalidValueBackground: Color = Color.red.opacity(0.15)
    
    var body: some View {
        // Sabit boyut sunucusu
        GeometryReader { geometry in
            let minDimension = min(geometry.size.width, geometry.size.height)
            let localCellSize = (minDimension / 9) - cellPadding * 2
            let frame = geometry.frame(in: .local)
            
            // Sabit bir çerçeve içinde tüm içerik
            ZStack(alignment: .center) {
                // Baz katman - arka plan
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                
                // Sadece oyun tahtasını içine alan konteyner
                ZStack {
                    // Tablo arkaplanı - Minimal tasarım
                    RoundedRectangle(cornerRadius: 4)
                        .fill(getTableBackgroundColor())
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                        .aspectRatio(1, contentMode: .fit)
                    
                    // 9x9 hücre gridi - sabit boyutlu hücreler
                    LazyVStack(spacing: 0) {
                        ForEach(0..<9) { row in
                            LazyHStack(spacing: 0) {
                                ForEach(0..<9) { column in
                                    cellView(row: row, column: column)
                                        .id("cell_\(row)_\(column)_\(boardRefreshID)")
                                        .frame(width: localCellSize + (cellPadding * 2), height: localCellSize + (cellPadding * 2))
                            }
                        }
                        // Satır boyutunu sabitle
                        .frame(height: localCellSize + (cellPadding * 2))
                    }
                }
                .frame(width: minDimension, height: minDimension)
                .clipped() // Taşmaları önle
                // Her zaman GPU hızlandırma kullan - güç tasarrufu modunda bile
                .drawingGroup(opaque: true, colorMode: .linear)
                
                // Izgara çizgilerini üst katmanda göster
                gridOverlay
                    .frame(width: minDimension, height: minDimension)
                    .drawingGroup(opaque: true) // Izgara çizgilerini de GPU ile render et
                }
                .aspectRatio(1, contentMode: .fit) // Kare oranını koru
                .drawingGroup() // Tüm ZStack'i GPU ile render et
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            // Görünüm dışında state güncelleme
            .onAppear {
                // İlk yükleme veya ekran değişiminde boyutları güncelle
                _ = updateSizes(from: frame, cellSize: localCellSize)
                
                // İlgili bildirimleri dinle
                setupBoardColorNotifications()
            }
            .onChange(of: frame) { oldFrame, newFrame in
                // Ekran boyutu değiştiğinde boyutları güncelle
                if oldFrame != newFrame {
                    _ = updateSizes(from: newFrame, cellSize: localCellSize)
                }
            }
            .onChange(of: themeManager.colorScheme) { _, _ in
                // Tema değişikliğinde yenile
                withAnimation(.easeInOut(duration: 0.3)) {
                    boardRefreshID = UUID()
                }
            }
            .onDisappear {
                // Kaynakları temizle
                NotificationCenter.default.removeObserver(self)
            }
            
            // İpucu açıklama ekranı artık GameView'da gösteriliyor
        }
        .aspectRatio(1, contentMode: .fit)
        .drawingGroup() // Tüm görünümü GPU ile render et
        .id(boardRefreshID) // Tüm tahta görünümünü yenileme ID'si
        .animation(.easeInOut(duration: 0.3), value: themeManager.darkMode) // Tema değişimi animasyonu
        .animation(.easeInOut(duration: 0.3), value: themeManager.useSystemAppearance) // Sistem tema değişimi animasyonu
        .animation(.easeInOut(duration: 0.3), value: themeManager.bejMode) // Bej mod değişimi animasyonu
    }
    
    // Boyutları güncelle - sabit bir cell boyutu için optimize edildi
    private func updateSizes(from frame: CGRect, cellSize: CGFloat) -> Bool {
        // Sadece farklı bir boyut varsa güncelle
        if frame != lastCalculatedFrame {
            let availableSize = min(frame.width, frame.height)
            gridSize = availableSize
            self.cellSize = cellSize
            lastCalculatedFrame = frame
            return true
        }
        return false
    }
    
    // Izgara çizgilerini çiz - performans için sadece değişiklik olduğunda yeniden hesapla
    private var gridOverlay: some View {
        // Bej mod grid renkleri
        let gridColor = isBejMode ? 
                      ThemeManager.BejThemeColors.text.opacity(0.7) : 
                      (effectiveColorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
        
        let gridLinesColor = isBejMode ? 
                           ThemeManager.BejThemeColors.text.opacity(0.3) : 
                           (effectiveColorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3))
        
        return ZStack {
            // Tüm hücreler için ince çizgiler - tek bir drawingGroup içinde birleştir
            gridCellLines(gridLinesColor: gridLinesColor)
                .drawingGroup(opaque: true) // İnce çizgiler için Metal hızlandırması
            
            // 3x3 bölgeleri için kalın çizgiler - tek bir drawingGroup içinde birleştir
            gridBoldLines(gridColor: gridColor)
                .drawingGroup(opaque: true) // Kalın çizgiler için Metal hızlandırması
        }
    }
    
    // İnce hücre çizgileri - renk parametresiyle önbellekleme için
    private func gridCellLines(gridLinesColor: Color) -> some View {
        ZStack {
            // Tüm yatay ince çizgiler - tek bir Path içinde birleştir
            Path { path in
                for index in 0..<10 {
                    let yPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: yPosition))
                    path.addLine(to: CGPoint(x: gridSize, y: yPosition))
                }
            }
            .stroke(gridLinesColor, lineWidth: 0.8)
            
            // Tüm dikey ince çizgiler - tek bir Path içinde birleştir
            Path { path in
                for index in 0..<10 {
                    let xPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: xPosition, y: 0))
                    path.addLine(to: CGPoint(x: xPosition, y: gridSize))
                }
            }
            .stroke(gridLinesColor, lineWidth: 0.8)
        }
    }
    
    // Kalın grid çizgileri - renk parametresiyle önbellekleme için
    private func gridBoldLines(gridColor: Color) -> some View {
        ZStack {
            // Tüm yatay kalın çizgiler - tek bir Path içinde birleştir
            Path { path in
                for index in [3, 6] {
                    let yPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: yPosition))
                    path.addLine(to: CGPoint(x: gridSize, y: yPosition))
                }
            }
            .stroke(gridColor, lineWidth: 2.0)
            
            // Tüm dikey kalın çizgiler - tek bir Path içinde birleştir
            Path { path in
                for index in [3, 6] {
                    let xPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: xPosition, y: 0))
                    path.addLine(to: CGPoint(x: xPosition, y: gridSize))
                }
            }
            .stroke(gridColor, lineWidth: 2.0)
            
            // Dış çerçeve - minimal tasarım için hafif yuvarlatılmış köşeler
            RoundedRectangle(cornerRadius: 4)
                .stroke(gridColor, lineWidth: 2.5)
        }
    }
    
    // Hücre görünümü - performans için optimize edildi
    private func cellView(row: Int, column: Int) -> some View {
        // Animasyon değişkenleri
        let cellValue = viewModel.board.getValue(row: row, column: column)
        let isOriginal = viewModel.board.isOriginalValue(row: row, column: column)
        let isSelected = viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column
        
        // YENİ: Sadece dolu bir hücre seçiliyse diğerlerini vurgula
        let shouldHighlightBasedOnSelection = viewModel.selectedCell != nil && (viewModel.board.getValue(at: viewModel.selectedCell!.row, col: viewModel.selectedCell!.column) ?? 0 > 0)
        
        // İpucu aktifse normal vurgulamaları kapat
        let isHintActive = viewModel.hintExplanationData != nil
        let isHighlighted = !isHintActive && shouldHighlightBasedOnSelection && viewModel.isHighlighted(row: row, column: column)
        let isSameValue = !isHintActive && shouldHighlightBasedOnSelection && viewModel.hasSameValue(row: row, column: column)
        let isInvalid = viewModel.invalidCells.contains(Position(row: row, col: column))
        
        // YENİ: Bu hücrenin ipucu hedefi olup olmadığını kontrol et
        let isHintTargetCell = isHintActive && viewModel.hintExplanationData?.row == row && viewModel.hintExplanationData?.column == column
        
        // Kalem işaretlerini al
        let pencilMarks = viewModel.getPencilMarks(at: row, col: column)
        
        // ID değerini hesapla - değişimler için gerekli değerleri dahil et
        let cellID = "\(row)\(column)\(cellValue ?? 0)\(isSelected)\(isInvalid)\(pencilMarks.hashValue)"
        
        // Her zaman GPU render kullan
        let cellView = SudokuCellView(
            row: row,
            column: column,
            value: cellValue,
            isFixed: isOriginal,
            isUserEntered: viewModel.userEnteredValues[row][column],
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            isMatchingValue: isSameValue,
            isInvalid: isInvalid,
            pencilMarks: pencilMarks,
            onCellTapped: {
                // Performans optimizasyonu: Zaten seçili hücreye tekrar basılırsa işlem yapma
                if viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column {
                    return
                }
                viewModel.selectCell(row: row, column: column)
            },
            isHintEntered: false,
            isHintTargetCell: isHintTargetCell
        )
        .id(cellID)
        .drawingGroup(opaque: true, colorMode: .linear) // Her zaman GPU ile render et, maksimum performans
        
        return AnyView(cellView)
    }
    
    // Hücre arka plan rengini hesapla - önbelleğe alma için ayrı fonksiyon
    private func calculateCellBackgroundColor(row: Int, column: Int) -> Color {
        let cellValue = viewModel.board.getValue(row: row, column: column)
        
        // Bej mod özel renkleri
        if isBejMode {
            // ThemeManager'dan rengimizi alalım
            let themeColor = themeManager.getBoardColor()
            
            // İlk olarak seçilen hücre kontrolü
            if viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column {
                return themeColor.opacity(0.2)
            }
            
            // Hücrenin geçerli değeri yok ya da orijinal değerse
            if viewModel.selectedCell == nil {
                return ThemeManager.BejThemeColors.background.opacity(0.5)
            }
            
            // Hücrenin seçili hücreyle aynı değeri varsa
            if let selectedCell = viewModel.selectedCell,
               let selectedValue = viewModel.board.getValue(row: selectedCell.row, column: selectedCell.column),
               let currentValue = cellValue,
               selectedValue == currentValue && currentValue != 0 {
                return themeColor.opacity(0.15) // Bej uyumlu yeşil yerine seçilen rengi kullan
            }
            
            // Hücre aynı satır, sütun veya 3x3 bloktaysa
            if viewModel.isHighlighted(row: row, column: column) {
                return themeColor.opacity(0.1)
            }
            
            // Varsayılan arka plan rengi
            return ThemeManager.BejThemeColors.background.opacity(0.5)
        } else {
            // Normal tema renkleri
            // İlk olarak seçilen hücre kontrolü
            if viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column {
                return selectedCellBackground()
            }
            
            // Hücrenin geçerli değeri yok ya da orijinal değerse
            if viewModel.selectedCell == nil {
                return originalCellBackground()
            }
            
            // Hücrenin seçili hücreyle aynı değeri varsa
            if let selectedCell = viewModel.selectedCell,
               let selectedValue = viewModel.board.getValue(row: selectedCell.row, column: selectedCell.column),
               let currentValue = cellValue,
               selectedValue == currentValue && currentValue != 0 {
                return matchingValueBackground
            }
            
            // Hücre aynı satır, sütun veya 3x3 bloktaysa
            if viewModel.isHighlighted(row: row, column: column) {
                return selectedRowColBackground()
            }
            
            // Varsayılan arka plan rengi
            return originalCellBackground()
        }
    }
    
    // Metin rengini hesapla - önbelleğe alma için ayrı fonksiyon
    private func getTextColor(isOriginal: Bool, isSelected: Bool, cellValue: Int?) -> Color {
        if isBejMode {
            // ThemeManager'dan rengimizi alalım
            let themeColor = themeManager.getBoardColor()
            
            if isOriginal {
                return ThemeManager.BejThemeColors.text
            } else if let value = cellValue, let selectedCell = viewModel.selectedCell {
                if viewModel.board.isCorrectValue(row: selectedCell.row, column: selectedCell.column, value: value) {
                    return themeColor
                } else {
                    return Color.red.opacity(0.8)
                }
            }
            return themeColor
        } else {
            if isOriginal {
                return effectiveColorScheme == .dark ? .white : .black
            } else if let value = cellValue, let selectedCell = viewModel.selectedCell {
                if viewModel.board.isCorrectValue(row: selectedCell.row, column: selectedCell.column, value: value) {
                    return themeManager.getBoardColor().opacity(0.8)
                } else {
                    return Color.red.opacity(0.8)
                }
            }
            
            return themeManager.getBoardColor().opacity(0.8)
        }
    }
    
    // İpucu hedef hücresi mi kontrol et
    private func isHintTargetCell(row: Int, column: Int) -> Bool {
        guard let hintData = viewModel.hintExplanationData,
              viewModel.showHintExplanation else {
            return false
        }
        
        // İpucu hedef hücresi veya vurgulanan hücrelerden biriyse true döndür
        if hintData.row == row && hintData.column == column {
            return true
        }
        
        // Vurgulanan diğer hücreler
        return hintData.highlightedCells.contains { $0.row == row && $0.column == column && $0.type == .target }
    }
    
    // MARK: - Bildirim Yönetimi
    private func setupBoardColorNotifications() {
        // Renk değişikliği bildirimini dinle
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BoardColorChanged"), 
            object: nil, 
            queue: .main
        ) { _ in
            // Renk değiştiğinde zorla yeniden çizim yap
            withAnimation(.easeInOut(duration: 0.3)) {
                // ViewModel'in objectWillChange'ini kullan
                self.viewModel.objectWillChange.send()
                
                // Ayrıca tüm tahta görünümünü yenilemek için ID'yi değiştir
                self.boardRefreshID = UUID()
            }
        }
        
        // Tema değişikliği bildirimlerini de dinleyebiliriz
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ThemeChanged"), 
            object: nil, 
            queue: .main
        ) { _ in
            // Tema değiştiğinde zorla yeniden çizim yap
            withAnimation(.easeInOut(duration: 0.3)) {
                // ViewModel'in objectWillChange'ini kullan
                self.viewModel.objectWillChange.send()
                
                // Ayrıca tüm tahta görünümünü yenilemek için ID'yi değiştir 
                self.boardRefreshID = UUID()
            }
        }
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
                    } catch {
                        logError("Kullanıcı çıkışı hatası: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // Tahta arka plan rengini hesapla
    private func getTableBackgroundColor() -> Color {
        if isBejMode {
            return ThemeManager.BejThemeColors.cardBackground
        } else {
            return effectiveColorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground)
        }
    }
}

// ConditionalDrawingGroup modifierını güncelliyorum - her zaman GPU render kullansın
struct ConditionalDrawingGroup: ViewModifier {
    func body(content: Content) -> some View {
        // Her zaman Metal hızlandırması kullan, güç tasarrufu durumunu dikkate alma
        return AnyView(content.drawingGroup(opaque: true, colorMode: .linear))
    }
}
