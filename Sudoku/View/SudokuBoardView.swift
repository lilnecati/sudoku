//  SudokuBoardView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 11.11.2024.
//

import SwiftUI
import Combine

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
            
            // İpucu açıklama ekranı artık GameView'da gösteriliyor
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
        // Animasyon değişkenleri
        let cellValue = viewModel.board.getValue(row: row, column: column)
        let isOriginal = viewModel.board.isOriginalValue(row: row, column: column)
        let isSelected = viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column
        
        // Vurgu ve yanlış değer durumlarını hesapla - viewModel'daki önbelleklenmiş metodları kullan
        let isHighlighted = viewModel.isHighlighted(row: row, column: column)
        let isSameValue = viewModel.hasSameValue(row: row, column: column)
        let isInvalid = viewModel.invalidCells.contains(Position(row: row, col: column))
        
        // İpucu hedef hücresi mi kontrol et
        let isHintTarget = isHintTargetCell(row: row, column: column)
        
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
            isHintTarget: isHintTarget,
            onCellTapped: {
                // PowerSavingManager ile etkileşimleri kontrol et
                if !PowerSavingManager.shared.throttleInteractions() {
                    viewModel.selectCell(row: row, column: column)
                }
            }
        )
        .id("cellView_\(row)_\(column)_\(cellValue ?? 0)_\(pencilMarks.hashValue)")
        .drawingGroup()
    }
    
    // Hücre arka plan rengini hesapla - önbelleğe alma için ayrı fonksiyon
    private func calculateCellBackgroundColor(row: Int, column: Int) -> Color {
        let cellValue = viewModel.board.getValue(row: row, column: column)
        
        // İlk olarak seçilen hücre kontrolü
        if viewModel.selectedCell?.row == row && viewModel.selectedCell?.column == column {
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
        if viewModel.isHighlighted(row: row, column: column) {
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
        lhs.isInvalid == rhs.isInvalid &&
        lhs.isHintTarget == rhs.isHintTarget
    }
}
