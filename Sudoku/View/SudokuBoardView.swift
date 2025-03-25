import SwiftUI

struct SudokuBoardView: View {
    @ObservedObject var viewModel: SudokuViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Performans için önbellekleme
    @State private var cellSize: CGFloat = 0
    @State private var gridSize: CGFloat = 0
    @State private var lastCalculatedFrame: CGRect = .zero
    
    // Sabit değerler
    private let cellPadding: CGFloat = 1
    private let boldLineWidth: CGFloat = 2.5
    private let normalLineWidth: CGFloat = 0.8
    
    // Hücre arka plan renkleri - önbellekleme
    private let originalCellBackground: Color = Color.blue.opacity(0.05)
    private let selectedRowColBackground: Color = Color.blue.opacity(0.08)
    private let selectedCellBackground: Color = Color.blue.opacity(0.2)
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
                    // Tablo arkaplanı
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .aspectRatio(1, contentMode: .fit)
                    
                    // 9x9 hücre gridi - sabit boyutlu hücreler
                    VStack(spacing: 0) {
                        ForEach(0..<9) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<9) { column in
                                    cellView(row: row, column: column)
                                        .id("cell_\(row)_\(column)")
                                        .frame(width: localCellSize + (cellPadding * 2), height: localCellSize + (cellPadding * 2))
                                        .drawingGroup() // Metal hızlandırması
                                }
                            }
                            // Satır boyutunu sabitle
                            .frame(height: localCellSize + (cellPadding * 2))
                        }
                    }
                    .frame(width: minDimension, height: minDimension)
                    .clipped() // Taşmaları önle
                    
                    // Izgara çizgilerini üst katmanda göster
                    gridOverlay
                        .frame(width: minDimension, height: minDimension)
                }
                .aspectRatio(1, contentMode: .fit) // Kare oranını koru
                .drawingGroup() // Metal hızlandırması
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            // Görünüm dışında state güncelleme
            .onAppear {
                // İlk yükleme veya ekran değişiminde boyutları güncelle
                _ = updateSizes(from: frame, cellSize: localCellSize)
            }
            .onChange(of: frame) { oldFrame, newFrame in
                // Ekran boyutu değiştiğinde boyutları güncelle
                if oldFrame != newFrame {
                    _ = updateSizes(from: newFrame, cellSize: localCellSize)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
    
    // Grid çizgilerini çiz
    private var gridOverlay: some View {
        ZStack {
            // Tüm hücreler için ince çizgiler
            gridCellLines
            
            // 3x3 bölgeleri için kalın çizgiler
            gridLines
        }
    }
    
    // İnce hücre çizgileri
    private var gridCellLines: some View {
        ZStack {
            // Tüm yatay ince çizgiler
            ForEach(0..<10, id: \.self) { index in
                Path { path in
                    let yPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: yPosition))
                    path.addLine(to: CGPoint(x: gridSize, y: yPosition))
                }
                .stroke(colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: normalLineWidth)
            }
            
            // Tüm dikey ince çizgiler
            ForEach(0..<10, id: \.self) { index in
                Path { path in
                    let xPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: xPosition, y: 0))
                    path.addLine(to: CGPoint(x: xPosition, y: gridSize))
                }
                .stroke(colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: normalLineWidth)
            }
        }
    }
    
    // Kalın grid çizgileri
    private var gridLines: some View {
        ZStack {
            // Yatay kalın çizgiler
            ForEach([3, 6], id: \.self) { index in
                Path { path in
                    let yPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: yPosition))
                    path.addLine(to: CGPoint(x: gridSize, y: yPosition))
                }
                .stroke(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6), lineWidth: boldLineWidth)
            }
            
            // Dikey kalın çizgiler
            ForEach([3, 6], id: \.self) { index in
                Path { path in
                    let xPosition = gridSize / 9 * CGFloat(index)
                    path.move(to: CGPoint(x: xPosition, y: 0))
                    path.addLine(to: CGPoint(x: xPosition, y: gridSize))
                }
                .stroke(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6), lineWidth: boldLineWidth)
            }
            
            // Dış çerçeve
            Rectangle()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6), lineWidth: boldLineWidth)
        }
    }
    
    // Hücre görünümü - performans için optimize edildi
    private func cellView(row: Int, column: Int) -> some View {
        let cellValue = viewModel.board.getValue(row: row, column: column)
        let isOriginal = viewModel.board.isOriginalValue(row: row, column: column)
        let isSelected = viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column
        
        // Vurgu ve yanlış değer durumlarını hesapla
        let isHighlighted = self.isHighlighted(row: row, column: column)
        let isSameValue = self.hasSameValue(row: row, column: column)
        let isInvalid = viewModel.invalidCells.contains(Position(row: row, col: column))
        
        // Kalem işaretlerini al
        let pencilMarks = viewModel.getPencilMarks(at: row, col: column)
        
        return SudokuCellView(
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
                // Sadece oyun devam ederken hücre seçimine izin ver
                if viewModel.gameState == .playing || viewModel.gameState == .ready {
                    // Aynı hücreye yeniden basıldığında değişiklik yoksa animasyon yapma
                    if viewModel.selectedCell?.row != row || viewModel.selectedCell?.column != column {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.impactOccurred()
                    }
                    
                    viewModel.selectCell(row: row, column: column)
                }
            }
        )
    }
    
    // Kalem notları - performans için optimize edildi
    private func pencilMarksView(row: Int, column: Int) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<3) { r in
                HStack(spacing: 1) {
                    ForEach(0..<3) { c in
                        let number = r * 3 + c + 1
                        if viewModel.isPencilMarkSet(row: row, column: column, value: number) {
                            Text("\(number)")
                                .font(.system(size: cellSize * 0.2))
                                .foregroundColor(.gray)
                                .frame(width: cellSize / 3, height: cellSize / 3)
                        } else {
                            Color.clear
                                .frame(width: cellSize / 3, height: cellSize / 3)
                        }
                    }
                }
            }
        }
    }
    
    // Hücre arka plan rengini hesapla - önbelleğe alma için ayrı fonksiyon
    private func getCellBackgroundColor(row: Int, column: Int, isSelected: Bool) -> Color {
        let cellValue = viewModel.board.getValue(row: row, column: column)
        
        // İlk olarak seçilen hücre kontrolü
        if isSelected {
            return selectedCellBackground
        }
        
        // Hücrenin geçerli değeri yok ya da orijinal değerse
        if viewModel.selectedCell == nil {
            return originalCellBackground
        }
        
        // Hücrenin seçili hücreyle aynı değeri varsa
        if let selectedCell = viewModel.selectedCell,
           let selectedValue = viewModel.board.getValue(row: selectedCell.row, column: selectedCell.column),
           let currentValue = cellValue,
           selectedValue == currentValue && currentValue != 0 {
            return matchingValueBackground
        }
        
        // Hücre aynı satır, sütun veya 3x3 bloktaysa
        if isHighlighted(row: row, column: column) {
            return selectedRowColBackground
        }
        
        // Varsayılan arka plan rengi
        return originalCellBackground
    }
    
    // Metin rengini hesapla - önbelleğe alma için ayrı fonksiyon
    private func getTextColor(isOriginal: Bool, isSelected: Bool, cellValue: Int?) -> Color {
        if isOriginal {
            return colorScheme == .dark ? .white : .black
        } else if let value = cellValue, let selectedCell = viewModel.selectedCell {
            if viewModel.board.isCorrectValue(row: selectedCell.row, column: selectedCell.column, value: value) {
                return Color.blue.opacity(0.8)
            } else {
                return Color.red.opacity(0.8)
            }
        }
        
        return Color.blue.opacity(0.8)
    }
    
    // Hücre vurgulanmış mı
    private func isHighlighted(row: Int, column: Int) -> Bool {
        guard let selectedCell = viewModel.selectedCell else {
            return false
        }
        
        // Seçili hücrenin kendisi vurgulanmaz
        if row == selectedCell.row && column == selectedCell.column {
            return false
        }
        
        let sRow = selectedCell.row
        let sCol = selectedCell.column
        
        // Aynı satır veya sütun
        return row == sRow || column == sCol
    }
    
    // Hücrenin seçili hücreyle aynı değeri var mı
    private func hasSameValue(row: Int, column: Int) -> Bool {
        guard let selectedCell = viewModel.selectedCell,
              let selectedValue = viewModel.board.getValue(row: selectedCell.row, column: selectedCell.column),
              let currentValue = viewModel.board.getValue(row: row, column: column),
              selectedValue == currentValue,
              selectedValue > 0,
              // Seçili hücrenin kendisi değilse
              !(row == selectedCell.row && column == selectedCell.column) else {
            return false
        }
        
        return true
    }
}

// Equatable desteği ekle
extension SudokuCellView: Equatable {
    static func == (lhs: SudokuCellView, rhs: SudokuCellView) -> Bool {
        lhs.row == rhs.row &&
        lhs.column == rhs.column &&
        lhs.value == rhs.value &&
        lhs.isFixed == rhs.isFixed &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isHighlighted == rhs.isHighlighted &&
        lhs.isMatchingValue == rhs.isMatchingValue &&
        lhs.isInvalid == rhs.isInvalid
    }
}