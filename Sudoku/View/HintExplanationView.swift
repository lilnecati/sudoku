//  HintExlanationVion.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 15.10.2024.
//

import SwiftUI

struct HintExplanationView: View {
    @ObservedObject var viewModel: SudokuViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Animasyon durumları
    @State private var isShowing = false
    @State private var offsetY: CGFloat = 300 // Panel alt kısımdan yükselecek, yüksekliği arttı
    @StateObject private var powerManager = PowerSavingManager.shared
    
    // Önizleme için test verisi
    private static let testData: SudokuViewModel.HintData = {
        let data = SudokuViewModel.HintData(
            row: 3, 
            column: 4, 
            value: 5, 
            reason: "Bu hücreye 5 değeri konabilir."
        )
        
        // Test verisi için vurgulama ekleyelim
        data.highlightCell(row: data.row, column: data.column, type: SudokuViewModel.CellInteractionType.target)
        return data
    }()
    
    // Bej mod kontrolü
    private var isBejMode: Bool {
        themeManager.bejMode
    }
    
    var body: some View {
        let hintData = viewModel.hintExplanationData ?? Self.testData
        
        ZStack(alignment: .bottom) {
            // Panel dışına tıklanınca kapatma
            if isShowing {
                 Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                .onTapGesture {
                    dismissHint()
                    }
                }
            
            // Geliştirilmiş Alt Panel
            VStack(spacing: 0) {
                // Başlık Alanı
                hintPanelHeader(hintData: hintData)
                
                // İçerik Alanı
                VStack(spacing: 15) {
                    // Açıklama Metni
                    Text(hintData.stepDescription(for: viewModel.currentHintStep)) // Lokalize anahtar doğrudan kullanılıyor
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        .foregroundColor(themeManager.getTextColor(isSecondary: true))
                    
                    // YENİ: Teknik Diagramı Görünümü
                    HintDiagramView(hintData: hintData)
                    
                    // YENİ: Aday Sayıları Gösterimi
                    if let candidates = hintData.targetCellCandidates, !candidates.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                           Text("Hedef Hücre Adayları:")
                               .font(.caption)
                               .foregroundColor(themeManager.getTextColor(isSecondary: true))
                               .padding(.leading, 5)
                           HStack {
                               ForEach(candidates.sorted(), id: \.self) { candidate in
                                   Text("\(candidate)")
                                       .font(.system(size: 14, weight: .bold))
                                       .frame(width: 24, height: 24)
                                       .background(themeManager.getBoardColor().opacity(0.15))
                                       .clipShape(Circle())
                                       .foregroundColor(themeManager.getBoardColor())
                        }
                           }
                        }
                       .padding(.top, 5)
                    }

                    // İlerleme Göstergesi ve Kontroller
                    hintStepControls(hintData: hintData)
                }
                .padding()
            }
            .background(themeManager.getCardBackgroundColor()) // Tema uyumlu kart rengi
            .cornerRadius(20, corners: [.topLeft, .topRight]) // Sadece üst köşeleri yuvarlat
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: -5)
            .frame(maxWidth: .infinity)
            .offset(y: isShowing ? 0 : offsetY)
            .transition(.move(edge: .bottom))
            .animation(.spring(response: powerManager.isPowerSavingEnabled ? 0.3 : 0.5, dampingFraction: 0.8), value: isShowing)
            .onAppear {
                withAnimation {
                    isShowing = true
                    offsetY = 0
                }
                viewModel.placeHintValueOnBoard(hint: hintData)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom) // Panelin en alta yapışmasını sağla
    }
    
    // MARK: - Alt Görünümler
    
    // Panel Başlığı
    private func hintPanelHeader(hintData: SudokuViewModel.HintData) -> some View {
        ZStack {
            // Arka Plan Gradyanı
            Rectangle()
                .fill(headerGradient(for: hintData.technique))
                .frame(height: 55)
            
            // İkon ve Başlık
            HStack(spacing: 10) {
                Image(systemName: hintData.technique.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(hintData.stepTitle(for: viewModel.currentHintStep))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Kapatma Butonu
                 Button(action: dismissHint) {
                     Image(systemName: "xmark.circle.fill")
                         .font(.title2)
                         .foregroundColor(.white.opacity(0.7))
                 }
            }
            .padding(.horizontal)
        }
    }
    
    // Adım Kontrolleri ve İlerleme Çubuğu
    private func hintStepControls(hintData: SudokuViewModel.HintData) -> some View {
        VStack(spacing: 10) {
            // Geliştirilmiş İlerleme Çubuğu
            ProgressView(value: Double(viewModel.currentHintStep + 1), total: Double(hintData.totalSteps)) {
                // İsteğe bağlı etiket
            } currentValueLabel: {
                 Text("Adım \(viewModel.currentHintStep + 1) / \(hintData.totalSteps)")
                    .font(.caption)
                    .foregroundColor(themeManager.getTextColor(isSecondary: true))
            }
            // Tema rengi ile tint ayarı
            .progressViewStyle(LinearProgressViewStyle(tint: themeManager.getBoardColor())) 
            .padding(.horizontal)
            
            // Kontrol Butonları
            HStack(spacing: 30) {
                // Geri Butonu
                controlButton(icon: "chevron.left", enabled: viewModel.currentHintStep > 0) {
                    if viewModel.currentHintStep > 0 {
                        viewModel.currentHintStep -= 1
                    }
                }
                
                Spacer()
                
                // İleri / Bitti Butonu
                 let isLastStep = viewModel.currentHintStep >= hintData.totalSteps - 1
                 controlButton(icon: isLastStep ? "checkmark" : "chevron.right", enabled: true, isPrimary: isLastStep) {
                     if isLastStep {
                         // Sadece ipucu kullanımını onayla ve paneli kapat
                         viewModel.confirmHintUsed(hint: hintData)
                     } else {
                         viewModel.currentHintStep += 1
                     }
                 }
            }
        }
    }
    
    // Genel Kontrol Butonu
    private func controlButton(icon: String, enabled: Bool, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                // Tema rengi kullanıldı
                .foregroundColor(enabled ? (isPrimary ? .white : themeManager.getBoardColor()) : .gray.opacity(0.5))
                .frame(width: 50, height: 35)
                .background(
                    // Tema rengi kullanıldı
                    isPrimary ? AnyView(Capsule().fill(themeManager.getBoardColor())) : AnyView(Capsule().fill(themeManager.getBoardColor().opacity(0.15)))
                 )
        }
        .disabled(!enabled)
    }
    
    // Tekniğe göre başlık gradyanı
    private func headerGradient(for technique: SudokuViewModel.HintTechnique) -> LinearGradient {
        let color = technique.color // Tekniğin ana rengini al
        return LinearGradient(
            gradient: Gradient(colors: [
                color.opacity(isBejMode ? 0.7 : 0.9),
                color.opacity(isBejMode ? 0.5 : 0.7)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Kapatma Fonksiyonu
    private func dismissHint() {
        // Güç tasarrufu moduna göre animasyon süresi ayarlanır
        let animationDuration = powerManager.isPowerSavingEnabled ? 0.2 : 0.3
        
        // Aşağı doğru kayarak kapanma animasyonu
        withAnimation(.easeInOut(duration: animationDuration)) {
            isShowing = false
            offsetY = 300 // Ekranın altına doğru kayma
        }
        
        // Animasyon tamamlandıktan sonra viewModel'deki değerleri sıfırla
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.05) {
            viewModel.hintExplanationData = nil
            viewModel.currentHintStep = 0
            viewModel.showHintExplanation = false
        }
    }
}

// --- TAŞINACAK BLOKLAR BURADAN ALINACAK ---
// (extension View, struct RoundedCorner, extension HintTechnique, extension HintData)

// --- TAŞINACAK BLOKLAR BURAYA, PREVIEW'DAN ÖNCE EKLENECEK ---

// Yeni: Köşeleri belirli yuvarlatma için uzantı
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - HintTechnique Uzantıları (Renk ve İkon)

extension SudokuViewModel.HintTechnique {
    var icon: String {
        switch self {
        case .nakedSingle: return "1.circle.fill"
        case .hiddenSingle: return "eye.circle.fill"
        case .nakedPair: return "link.circle.fill"
        case .hiddenPair: return "lock.circle.fill"
        case .nakedTriple: return "list.bullet.circle.fill"
        case .hiddenTriple: return "list.bullet.indent"
        case .xWing: return "wind"
        case .swordfish: return "scalemass.fill"
        case .general: return "lightbulb.fill"
        case .none: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        let isBej = ThemeManager.shared.bejMode // shared instance kullan
        
        switch self {
        case .nakedSingle, .hiddenSingle:
            return isBej ? ThemeManager.BejThemeColors.boardColors.green : .green
        case .nakedPair, .hiddenPair:
            return isBej ? ThemeManager.BejThemeColors.boardColors.blue : .blue
        case .nakedTriple, .hiddenTriple:
            return isBej ? ThemeManager.BejThemeColors.boardColors.purple : .purple
        case .xWing, .swordfish:
            return isBej ? ThemeManager.BejThemeColors.boardColors.orange : .orange
        case .general, .none:
            return isBej ? ThemeManager.BejThemeColors.accent : .gray
        }
    }
}

// MARK: - HintData Uzantıları (Adım Başlığı/Açıklaması)

extension SudokuViewModel.HintData {
    // Belirli bir adım için başlık
    func stepTitle(for step: Int) -> String {
        guard step < stepTitles.count else {
            return technique.rawValue // Varsayılan
        }
        // Lokalizasyon anahtarını doğrudan kullan
        return NSLocalizedString(stepTitles[step], comment: "İpucu başlığı")
    }

    // Belirli bir adım için açıklama
    func stepDescription(for step: Int) -> String {
        guard step < stepDescriptions.count else {
             return NSLocalizedString(reason, comment: "İpucu varsayılan açıklaması")
        }
         // Lokalizasyon anahtarını doğrudan kullan
         return NSLocalizedString(stepDescriptions[step], comment: "İpucu adım açıklaması")
    }
}

// --- YENİ: İpucu Diagram Görünümü ---
struct HintDiagramView: View {
    let hintData: SudokuViewModel.HintData
    // ViewModel'e erişim gerekli olabilir (tahta değerleri için), şimdilik olmadan deneyelim
    // @EnvironmentObject var viewModel: SudokuViewModel 
    @EnvironmentObject var themeManager: ThemeManager
 
    // 3x3 grid için hücre koordinatlarını hesapla (kenar durumları dahil)
    private var gridCells: [(row: Int, col: Int)] {
        var cells: [(row: Int, col: Int)] = []
        // Merkezi hedef hücrenin etrafındaki -1, 0, +1 ofsetleri al
        for rOffset in -1...1 {
            for cOffset in -1...1 {
                let r = hintData.row + rOffset
                let c = hintData.column + cOffset
                // Geçerli Sudoku koordinatları içinde mi kontrol et (0-8)
                if r >= 0 && r < 9 && c >= 0 && c < 9 {
                    cells.append((r, c))
                } else {
                    // Sınır dışıysa boş yer tutucu ekle (veya nil?)
                    // Şimdilik geçerli olanları ekliyoruz, layout kendi ayarlar.
                }
            }
        }
        // Eğer 9 hücre bulamazsak (kenarlarda ise) mantığı ayarlamak gerekebilir
        // Ama Grid yapısı eksik hücreleri kaldıracaktır.
        // Hedef hücreyi merkeze almak için sıralama?
        // Şimdilik basitçe 3x3 alanı dolduruyoruz.
        
        // 3x3 alanı dolduracak şekilde koordinatları belirle
        var gridCoords: [(Int, Int)] = []
        let startRow = max(0, hintData.row - 1)
        let endRow = min(8, hintData.row + 1)
        let startCol = max(0, hintData.column - 1)
        let endCol = min(8, hintData.column + 1)

        for r in startRow...endRow {
            for c in startCol...endCol {
                gridCoords.append((r, c))
            }
        }
        // Eksik hücre olursa 9'a tamamlamak yerine Grid'in boş bırakmasını sağlayalım.
        return gridCoords
    }

    var body: some View {
        // Basit 3x3 Grid layout
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<3) { rIndex in // 3 satır
                GridRow {
                    ForEach(0..<3) { cIndex in // 3 sütun
                        let cellIndex = rIndex * 3 + cIndex
                        // Hesaplanan koordinat dizisinin sınırlarını kontrol et
                        if cellIndex < gridCells.count {
                            let (row, col) = gridCells[cellIndex]
                            miniCellView(row: row, col: col)
                                .frame(minWidth: 25, minHeight: 25) // Boyut
                        } else {
                            // Eksik hücre varsa boşluk bırak (kenar durumlar)
                             Color.clear
                                 .frame(minWidth: 25, minHeight: 25)
                        }
                    }
                }
            }
        }
        .padding(5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .frame(height: 90) // Diagram alanına sığdır
    }

    // Mini hücre görünümü
    @ViewBuilder
    private func miniCellView(row: Int, col: Int) -> some View {
        let cellType = hintData.highlightedCells.first { $0.row == row && $0.column == col }?.type
        let isTarget = (cellType == .target || (row == hintData.row && col == hintData.column))
        
        ZStack {
            // Arka plan rengi
            RoundedRectangle(cornerRadius: 3)
                .fill(miniCellBackgroundColor(cellType: cellType, isTarget: isTarget))
            
            // Değer (sadece hedef hücre için)
            if isTarget {
                Text("\(hintData.value)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.getBoardColor()) 
            } else if cellType == .conflict {
                 Image(systemName: "xmark") // Çakışma için ikon
                    .font(.system(size: 10, weight: .bold))
                     .foregroundColor(.red)
            } else if cellType == .related || cellType == .highlight {
                 Circle() // İlişkili için nokta
                     .fill(themeManager.getBoardColor().opacity(0.5))
                     .frame(width: 5, height: 5)
            }
            
            // Kenarlık
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    // Mini hücre arka plan rengi
    private func miniCellBackgroundColor(cellType: SudokuViewModel.CellInteractionType?, isTarget: Bool) -> Color {
        if isTarget {
            return themeManager.getBoardColor().opacity(0.25) // Hedef vurgusu
        }
        switch cellType {
            case .conflict: return Color.red.opacity(0.2) // Çakışma
            case .related, .highlight: return themeManager.getBoardColor().opacity(0.1) // İlişkili
            default: return Color.clear // Diğerleri şeffaf
        }
    }
}

// Önizleme
struct HintExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SudokuViewModel()
        let hintData = SudokuViewModel.HintData(
            row: 2, 
            column: 3,
            value: 5,
            reason: "Bu hücreye 5 değeri konabilir çünkü aynı satır, sütun ve 3x3 bloktaki diğer sayılarla çakışmaz.",
            technique: SudokuViewModel.HintTechnique.general
        )
        hintData.addStep(title: "Adım 1", description: "İlk adım açıklaması")
        hintData.addStep(title: "Adım 2", description: "İkinci adım açıklaması")
        viewModel.hintExplanationData = hintData
        viewModel.showHintExplanation = true
        
        return Group {
            HintExplanationView(viewModel: viewModel)
                .previewLayout(.fixed(width: 350, height: 400))
            
            HintExplanationView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .previewLayout(.fixed(width: 350, height: 400))
        }
    }
}
